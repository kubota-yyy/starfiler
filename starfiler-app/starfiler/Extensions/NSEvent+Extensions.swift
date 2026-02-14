import AppKit

extension NSEvent {
    var keyEvent: KeyEvent? {
        guard type == .keyDown else {
            return nil
        }

        var modifiers = KeyModifiers(modifierFlags: modifierFlags)

        if let namedKey = Self.namedKey(for: keyCode) {
            return KeyEvent(key: namedKey, modifiers: modifiers)
        }

        guard let scalar = resolvedPrintableScalar() else {
            return nil
        }

        if modifiers.contains(.shift), !Self.isAlphabetic(scalar) {
            modifiers.remove(.shift)
        }

        return KeyEvent(key: String(scalar), modifiers: modifiers)
    }

    private func resolvedPrintableScalar() -> UnicodeScalar? {
        // Ctrl/Alt/Cmd combinations often produce control or alternate glyphs in `characters`.
        // Prefer the physical key representation so bindings like Ctrl-b resolve to "b".
        let shouldPreferIgnoringModifiers = !modifierFlags
            .intersection([.control, .option, .command])
            .isEmpty

        if shouldPreferIgnoringModifiers {
            if let charactersIgnoringModifiers, let scalar = charactersIgnoringModifiers.unicodeScalars.first {
                return scalar
            }
            if let characters, let scalar = characters.unicodeScalars.first {
                return scalar
            }
        } else {
            if let characters, let scalar = characters.unicodeScalars.first {
                return scalar
            }
            if let charactersIgnoringModifiers, let scalar = charactersIgnoringModifiers.unicodeScalars.first {
                return scalar
            }
        }

        return nil
    }

    private static func isAlphabetic(_ scalar: UnicodeScalar) -> Bool {
        let value = String(scalar)
        return value.lowercased() != value.uppercased()
    }

    private static func namedKey(for keyCode: UInt16) -> String? {
        switch keyCode {
        case 36, 76:
            return "Return"
        case 48:
            return "Tab"
        case 49:
            return "Space"
        case 51:
            return "Backspace"
        case 53:
            return "Escape"
        case 116:
            return "PageUp"
        case 121:
            return "PageDown"
        case 115:
            return "Home"
        case 119:
            return "End"
        case 123:
            return "ArrowLeft"
        case 124:
            return "ArrowRight"
        case 125:
            return "ArrowDown"
        case 126:
            return "ArrowUp"
        default:
            return nil
        }
    }
}

extension KeyModifiers {
    init(modifierFlags: NSEvent.ModifierFlags) {
        let flags = modifierFlags.intersection([.shift, .control, .option, .command])
        var modifiers: KeyModifiers = []

        if flags.contains(.shift) {
            modifiers.insert(.shift)
        }
        if flags.contains(.control) {
            modifiers.insert(.control)
        }
        if flags.contains(.option) {
            modifiers.insert(.option)
        }
        if flags.contains(.command) {
            modifiers.insert(.command)
        }

        self = modifiers
    }
}
