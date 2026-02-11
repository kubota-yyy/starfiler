import Foundation

struct KeyEvent: Hashable, Codable, Sendable {
    let key: String
    let modifiers: KeyModifiers

    init(key: String, modifiers: KeyModifiers = []) {
        self.key = Self.normalizeKey(key)
        self.modifiers = modifiers
    }

    private static func normalizeKey(_ rawKey: String) -> String {
        switch rawKey.lowercased() {
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
            if rawKey.count == 1 {
                return rawKey.lowercased()
            }
            return rawKey
        }
    }
}

struct KeyModifiers: OptionSet, Hashable, Codable, Sendable {
    let rawValue: Int

    init(rawValue: Int) {
        self.rawValue = rawValue
    }

    static let shift = KeyModifiers(rawValue: 1 << 0)
    static let control = KeyModifiers(rawValue: 1 << 1)
    static let option = KeyModifiers(rawValue: 1 << 2)
    static let command = KeyModifiers(rawValue: 1 << 3)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.init(rawValue: try container.decode(Int.self))
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}
