import AppKit

protocol KeyActionDelegate: AnyObject {
    func fileTableView(_ tableView: FileTableView, didTrigger action: KeyAction) -> Bool
}

final class FileTableView: NSTableView {
    weak var keyActionDelegate: (any KeyActionDelegate)?
    var didBecomeFirstResponderHandler: (() -> Void)?
    var shouldHandleMouseDown: ((NSEvent, NSPoint) -> Bool)?
    var dragSourceHandler: FileDragSource?
    var dropTargetHandler: FileDropTarget?
    var dragURLsProvider: (() -> [URL])?
    var onBookmarkJump: ((String) -> Void)?
    var onBookmarkJumpPending: ((BookmarkJumpHint) -> Void)?
    var onBookmarkJumpEnded: (() -> Void)?

    private static let minimumDragDistance: CGFloat = 5

    private var keyInterpreter = KeyInterpreter()
    private var bookmarkJumpInterpreter: BookmarkJumpInterpreter?
    private var mouseDownLocation: NSPoint?
    private var mouseDownEvent: NSEvent?
    private var isDragging = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configureTableBehavior()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureTableBehavior()
    }

    override func keyDown(with event: NSEvent) {
        normalizeFilterModeForKeyboardInputIfNeeded()

        let isAwaitingBookmarkJump = bookmarkJumpInterpreter?.state != .idle

        if event.modifierFlags.contains(.command), !isAwaitingBookmarkJump {
            bookmarkJumpInterpreter?.reset()
            if let keyEvent = event.keyEvent {
                switch keyInterpreter.interpret(keyEvent) {
                case .action(let action):
                    if keyActionDelegate?.fileTableView(self, didTrigger: action) == true {
                        return
                    }
                case .pending, .unhandled:
                    break
                }
            }
            super.keyDown(with: event)
            return
        }

        guard let keyEvent = event.keyEvent else {
            super.keyDown(with: event)
            return
        }

        if isAwaitingBookmarkJump, !keyEvent.modifiers.isEmpty, keyEvent.key != "Escape" {
            return
        }

        if bookmarkJumpInterpreter != nil {
            if keyEvent.key == "Escape", bookmarkJumpInterpreter?.state != .idle {
                bookmarkJumpInterpreter?.reset()
                onBookmarkJumpEnded?()
                return
            }

            let wasAwaitingBookmarkJump = bookmarkJumpInterpreter?.state != .idle

            switch bookmarkJumpInterpreter!.interpret(keyEvent, now: Date()) {
            case .jumpTo(let path):
                onBookmarkJumpEnded?()
                onBookmarkJump?(path)
                return
            case .pending(let hint):
                onBookmarkJumpPending?(hint)
                return
            case .unhandled:
                if wasAwaitingBookmarkJump {
                    onBookmarkJumpEnded?()
                }
                break
            }
        }

        if shouldPreferTypeSelect(for: keyEvent) {
            keyInterpreter.clearPendingSequence()
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
            if shouldFallbackToPaneSwitch(for: keyEvent),
               keyActionDelegate?.fileTableView(self, didTrigger: .switchPane) == true {
                return
            }
        }

        super.keyDown(with: event)
    }

    override func mouseDown(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        if shouldHandleMouseDown?(event, location) == true {
            mouseDownLocation = nil
            mouseDownEvent = nil
            isDragging = false
            return
        }

        mouseDownLocation = location
        mouseDownEvent = event
        isDragging = false
        super.mouseDown(with: event)
    }

    override func mouseDragged(with event: NSEvent) {
        guard !isDragging else {
            return
        }

        guard let origin = mouseDownLocation else {
            super.mouseDragged(with: event)
            return
        }

        let current = convert(event.locationInWindow, from: nil)
        let dx = current.x - origin.x
        let dy = current.y - origin.y
        let distance = sqrt(dx * dx + dy * dy)

        guard distance >= Self.minimumDragDistance else {
            super.mouseDragged(with: event)
            return
        }

        if
            let dragSourceHandler,
            let dragURLsProvider,
            dragSourceHandler.beginDragging(from: self, with: mouseDownEvent ?? event, urls: dragURLsProvider())
        {
            isDragging = true
            return
        }

        super.mouseDragged(with: event)
    }

    override func mouseUp(with event: NSEvent) {
        mouseDownLocation = nil
        mouseDownEvent = nil
        isDragging = false
        super.mouseUp(with: event)
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

    func reloadKeybindings() {
        keyInterpreter = KeyInterpreter(
            mode: keyInterpreter.mode,
            timeout: keyInterpreter.timeout
        )
    }

    func setBookmarkJumpConfig(_ config: BookmarksConfig) {
        bookmarkJumpInterpreter = BookmarkJumpInterpreter(bookmarksConfig: config)
        onBookmarkJumpEnded?()
    }

    private func configureTableBehavior() {
        usesAutomaticRowHeights = false
        rowHeight = 24
        allowsTypeSelect = true
        selectionHighlightStyle = .regular
    }

    private func shouldPreferTypeSelect(for event: KeyEvent) -> Bool {
        guard event.key.count == 1 else {
            return false
        }

        if event.key == "/" {
            return false
        }

        let unsupportedModifiers = event.modifiers.subtracting([.shift])
        return unsupportedModifiers.isEmpty
    }

    private func normalizeFilterModeForKeyboardInputIfNeeded() {
        guard keyInterpreter.mode == .filter else {
            return
        }

        // Table input should always run in normal mode.
        // Filter mode is only valid while the search field is actively editing.
        keyInterpreter.setMode(.normal)
    }

    private func shouldFallbackToPaneSwitch(for event: KeyEvent) -> Bool {
        guard event.key == "Tab" else {
            return false
        }

        let unsupportedModifiers = event.modifiers.subtracting([.shift])
        return unsupportedModifiers.isEmpty
    }
}
