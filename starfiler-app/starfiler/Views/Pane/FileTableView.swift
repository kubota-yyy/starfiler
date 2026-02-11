import AppKit

protocol KeyActionDelegate: AnyObject {
    func fileTableView(_ tableView: FileTableView, didTrigger action: KeyAction) -> Bool
}

final class FileTableView: NSTableView {
    weak var keyActionDelegate: (any KeyActionDelegate)?
    var didBecomeFirstResponderHandler: (() -> Void)?

    private var keyInterpreter = KeyInterpreter()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configureTableBehavior()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureTableBehavior()
    }

    override func keyDown(with event: NSEvent) {
        if event.modifierFlags.contains(.command) {
            keyInterpreter.clearPendingSequence()
            super.keyDown(with: event)
            return
        }

        guard let keyEvent = event.keyEvent else {
            super.keyDown(with: event)
            return
        }

        switch keyInterpreter.interpret(keyEvent) {
        case .action(let action):
            if keyActionDelegate?.fileTableView(self, didTrigger: action) == true {
                return
            }
        case .pending:
            return
        case .unhandled:
            break
        }

        super.keyDown(with: event)
    }

    override func becomeFirstResponder() -> Bool {
        let didBecome = super.becomeFirstResponder()
        if didBecome {
            didBecomeFirstResponderHandler?()
        }
        return didBecome
    }

    func setVimMode(_ mode: VimMode) {
        keyInterpreter.setMode(mode)
    }

    func setSequenceTimeout(_ timeout: TimeInterval) {
        keyInterpreter.setTimeout(timeout)
    }

    private func configureTableBehavior() {
        usesAutomaticRowHeights = false
        rowHeight = 24
        allowsTypeSelect = false
        selectionHighlightStyle = .regular
    }
}
