import Foundation

protocol FileSystemProviding {
    func contentsOfDirectory(at url: URL) async throws -> [FileItem]
}

struct FileSystemService: FileSystemProviding {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func contentsOfDirectory(at url: URL) async throws -> [FileItem] {
        let resourceKeys: Set<URLResourceKey> = [
            .nameKey,
            .isDirectoryKey,
            .isRegularFileKey,
            .fileSizeKey,
            .contentModificationDateKey,
            .isHiddenKey,
            .isSymbolicLinkKey,
            .isPackageKey
        ]

        let urls = try fileManager.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: Array(resourceKeys),
            options: [.skipsSubdirectoryDescendants]
        )

        return urls.map { entryURL in
            let values = try? entryURL.resourceValues(forKeys: resourceKeys)
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
}
