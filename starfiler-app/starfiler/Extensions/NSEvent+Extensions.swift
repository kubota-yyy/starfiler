import AppKit

extension NSEvent {
    var keyEvent: KeyEvent? {
        guard type == .keyDown else {
            return nil
        }

        let modifiers = KeyModifiers(modifierFlags: modifierFlags)

        if let namedKey = Self.namedKey(for: keyCode) {
            return KeyEvent(key: namedKey, modifiers: modifiers)
        }

        guard let characters = charactersIgnoringModifiers, let scalar = characters.unicodeScalars.first else {
            return nil
        }

        return KeyEvent(key: String(scalar), modifiers: modifiers)
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
