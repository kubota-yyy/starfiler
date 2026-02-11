import AppKit

final class FileTableView: NSTableView {
    var keyDownHandler: ((NSEvent) -> Bool)?
    var tabKeyHandler: (() -> Bool)?
    var didBecomeFirstResponderHandler: (() -> Void)?

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
            super.keyDown(with: event)
            return
        }

        if event.keyCode == 48, tabKeyHandler?() == true {
            return
        }

        if keyDownHandler?(event) == true {
            return
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

    private func configureTableBehavior() {
        usesAutomaticRowHeights = false
        rowHeight = 24
        allowsTypeSelect = false
        selectionHighlightStyle = .regular
    }
}
