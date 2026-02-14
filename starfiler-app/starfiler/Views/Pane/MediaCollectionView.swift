import AppKit

final class MediaCollectionView: NSCollectionView {
    weak var keyActionDelegate: MediaKeyActionDelegate?
    var didBecomeFirstResponderHandler: (() -> Void)?
    var dragSourceHandler: FileDragSource?
    var dragURLsProvider: (() -> [URL])?
    var onBookmarkJump: ((String) -> Void)?
    var onBookmarkJumpPending: ((BookmarkJumpHint) -> Void)?
    var onBookmarkJumpEnded: (() -> Void)?
    private var keyInterpreter = KeyInterpreter()
    private var bookmarkJumpInterpreter: BookmarkJumpInterpreter?
    private var mouseDownLocation: NSPoint?
    private var mouseDownEvent: NSEvent?
    private var isDragging = false
    private static let minimumDragDistance: CGFloat = 5

    override func keyDown(with event: NSEvent) {
        normalizeFilterModeForKeyboardInputIfNeeded()

        let isAwaitingBookmarkJump = bookmarkJumpInterpreter?.state != .idle

        if event.modifierFlags.contains(.command), !isAwaitingBookmarkJump {
            bookmarkJumpInterpreter?.reset()
            if let keyEvent = event.keyEvent {
                switch keyInterpreter.interpret(keyEvent) {
                case .action(let action):
                    if keyActionDelegate?.mediaCollectionView(self, didTrigger: action) == true {
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
            if keyActionDelegate?.mediaCollectionView(self, didTrigger: action) == true {
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

    override func mouseDown(with event: NSEvent) {
        mouseDownLocation = convert(event.locationInWindow, from: nil)
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

    func setVimMode(_ mode: VimMode) {
        keyInterpreter.setMode(mode)
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

    private func normalizeFilterModeForKeyboardInputIfNeeded() {
        guard keyInterpreter.mode == .filter else {
            return
        }

        // Collection input should always run in normal mode.
        // Filter mode is only valid while the search field is actively editing.
        keyInterpreter.setMode(.normal)
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
}

final class MediaCollectionItem: NSCollectionViewItem {
    static let identifier = NSUserInterfaceItemIdentifier("mediaCollectionItem")

    private let titleLabel = NSTextField(labelWithString: "")
    private let markBadge = NSImageView()

    override func loadView() {
        view = NSView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let imageView = NSImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.wantsLayer = true
        imageView.layer?.cornerRadius = 6
        imageView.layer?.masksToBounds = true
        self.imageView = imageView

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.alignment = .center
        titleLabel.font = .systemFont(ofSize: 11, weight: .regular)
        titleLabel.lineBreakMode = .byTruncatingMiddle
        titleLabel.maximumNumberOfLines = 2

        markBadge.translatesAutoresizingMaskIntoConstraints = false
        markBadge.image = NSImage(systemSymbolName: "star.fill", accessibilityDescription: "Marked")
        markBadge.contentTintColor = .systemOrange
        markBadge.isHidden = true

        view.wantsLayer = true
        view.layer?.cornerRadius = 8
        view.layer?.borderWidth = 1
        view.layer?.masksToBounds = true

        view.addSubview(imageView)
        view.addSubview(titleLabel)
        view.addSubview(markBadge)

        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: view.topAnchor, constant: 8),
            imageView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            imageView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
            imageView.heightAnchor.constraint(equalTo: imageView.widthAnchor, multiplier: 0.75),

            titleLabel.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 6),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 6),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -6),
            titleLabel.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor, constant: -8),

            markBadge.topAnchor.constraint(equalTo: view.topAnchor, constant: 4),
            markBadge.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -6)
        ])
    }

    override var isSelected: Bool {
        didSet {
            applySelectionAppearance()
        }
    }

    func configure(name: String, thumbnail: NSImage?, isMarked: Bool, palette: FilerThemePalette) {
        titleLabel.stringValue = name
        titleLabel.textColor = palette.primaryTextColor
        imageView?.image = thumbnail
        markBadge.isHidden = !isMarked
        markBadge.contentTintColor = palette.starAccentColor
        applySelectionAppearance(palette: palette)
    }

    private func applySelectionAppearance(palette: FilerThemePalette? = nil) {
        let palette = palette ?? FilerTheme.system.palette
        if isSelected {
            view.layer?.borderColor = palette.activeBorderColor.cgColor
            view.layer?.backgroundColor = palette.accentColor.withAlphaComponent(0.18).cgColor
        } else {
            view.layer?.borderColor = palette.inactiveBorderColor.cgColor
            view.layer?.backgroundColor = palette.tableBackgroundColor.withAlphaComponent(0.35).cgColor
        }
    }
}
