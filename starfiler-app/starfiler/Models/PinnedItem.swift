import Foundation

struct PinnedItem: Codable, Hashable, Sendable {
    let path: String
    var displayName: String
    var isDirectory: Bool
    var pinnedAt: Date

    init(path: String, displayName: String, isDirectory: Bool = true, pinnedAt: Date = Date()) {
        self.path = path
        self.displayName = displayName
        self.isDirectory = isDirectory
        self.pinnedAt = pinnedAt
    }
}
