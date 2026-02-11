import Foundation

extension URL {
    var isDirectory: Bool {
        (try? resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
    }

    var isPackage: Bool {
        (try? resourceValues(forKeys: [.isPackageKey]).isPackage) ?? false
    }

    var displayName: String {
        FileManager.default.displayName(atPath: path)
    }
}
