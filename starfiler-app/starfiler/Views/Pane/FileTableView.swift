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
    var onShortcutGuideUpdated: (([KeybindingHintCandidate], [KeyEvent], KeyModifiers) -> Void)?
    var onShortcutGuideEnded: (() -> Void)?
    var shortcutGuideEnabled = false {
        didSet {
            if !shortcutGuideEnabled {
                endShortcutGuideIfNeeded()
            }
        }
    }

    private static let minimumDragDistance: CGFloat = 5

    private var keyInterpreter = KeyInterpreter()
    private var bookmarkJumpInterpreter: BookmarkJumpInterpreter?
    private var mouseDownLocation: NSPoint?
    private var mouseDownEvent: NSEvent?
    private var isDragging = false
    private var isShortcutGuideVisible = false

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
        if isAwaitingBookmarkJump {
            endShortcutGuideIfNeeded()
        }

        if event.modifierFlags.contains(.command), !isAwaitingBookmarkJump {
            bookmarkJumpInterpreter?.reset()
            guard let keyEvent = event.keyEvent else {
                if updateShortcutGuideForModifierFlagsIfNeeded(event.modifierFlags) {
                    return
                }
                endShortcutGuideIfNeeded()
                super.keyDown(with: event)
                return
            }

            switch keyInterpreter.interpret(keyEvent) {
            case .action(let action):
                endShortcutGuideIfNeeded()
                if keyActionDelegate?.fileTableView(self, didTrigger: action) == true {
                    return
                }
            case .pending:
                updateShortcutGuideForPendingSequenceIfNeeded()
            case .unhandled:
                endShortcutGuideIfNeeded()
            }
            endShortcutGuideIfNeeded()
            super.keyDown(with: event)
            return
        }

        guard let keyEvent = event.keyEvent else {
            if updateShortcutGuideForModifierFlagsIfNeeded(event.modifierFlags) {
                return
            }
            endShortcutGuideIfNeeded()
            super.keyDown(with: event)
            return
        }

        if isAwaitingBookmarkJump, !keyEvent.modifiers.isEmpty, keyEvent.key != "Escape" {
            endShortcutGuideIfNeeded()
            return
        }

        if bookmarkJumpInterpreter != nil {
            if keyEvent.key == "Escape", bookmarkJumpInterpreter?.state != .idle {
                bookmarkJumpInterpreter?.reset()
                onBookmarkJumpEnded?()
                endShortcutGuideIfNeeded()
                return
            }

            let wasAwaitingBookmarkJump = bookmarkJumpInterpreter?.state != .idle

            switch bookmarkJumpInterpreter!.interpret(keyEvent, now: Date()) {
            case .jumpTo(let path):
                onBookmarkJumpEnded?()
                onBookmarkJump?(path)
                endShortcutGuideIfNeeded()
                return
            case .pending(let hint):
                onBookmarkJumpPending?(hint)
                endShortcutGuideIfNeeded()
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
            endShortcutGuideIfNeeded()
            super.keyDown(with: event)
            return
        }

        switch keyInterpreter.interpret(keyEvent) {
        case .action(let action):
            endShortcutGuideIfNeeded()
            if keyActionDelegate?.fileTableView(self, didTrigger: action) == true {
                return
            }
        case .pending:
            updateShortcutGuideForPendingSequenceIfNeeded()
            return
        case .unhandled:
            endShortcutGuideIfNeeded()
            if shouldFallbackToPaneSwitch(for: keyEvent),
               keyActionDelegate?.fileTableView(self, didTrigger: .switchPane) == true {
                return
            }
        }

        super.keyDown(with: event)
    }

    override func flagsChanged(with event: NSEvent) {
        defer { super.flagsChanged(with: event) }

        guard keyInterpreter.currentPendingSequence.isEmpty else {
            return
        }

        if updateShortcutGuideForModifierFlagsIfNeeded(event.modifierFlags) {
            return
        }

        endShortcutGuideIfNeeded()
    }

    private func updateShortcutGuideForModifierFlagsIfNeeded(_ modifierFlags: NSEvent.ModifierFlags) -> Bool {
        guard shortcutGuideEnabled else {
            return false
        }

        guard bookmarkJumpInterpreter?.state == .idle else {
            return false
        }

        let modifiers = KeyModifiers(modifierFlags: modifierFlags)
        guard !modifiers.isEmpty else {
            return false
        }

        let candidates = keyInterpreter.candidatesForInitialModifiers(modifiers)
        guard !candidates.isEmpty else {
            return false
        }

        onShortcutGuideUpdated?(candidates, [], modifiers)
        isShortcutGuideVisible = true
        return true
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
        endShortcutGuideIfNeeded()
    }

    func setSequenceTimeout(_ timeout: TimeInterval) {
        keyInterpreter.setTimeout(timeout)
    }

    func reloadKeybindings() {
        keyInterpreter = KeyInterpreter(
            mode: keyInterpreter.mode,
            timeout: keyInterpreter.timeout
        )
        endShortcutGuideIfNeeded()
    }

    func setBookmarkJumpConfig(_ config: BookmarksConfig) {
        bookmarkJumpInterpreter = BookmarkJumpInterpreter(bookmarksConfig: config)
        onBookmarkJumpEnded?()
        endShortcutGuideIfNeeded()
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

    private func updateShortcutGuideForPendingSequenceIfNeeded() {
        guard shortcutGuideEnabled else {
            endShortcutGuideIfNeeded()
            return
        }

        let pendingSequence = keyInterpreter.currentPendingSequence
        guard !pendingSequence.isEmpty else {
            endShortcutGuideIfNeeded()
            return
        }

        let firstEventHasModifier = pendingSequence.first?.modifiers.isEmpty == false
        guard firstEventHasModifier || isShortcutGuideVisible else {
            endShortcutGuideIfNeeded()
            return
        }

        let candidates = keyInterpreter.candidatesForPendingSequence()
        guard !candidates.isEmpty else {
            endShortcutGuideIfNeeded()
            return
        }

        onShortcutGuideUpdated?(candidates, pendingSequence, [])
        isShortcutGuideVisible = true
    }

    private func endShortcutGuideIfNeeded() {
        guard isShortcutGuideVisible else {
            return
        }

        isShortcutGuideVisible = false
        onShortcutGuideEnded?()
    }
}
