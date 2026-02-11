import Foundation

struct BookmarkEntry: Codable, Hashable, Sendable {
    var displayName: String
    var path: String

    init(displayName: String, path: String) {
        self.displayName = displayName
        self.path = path
    }
}

struct BookmarkGroup: Codable, Hashable, Sendable {
    var name: String
    var entries: [BookmarkEntry]

    init(name: String, entries: [BookmarkEntry] = []) {
        self.name = name
        self.entries = entries
    }
}
