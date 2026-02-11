import AppKit

final class FileTableView: NSTableView {
    var keyDownHandler: ((NSEvent) -> Bool)?

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

        if keyDownHandler?(event) == true {
            return
        }

        super.keyDown(with: event)
    }

    private func configureTableBehavior() {
        usesAutomaticRowHeights = false
        rowHeight = 24
        allowsTypeSelect = false
        selectionHighlightStyle = .regular
    }
}
