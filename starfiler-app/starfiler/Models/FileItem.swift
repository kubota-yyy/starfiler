import Foundation

struct FileItem: Hashable, Identifiable, Sendable {
    let url: URL
    let name: String
    let isDirectory: Bool
    let size: Int64?
    let dateModified: Date?
    let isHidden: Bool
    let isSymlink: Bool
    let isPackage: Bool

    var id: URL { url }
}
