import Foundation

protocol FileSystemProviding {
    func contentsOfDirectory(at url: URL) async throws -> [FileItem]
    func recursiveContentsOfDirectory(at url: URL, includeHiddenFiles: Bool) async throws -> [FileItem]
    func mediaItems(in directory: URL, recursive: Bool, includeHiddenFiles: Bool) async throws -> [FileItem]
}

private actor FileSystemWorker {
    private let fileManager: FileManager
    private let resourceKeys: Set<URLResourceKey>

    init(fileManager: FileManager, resourceKeys: Set<URLResourceKey>) {
        self.fileManager = fileManager
        self.resourceKeys = resourceKeys
    }

    func contentsOfDirectory(at url: URL) throws -> [FileItem] {
        try Task.checkCancellation()
        let urls = try fileManager.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: Array(resourceKeys),
            options: [.skipsSubdirectoryDescendants]
        )

        var items: [FileItem] = []
        items.reserveCapacity(urls.count)
        for entryURL in urls {
            try Task.checkCancellation()
            let values = try? entryURL.resourceValues(forKeys: resourceKeys)
            items.append(makeFileItem(from: entryURL, values: values))
        }
        return items
    }

    func recursiveContentsOfDirectory(at url: URL, includeHiddenFiles: Bool) throws -> [FileItem] {
        try Task.checkCancellation()
        let options: FileManager.DirectoryEnumerationOptions = includeHiddenFiles
            ? [.skipsPackageDescendants]
            : [.skipsPackageDescendants, .skipsHiddenFiles]

        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: Array(resourceKeys),
            options: options
        ) else {
            return []
        }

        var items: [FileItem] = []
        while let entryURL = enumerator.nextObject() as? URL {
            try Task.checkCancellation()
            let values = try? entryURL.resourceValues(forKeys: resourceKeys)
            let item = makeFileItem(from: entryURL, values: values)
            if !includeHiddenFiles, item.isHidden {
                continue
            }
            items.append(item)
        }

        return items.sorted {
            $0.url.path.localizedStandardCompare($1.url.path) == .orderedAscending
        }
    }

    func mediaItems(in directory: URL, recursive: Bool, includeHiddenFiles: Bool) throws -> [FileItem] {
        try Task.checkCancellation()
        if !recursive {
            let items = try contentsOfDirectory(at: directory)
            var filtered: [FileItem] = []
            filtered.reserveCapacity(items.count)
            for item in items {
                try Task.checkCancellation()
                if item.isDirectory {
                    continue
                }
                if !includeHiddenFiles, item.isHidden {
                    continue
                }
                if item.url.isMediaFile {
                    filtered.append(item)
                }
            }
            return filtered
        }

        let options: FileManager.DirectoryEnumerationOptions = includeHiddenFiles
            ? [.skipsPackageDescendants]
            : [.skipsPackageDescendants, .skipsHiddenFiles]

        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: Array(resourceKeys),
            options: options
        ) else {
            return []
        }

        var items: [FileItem] = []
        while let entryURL = enumerator.nextObject() as? URL {
            try Task.checkCancellation()
            let values = try? entryURL.resourceValues(forKeys: resourceKeys)
            let item = makeFileItem(from: entryURL, values: values)
            if item.isDirectory {
                continue
            }
            if !includeHiddenFiles, item.isHidden {
                continue
            }
            if item.url.isMediaFile {
                items.append(item)
            }
        }

        return items.sorted {
            $0.url.path.localizedStandardCompare($1.url.path) == .orderedAscending
        }
    }

    private func makeFileItem(from entryURL: URL, values: URLResourceValues?) -> FileItem {
        let isDirectory = values?.isDirectory ?? false
        let isPackage = values?.isPackage ?? false

        return FileItem(
            url: entryURL,
            name: values?.name ?? entryURL.displayName,
            isDirectory: isDirectory,
            size: values?.fileSize.map(Int64.init),
            dateModified: values?.contentModificationDate,
            isHidden: values?.isHidden ?? false,
            isSymlink: values?.isSymbolicLink ?? false,
            isPackage: isPackage
        )
    }
}

struct FileSystemService: FileSystemProviding {
    private static let resourceKeys: Set<URLResourceKey> = [
            .nameKey,
            .isDirectoryKey,
            .isRegularFileKey,
            .fileSizeKey,
            .contentModificationDateKey,
            .isHiddenKey,
            .isSymbolicLinkKey,
            .isPackageKey
        ]
    private let worker: FileSystemWorker

    init(fileManager: FileManager = .default) {
        self.worker = FileSystemWorker(fileManager: fileManager, resourceKeys: Self.resourceKeys)
    }

    func contentsOfDirectory(at url: URL) async throws -> [FileItem] {
        try await worker.contentsOfDirectory(at: url)
    }

    func recursiveContentsOfDirectory(at url: URL, includeHiddenFiles: Bool) async throws -> [FileItem] {
        try await worker.recursiveContentsOfDirectory(at: url, includeHiddenFiles: includeHiddenFiles)
    }

    func mediaItems(in directory: URL, recursive: Bool, includeHiddenFiles: Bool) async throws -> [FileItem] {
        try await worker.mediaItems(in: directory, recursive: recursive, includeHiddenFiles: includeHiddenFiles)
    }
}
