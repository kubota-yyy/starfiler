import AppKit

protocol KeyActionDelegate: AnyObject {
    func fileTableView(_ tableView: FileTableView, didTrigger action: KeyAction) -> Bool
}

final class FileTableView: NSTableView {
    weak var keyActionDelegate: (any KeyActionDelegate)?
    var didBecomeFirstResponderHandler: (() -> Void)?
    var dragSourceHandler: FileDragSource?
    var dropTargetHandler: FileDropTarget?
    var dragURLsProvider: (() -> [URL])?
    var onBookmarkJump: ((String) -> Void)?
    var onBookmarkJumpPending: ((String) -> Void)?

    private var keyInterpreter = KeyInterpreter()
    private var bookmarkJumpInterpreter: BookmarkJumpInterpreter?

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
            bookmarkJumpInterpreter?.reset()
            super.keyDown(with: event)
            return
        }

        guard let keyEvent = event.keyEvent else {
            super.keyDown(with: event)
            return
        }

        if bookmarkJumpInterpreter != nil {
            switch bookmarkJumpInterpreter!.interpret(keyEvent, now: Date()) {
            case .jumpTo(let path):
                onBookmarkJump?(path)
                return
            case .pending(let hint):
                onBookmarkJumpPending?(hint)
                return
            case .unhandled:
                break
            }
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

    override func mouseDragged(with event: NSEvent) {
        if
            let dragSourceHandler,
            let dragURLsProvider,
            dragSourceHandler.beginDragging(from: self, with: event, urls: dragURLsProvider())
        {
            return
        }

        super.mouseDragged(with: event)
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        dropTargetHandler?.draggingEntered(sender) ?? []
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        dropTargetHandler?.draggingUpdated(sender) ?? []
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        dropTargetHandler?.draggingExited(sender)
    }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        dropTargetHandler?.prepareForDragOperation(sender) ?? false
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        dropTargetHandler?.performDragOperation(sender) ?? false
    }

    override func concludeDragOperation(_ sender: NSDraggingInfo?) {
        dropTargetHandler?.concludeDragOperation(sender)
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

    func setBookmarkJumpConfig(_ config: BookmarksConfig) {
        bookmarkJumpInterpreter = BookmarkJumpInterpreter(bookmarksConfig: config)
    }

    private func configureTableBehavior() {
        usesAutomaticRowHeights = false
        rowHeight = 24
        allowsTypeSelect = false
        selectionHighlightStyle = .regular
    }
}
