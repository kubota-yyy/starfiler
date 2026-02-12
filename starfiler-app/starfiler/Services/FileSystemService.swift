import Foundation

protocol FileSystemProviding {
    func contentsOfDirectory(at url: URL) async throws -> [FileItem]
    func mediaItems(in directory: URL, recursive: Bool, includeHiddenFiles: Bool) async throws -> [FileItem]
}

struct FileSystemService: FileSystemProviding {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    private let resourceKeys: Set<URLResourceKey> = [
            .nameKey,
            .isDirectoryKey,
            .isRegularFileKey,
            .fileSizeKey,
            .contentModificationDateKey,
            .isHiddenKey,
            .isSymbolicLinkKey,
            .isPackageKey
        ]

    func contentsOfDirectory(at url: URL) async throws -> [FileItem] {
        let urls = try fileManager.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: Array(self.resourceKeys),
            options: [.skipsSubdirectoryDescendants]
        )

        return urls.map { entryURL in
            let values = try? entryURL.resourceValues(forKeys: self.resourceKeys)
            return Self.makeFileItem(from: entryURL, values: values)
        }
    }

    func mediaItems(in directory: URL, recursive: Bool, includeHiddenFiles: Bool) async throws -> [FileItem] {
        if !recursive {
            let items = try await contentsOfDirectory(at: directory)
            return items.filter { item in
                if item.isDirectory {
                    return false
                }
                if !includeHiddenFiles, item.isHidden {
                    return false
                }
                return item.url.isMediaFile
            }
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
            let values = try? entryURL.resourceValues(forKeys: resourceKeys)
            let item = Self.makeFileItem(from: entryURL, values: values)
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

    private static func makeFileItem(from entryURL: URL, values: URLResourceValues?) -> FileItem {
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
