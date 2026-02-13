import Foundation

enum BookmarkShortcut {
    private static let namedAliases: Set<String> = [
        "space",
        "return",
        "enter",
        "escape",
        "esc",
        "tab",
        "backspace",
        "delete",
        "pageup",
        "pagedown",
        "home",
        "end",
        "left",
        "arrowleft",
        "right",
        "arrowright",
        "up",
        "arrowup",
        "down",
        "arrowdown",
    ]

    static func tokens(from rawShortcut: String?) -> [String] {
        guard let rawShortcut else {
            return []
        }

        let trimmed = rawShortcut.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return []
        }

        return trimmed
            .split(whereSeparator: \.isWhitespace)
            .flatMap { tokens(fromComponent: String($0)) }
    }

    static func canonical(from rawShortcut: String?) -> String? {
        let tokens = tokens(from: rawShortcut)
        guard !tokens.isEmpty else {
            return nil
        }
        return tokens.map { $0.lowercased() }.joined(separator: " ")
    }

    static func hint(groupShortcut: String?, entryShortcut: String?, isDefaultGroup: Bool) -> String? {
        let entryTokens = tokens(from: entryShortcut)
        guard !entryTokens.isEmpty else {
            return nil
        }

        let allTokens: [String]
        if isDefaultGroup {
            allTokens = entryTokens
        } else {
            let groupTokens = tokens(from: groupShortcut)
            guard !groupTokens.isEmpty else {
                return nil
            }
            allTokens = groupTokens + entryTokens
        }

        return "' " + allTokens.map(displayToken(for:)).joined(separator: " ")
    }

    static func displayToken(for normalizedToken: String) -> String {
        switch normalizedToken {
        case "Return":
            return "Enter"
        case "Escape":
            return "Esc"
        default:
            return normalizedToken
        }
    }

    private static func tokens(fromComponent component: String) -> [String] {
        let trimmed = component.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return []
        }

        if trimmed.count == 1 {
            return [normalizeToken(trimmed)]
        }

        if namedAliases.contains(trimmed.lowercased()) {
            return [normalizeToken(trimmed)]
        }

        return trimmed.map { normalizeToken(String($0)) }
    }

    private static func normalizeToken(_ raw: String) -> String {
        switch raw.lowercased() {
        case "space":
            return "Space"
        case "return", "enter":
            return "Return"
        case "escape", "esc":
            return "Escape"
        case "tab":
            return "Tab"
        case "backspace":
            return "Backspace"
        case "delete":
            return "Delete"
        case "pageup":
            return "PageUp"
        case "pagedown":
            return "PageDown"
        case "home":
            return "Home"
        case "end":
            return "End"
        case "left", "arrowleft":
            return "ArrowLeft"
        case "right", "arrowright":
            return "ArrowRight"
        case "up", "arrowup":
            return "ArrowUp"
        case "down", "arrowdown":
            return "ArrowDown"
        default:
            if raw.count == 1 {
                return raw.lowercased()
            }
            return raw
        }
    }
}

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
