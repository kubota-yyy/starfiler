import Foundation
@testable import Starfiler

enum FileItemFactory {
    static func file(
        name: String = "document.txt",
        size: Int64? = 1024,
        dateModified: Date? = Date(),
        isHidden: Bool = false,
        isSymlink: Bool = false,
        parentDirectory: URL = URL(fileURLWithPath: "/tmp/test")
    ) -> FileItem {
        FileItem(
            url: parentDirectory.appendingPathComponent(name),
            name: name,
            isDirectory: false,
            size: size,
            dateModified: dateModified,
            isHidden: isHidden,
            isSymlink: isSymlink,
            isPackage: false
        )
    }

    static func directory(
        name: String = "Folder",
        dateModified: Date? = Date(),
        isHidden: Bool = false,
        isPackage: Bool = false,
        parentDirectory: URL = URL(fileURLWithPath: "/tmp/test")
    ) -> FileItem {
        FileItem(
            url: parentDirectory.appendingPathComponent(name, isDirectory: true),
            name: name,
            isDirectory: true,
            size: nil,
            dateModified: dateModified,
            isHidden: isHidden,
            isSymlink: false,
            isPackage: isPackage
        )
    }

    static func sampleItems(
        count: Int = 5,
        parentDirectory: URL = URL(fileURLWithPath: "/tmp/test")
    ) -> [FileItem] {
        guard count > 0 else { return [] }

        let referenceDate = Date(timeIntervalSince1970: 1_700_000_000) // 2023-11-14

        return (0..<count).map { index in
            let isDir = index % 3 == 0
            let name = isDir ? "folder_\(index)" : "file_\(index).txt"
            let size: Int64? = isDir ? nil : Int64((index + 1) * 512)
            let modified = referenceDate.addingTimeInterval(Double(index) * 3600)

            return FileItem(
                url: parentDirectory.appendingPathComponent(name, isDirectory: isDir),
                name: name,
                isDirectory: isDir,
                size: size,
                dateModified: modified,
                isHidden: false,
                isSymlink: false,
                isPackage: false
            )
        }
    }
}
