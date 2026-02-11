import Foundation

struct BookmarkEntry: Codable, Hashable, Sendable {
    var displayName: String
    var path: String
    var shortcutKey: String?

    init(displayName: String, path: String, shortcutKey: String? = nil) {
        self.displayName = displayName
        self.path = path
        self.shortcutKey = shortcutKey
    }
}

struct BookmarkGroup: Codable, Hashable, Sendable {
    var name: String
    var entries: [BookmarkEntry]
    var shortcutKey: String?
    var isDefault: Bool

    init(name: String, entries: [BookmarkEntry] = [], shortcutKey: String? = nil, isDefault: Bool = false) {
        self.name = name
        self.entries = entries
        self.shortcutKey = shortcutKey
        self.isDefault = isDefault
    }

    enum CodingKeys: String, CodingKey {
        case name, entries, shortcutKey, isDefault
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        entries = try container.decode([BookmarkEntry].self, forKey: .entries)
        shortcutKey = try container.decodeIfPresent(String.self, forKey: .shortcutKey)
        isDefault = try container.decodeIfPresent(Bool.self, forKey: .isDefault) ?? false
    }
}
