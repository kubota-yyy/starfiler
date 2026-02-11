import AppKit

protocol KeyActionDelegate: AnyObject {
    func fileTableView(_ tableView: FileTableView, didTrigger action: KeyAction) -> Bool
}

private final class BookmarkJumpHintViewController: NSViewController {
    private let hint: BookmarkJumpHint

    init(hint: BookmarkJumpHint) {
        self.hint = hint
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = NSTextField(labelWithString: hint.title)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        titleLabel.textColor = .labelColor

        let candidatesText = hint.candidates.map { "[\($0.key)] \($0.label)" }.joined(separator: "\n")
        let candidatesLabel = NSTextField(wrappingLabelWithString: candidatesText)
        candidatesLabel.translatesAutoresizingMaskIntoConstraints = false
        candidatesLabel.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        candidatesLabel.textColor = .secondaryLabelColor
        candidatesLabel.maximumNumberOfLines = 12

        container.addSubview(titleLabel)
        container.addSubview(candidatesLabel)

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            titleLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 10),

            candidatesLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            candidatesLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            candidatesLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 6),
            candidatesLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -10),

            container.widthAnchor.constraint(greaterThanOrEqualToConstant: 240),
        ])

        view = container
    }
}

final class FileTableView: NSTableView {
    weak var keyActionDelegate: (any KeyActionDelegate)?
    var didBecomeFirstResponderHandler: (() -> Void)?
    var dragSourceHandler: FileDragSource?
    var dropTargetHandler: FileDropTarget?
    var dragURLsProvider: (() -> [URL])?
    var onBookmarkJump: ((String) -> Void)?
    var onBookmarkJumpPending: ((BookmarkJumpHint) -> Void)?

    private static let minimumDragDistance: CGFloat = 5

    private var keyInterpreter = KeyInterpreter()
    private var bookmarkJumpInterpreter: BookmarkJumpInterpreter?
    private var bookmarkJumpPopover: NSPopover?
    private var mouseDownLocation: NSPoint?
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
        if event.modifierFlags.contains(.command) {
            keyInterpreter.clearPendingSequence()
            bookmarkJumpInterpreter?.reset()
            closeBookmarkJumpPopover()
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
                closeBookmarkJumpPopover()
                onBookmarkJump?(path)
                return
            case .pending(let hint):
                onBookmarkJumpPending?(hint)
                showBookmarkJumpPopover(hint: hint)
                return
            case .unhandled:
                closeBookmarkJumpPopover()
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

    override func mouseDown(with event: NSEvent) {
        closeBookmarkJumpPopover()
        bookmarkJumpInterpreter?.reset()
        mouseDownLocation = convert(event.locationInWindow, from: nil)
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
            dragSourceHandler.beginDragging(from: self, with: event, urls: dragURLsProvider())
        {
            isDragging = true
            return
        }

        super.mouseDragged(with: event)
    }

    override func mouseUp(with event: NSEvent) {
        mouseDownLocation = nil
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
        closeBookmarkJumpPopover()
    }

    private func configureTableBehavior() {
        usesAutomaticRowHeights = false
        rowHeight = 24
        allowsTypeSelect = false
        selectionHighlightStyle = .regular
    }

    private func showBookmarkJumpPopover(hint: BookmarkJumpHint) {
        guard window != nil else {
            return
        }

        let popover = bookmarkJumpPopover ?? NSPopover()
        popover.behavior = .applicationDefined
        popover.animates = false
        let visibleCandidateCount = min(max(hint.candidates.count, 1), 12)
        popover.contentSize = NSSize(width: 280, height: CGFloat(40 + (visibleCandidateCount * 20)))
        popover.contentViewController = BookmarkJumpHintViewController(hint: hint)

        if !popover.isShown {
            bookmarkJumpPopover = popover
            popover.show(relativeTo: bounds, of: self, preferredEdge: .maxY)
        }
    }

    private func closeBookmarkJumpPopover() {
        guard let bookmarkJumpPopover, bookmarkJumpPopover.isShown else {
            return
        }
        bookmarkJumpPopover.performClose(nil)
    }
}
