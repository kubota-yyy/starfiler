import AppKit

final class KeyRecorderView: NSView {
    var onKeyRecorded: ((String) -> Void)?
    var onCancelled: (() -> Void)?

    private let displayLabel = NSTextField(labelWithString: "")
    private let hintLabel = NSTextField(labelWithString: "Press a key combination...")
    private var isRecording = false
    private var recordedSequence: String?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    func startRecording(currentBinding: String) {
        displayLabel.stringValue = currentBinding
        isRecording = true
        hintLabel.isHidden = false
        needsDisplay = true
        window?.makeFirstResponder(self)
    }

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        guard isRecording else {
            super.keyDown(with: event)
            return
        }

        if event.keyCode == 53 {
            cancelRecording()
            return
        }

        let sequence = buildSequenceString(from: event)
        guard let sequence else { return }

        recordedSequence = sequence
        displayLabel.stringValue = formatDisplaySequence(sequence)
        isRecording = false
        hintLabel.isHidden = true
        needsDisplay = true
        onKeyRecorded?(sequence)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let borderColor: NSColor = isRecording ? .controlAccentColor : .separatorColor
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: 4, yRadius: 4)
        borderColor.setStroke()
        path.lineWidth = isRecording ? 2.0 : 1.0
        path.stroke()

        if isRecording {
            NSColor.controlAccentColor.withAlphaComponent(0.06).setFill()
            path.fill()
        }
    }

    private func cancelRecording() {
        isRecording = false
        hintLabel.isHidden = true
        needsDisplay = true
        onCancelled?()
    }

    private func setupView() {
        wantsLayer = true

        displayLabel.translatesAutoresizingMaskIntoConstraints = false
        displayLabel.font = .monospacedSystemFont(ofSize: 13, weight: .medium)
        displayLabel.alignment = .center

        hintLabel.translatesAutoresizingMaskIntoConstraints = false
        hintLabel.font = .systemFont(ofSize: 11)
        hintLabel.textColor = .secondaryLabelColor
        hintLabel.alignment = .center
        hintLabel.isHidden = true

        addSubview(displayLabel)
        addSubview(hintLabel)

        NSLayoutConstraint.activate([
            displayLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            displayLabel.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -8),

            hintLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            hintLabel.topAnchor.constraint(equalTo: displayLabel.bottomAnchor, constant: 4),
        ])
    }

    private func buildSequenceString(from event: NSEvent) -> String? {
        var parts: [String] = []

        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if modifiers.contains(.control) { parts.append("Ctrl") }
        if modifiers.contains(.option) { parts.append("Alt") }
        if modifiers.contains(.shift) { parts.append("Shift") }
        if modifiers.contains(.command) { parts.append("Cmd") }

        guard let characters = event.charactersIgnoringModifiers?.lowercased(),
              !characters.isEmpty else {
            return nil
        }

        let keyName = mapKeyName(characters: characters, keyCode: event.keyCode)
        parts.append(keyName)

        return parts.joined(separator: "-")
    }

    private func mapKeyName(characters: String, keyCode: UInt16) -> String {
        switch keyCode {
        case 36: return "Return"
        case 48: return "Tab"
        case 49: return "Space"
        case 51: return "Backspace"
        case 53: return "Escape"
        case 117: return "Delete"
        case 116: return "PageUp"
        case 121: return "PageDown"
        case 115: return "Home"
        case 119: return "End"
        case 123: return "Left"
        case 124: return "Right"
        case 125: return "Down"
        case 126: return "Up"
        default:
            if characters.count == 1 {
                return characters
            }
            return characters
        }
    }

    private func formatDisplaySequence(_ sequence: String) -> String {
        sequence
            .replacingOccurrences(of: "Ctrl-", with: "^")
            .replacingOccurrences(of: "Shift-", with: "\u{21E7}")
            .replacingOccurrences(of: "Alt-", with: "\u{2325}")
            .replacingOccurrences(of: "Cmd-", with: "\u{2318}")
    }
}
