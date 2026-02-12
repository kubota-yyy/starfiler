import AppKit
import AVFoundation
import ImageIO

private final class AppearanceTrackingView: NSView {
    var onAppearanceChanged: (() -> Void)?

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        onAppearanceChanged?()
    }
}

private final class MarkedRowView: NSTableRowView {
    var isMarkedRow = false
    var isVisualMode = false
    var markedColor = NSColor.systemOrange.withAlphaComponent(0.14)
    var visualMarkedColor = NSColor.controlAccentColor.withAlphaComponent(0.22)

    override func drawBackground(in dirtyRect: NSRect) {
        guard isMarkedRow else {
            super.drawBackground(in: dirtyRect)
            return
        }

        let color = isVisualMode ? visualMarkedColor : markedColor

        color.setFill()
        dirtyRect.fill()
    }
}

private final class FileNameCellView: NSTableCellView {
    private let iconView = NSImageView()
    private let markStarView = NSImageView()
    private let nameLabel = NSTextField(labelWithString: "")
    private var iconWidthConstraint: NSLayoutConstraint?
    private var iconHeightConstraint: NSLayoutConstraint?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configureView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureView()
    }

    func setName(_ text: String, textColor: NSColor) {
        nameLabel.stringValue = text
        nameLabel.textColor = textColor
    }

    func setIcon(_ image: NSImage?, size: CGFloat) {
        iconView.image = image

        let clamped = min(max(size, 12), 40)
        iconWidthConstraint?.constant = clamped
        iconHeightConstraint?.constant = clamped
    }

    func setMarkStar(visible: Bool, color: NSColor) {
        markStarView.isHidden = !visible
        markStarView.contentTintColor = color
    }

    private func configureView() {
        identifier = NSUserInterfaceItemIdentifier("nameCell")

        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.imageScaling = .scaleProportionallyUpOrDown

        markStarView.translatesAutoresizingMaskIntoConstraints = false
        markStarView.image = NSImage(systemSymbolName: "star.fill", accessibilityDescription: "Marked")
        markStarView.imageScaling = .scaleProportionallyDown
        markStarView.isHidden = true

        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.lineBreakMode = .byTruncatingMiddle

        textField = nameLabel
        imageView = iconView

        addSubview(iconView)
        addSubview(markStarView)
        addSubview(nameLabel)

        let iconWidthConstraint = iconView.widthAnchor.constraint(equalToConstant: 16)
        let iconHeightConstraint = iconView.heightAnchor.constraint(equalToConstant: 16)
        self.iconWidthConstraint = iconWidthConstraint
        self.iconHeightConstraint = iconHeightConstraint

        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconWidthConstraint,
            iconHeightConstraint,

            markStarView.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 3),
            markStarView.centerYAnchor.constraint(equalTo: centerYAnchor),
            markStarView.widthAnchor.constraint(equalToConstant: 12),
            markStarView.heightAnchor.constraint(equalToConstant: 12),

            nameLabel.leadingAnchor.constraint(equalTo: markStarView.trailingAnchor, constant: 3),
            nameLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            nameLabel.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }
}

private final class BookmarkJumpOverlayView: NSView {
    private let titleLabel = NSTextField(labelWithString: "")
    private let candidatesLabel = NSTextField(wrappingLabelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configureView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureView()
    }

    func update(with hint: BookmarkJumpHint) {
        titleLabel.stringValue = hint.title
        candidatesLabel.stringValue = hint.candidates
            .map { "[\($0.key)] \($0.label)" }
            .joined(separator: "\n")
    }

    func applyPalette(_ palette: FilerThemePalette, backgroundOpacity: CGFloat) {
        _ = backgroundOpacity
        layer?.backgroundColor = palette.windowBackgroundColor.cgColor
        layer?.borderColor = palette.starAccentColor.withAlphaComponent(0.5).cgColor
        titleLabel.textColor = palette.primaryTextColor
        candidatesLabel.textColor = palette.secondaryTextColor
    }

    private func configureView() {
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        layer?.cornerRadius = 8
        layer?.borderWidth = 1
        layer?.masksToBounds = true

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .systemFont(ofSize: 12, weight: .semibold)

        candidatesLabel.translatesAutoresizingMaskIntoConstraints = false
        candidatesLabel.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        candidatesLabel.maximumNumberOfLines = 12
        candidatesLabel.lineBreakMode = .byTruncatingMiddle

        addSubview(titleLabel)
        addSubview(candidatesLabel)

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 10),

            candidatesLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            candidatesLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            candidatesLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 6),
            candidatesLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10),
        ])
    }
}

protocol MediaKeyActionDelegate: AnyObject {
    func mediaCollectionView(_ collectionView: MediaCollectionView, didTrigger action: KeyAction) -> Bool
}

final class MediaCollectionView: NSCollectionView {
    weak var keyActionDelegate: MediaKeyActionDelegate?
    var didBecomeFirstResponderHandler: (() -> Void)?
    var dragSourceHandler: FileDragSource?
    var dragURLsProvider: (() -> [URL])?
    private var keyInterpreter = KeyInterpreter()
    private var mouseDownLocation: NSPoint?
    private var isDragging = false
    private static let minimumDragDistance: CGFloat = 5

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

    func setVimMode(_ mode: VimMode) {
        keyInterpreter.setMode(mode)
    }

    func reloadKeybindings() {
        keyInterpreter = KeyInterpreter(
            mode: keyInterpreter.mode,
            timeout: keyInterpreter.timeout
        )
    }
}

private final class MediaCollectionItem: NSCollectionViewItem {
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

final class FilePaneViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate, NSCollectionViewDataSource, NSCollectionViewDelegate, NSCollectionViewDelegateFlowLayout, NSMenuDelegate, KeyActionDelegate, MediaKeyActionDelegate, NSTextFieldDelegate, NSSearchFieldDelegate {
    private enum SearchMode: Int {
        case filter = 0
        case spotlight = 1

        var menuTitle: String {
            switch self {
            case .filter:
                return "Filter (Current Folder)"
            case .spotlight:
                return "Spotlight Search"
            }
        }

        var placeholder: String {
            switch self {
            case .filter:
                return "Filter files in current folder..."
            case .spotlight:
                return "Search with Spotlight..."
            }
        }
    }

    private enum Column {
        static let name = NSUserInterfaceItemIdentifier("name")
        static let size = NSUserInterfaceItemIdentifier("size")
        static let modified = NSUserInterfaceItemIdentifier("modified")
    }

    private enum Cell {
        static let name = NSUserInterfaceItemIdentifier("nameCell")
        static let text = NSUserInterfaceItemIdentifier("textCell")
    }

    private static let byteFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter
    }()

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd HH:mm"
        return formatter
    }()

    private let viewModel: FilePaneViewModel
    private var keybindingManager = KeybindingManager()
    private let headerView = NSView()
    private let navigationStackView = NSStackView()
    private let backPeekButton = NSButton(title: "", target: nil, action: nil)
    private let pathControl = NSPathControl()
    private let forwardPeekButton = NSButton(title: "", target: nil, action: nil)
    private let searchControlsStackView = NSStackView()
    private let displayModeControl = NSSegmentedControl(labels: ["Files", "Media"], trackingMode: .selectOne, target: nil, action: nil)
    private let mediaRecursiveButton = NSButton(checkboxWithTitle: "Recursive", target: nil, action: nil)
    private let searchField = NSSearchField()
    private let scrollView = NSScrollView()
    private let bookmarkJumpOverlayView = BookmarkJumpOverlayView()
    private let tableView = FileTableView()
    private let mediaCollectionLayout = NSCollectionViewFlowLayout()
    private let mediaCollectionView = MediaCollectionView()
    private let fileDragSource = FileDragSource()

    private lazy var fileDropTarget = FileDropTarget { [weak self] in
        self?.viewModel.paneState.currentDirectory ?? UserPaths.homeDirectoryURL
    }

    private var isPaneActive = false
    private var isDropTargetHighlighted = false
    private var vimModeState = VimModeState()
    private var filerTheme: FilerTheme = .system
    private var backgroundOpacity: CGFloat = 1.0
    private var fileIconSize: CGFloat = 16
    private let iconCache = NSCache<NSString, NSImage>()
    private let thumbnailCache = NSCache<NSString, NSImage>()
    private var thumbnailTasks: [NSString: Task<Void, Never>] = [:]
    private var currentSearchMode: SearchMode = .filter
    private var searchMenuModeItems: [SearchMode: NSMenuItem] = [:]
    private var searchMenuScopeItems: [SpotlightSearchScope: NSMenuItem] = [:]
    private var currentDisplayMode: PaneDisplayMode = .browser
    private var starEffectsEnabled = true
    private var animationEffectSettings = AnimationEffectSettings.allEnabled
    private weak var lastCursorRippleLayer: CALayer?

    var onStatusChanged: ((String, Int, Int) -> Void)?
    var onSelectionChanged: ((FileItem?) -> Void)?
    var onTabPressed: (() -> Bool)?
    var onDidRequestActivate: (() -> Void)?
    var onFileOperationRequested: ((KeyAction) -> Bool)?
    var onBookmarkJump: ((String) -> Void)?
    var onDropOperationCompleted: ((NSDragOperation, Int) -> Void)?
    var onSpotlightSearchScopeChanged: ((SpotlightSearchScope) -> Void)?
    var onDirectoryLoadFailed: ((URL, Error) -> Void)?

    init(viewModel: FilePaneViewModel) {
        self.viewModel = viewModel
        self.currentDisplayMode = viewModel.displayMode
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        let containerView = AppearanceTrackingView()
        containerView.onAppearanceChanged = { [weak self] in
            self?.updateActiveAppearance()
        }
        view = containerView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureContainerAppearance()
        configureTableView()
        configureCollectionView()
        configureLayout()
        configureSearchControls()
        configureDragAndDrop()
        configureContextMenu()
        configureStarEffects()
        bindViewModel()
        setActive(false)
    }

    deinit {
        thumbnailTasks.values.forEach { $0.cancel() }
        thumbnailTasks.removeAll()
    }

    func focusTable() {
        if currentDisplayMode == .media {
            view.window?.makeFirstResponder(mediaCollectionView)
        } else {
            view.window?.makeFirstResponder(tableView)
        }
    }

    func setActive(_ active: Bool) {
        let wasInactive = !isPaneActive
        isPaneActive = active
        updateActiveAppearance()

        if active && wasInactive && starEffectsEnabled {
            let palette = filerTheme.palette
            let glowLayer = CALayer()
            glowLayer.frame = headerView.bounds
            glowLayer.backgroundColor = palette.starGlowColor.withAlphaComponent(0.3).cgColor
            headerView.layer?.addSublayer(glowLayer)

            let fadeOut = CABasicAnimation(keyPath: "opacity")
            fadeOut.fromValue = 1.0
            fadeOut.toValue = 0.0
            fadeOut.duration = 0.25
            fadeOut.isRemovedOnCompletion = false
            fadeOut.fillMode = .forwards
            fadeOut.delegate = StarSparkleAnimator.makeRemovalDelegate(for: glowLayer)
            glowLayer.add(fadeOut, forKey: "activePulse")
        }
    }

    func updateBookmarksConfig(_ config: BookmarksConfig) {
        tableView.setBookmarkJumpConfig(config)
        tableView.onBookmarkJump = { [weak self] path in
            self?.hideBookmarkJumpHint()
            self?.onBookmarkJump?(path)
        }
        tableView.onBookmarkJumpPending = { [weak self] hint in
            self?.showBookmarkJumpHint(hint)
        }
        tableView.onBookmarkJumpEnded = { [weak self] in
            self?.hideBookmarkJumpHint()
        }
    }

    func reloadKeybindings() {
        keybindingManager = KeybindingManager()
        tableView.reloadKeybindings()
        mediaCollectionView.reloadKeybindings()
    }

    func setStarEffectsEnabled(_ enabled: Bool) {
        starEffectsEnabled = enabled
        tableView.reloadData()
        mediaCollectionView.reloadData()
        updateActiveAppearance()
    }

    func setAnimationEffectSettings(_ settings: AnimationEffectSettings) {
        animationEffectSettings = settings
    }

    func setSpotlightSearchScope(_ scope: SpotlightSearchScope) {
        viewModel.setSpotlightSearchScope(scope)
        guard isViewLoaded else {
            return
        }
        updateSearchMenuSelectionStates()

        let trimmed = searchField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if selectedSearchMode == .spotlight, !trimmed.isEmpty {
            applySearchFromHeader()
        }
    }

    private func showBookmarkJumpHint(_ hint: BookmarkJumpHint) {
        bookmarkJumpOverlayView.update(with: hint)
        bookmarkJumpOverlayView.isHidden = false

        if starEffectsEnabled {
            bookmarkJumpOverlayView.alphaValue = 0
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.12
                ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
                self.bookmarkJumpOverlayView.animator().alphaValue = 1
            }
            if let layer = bookmarkJumpOverlayView.layer {
                let scale = CABasicAnimation(keyPath: "transform.scale")
                scale.fromValue = 0.92
                scale.toValue = 1.0
                scale.duration = 0.12
                scale.timingFunction = CAMediaTimingFunction(name: .easeOut)
                layer.add(scale, forKey: "scaleIn")
            }
        }

        onStatusChanged?(hint.statusText, viewModel.directoryContents.displayedItems.count, viewModel.markedCount)
    }

    private func hideBookmarkJumpHint() {
        if starEffectsEnabled && !bookmarkJumpOverlayView.isHidden {
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.1
                self.bookmarkJumpOverlayView.animator().alphaValue = 0
            }, completionHandler: {
                self.bookmarkJumpOverlayView.isHidden = true
                self.bookmarkJumpOverlayView.alphaValue = 1
            })
        } else {
            bookmarkJumpOverlayView.isHidden = true
        }
    }

    func applyTheme(_ theme: FilerTheme, backgroundOpacity: CGFloat = 1.0) {
        filerTheme = theme
        self.backgroundOpacity = backgroundOpacity
        tableView.reloadData()
        mediaCollectionView.reloadData()
        updateActiveAppearance()
    }

    func setFileIconSize(_ size: CGFloat) {
        let clampedSize = min(max(size, 12), 40)
        guard abs(fileIconSize - clampedSize) > 0.001 else {
            return
        }

        fileIconSize = clampedSize
        iconCache.removeAllObjects()
        thumbnailCache.removeAllObjects()
        thumbnailTasks.values.forEach { $0.cancel() }
        thumbnailTasks.removeAll()
        tableView.rowHeight = max(24, clampedSize + 8)
        tableView.reloadData()
        mediaCollectionLayout.invalidateLayout()
        mediaCollectionView.reloadData()
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        viewModel.directoryContents.displayedItems.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard viewModel.directoryContents.displayedItems.indices.contains(row) else {
            return nil
        }

        let item = viewModel.directoryContents.displayedItems[row]

        switch tableColumn?.identifier {
        case Column.name:
            return makeNameCell(for: item, row: row)
        case Column.size:
            return makeTextCell(text: sizeText(for: item), alignment: .right)
        case Column.modified:
            return makeTextCell(text: modifiedText(for: item), alignment: .left)
        default:
            return nil
        }
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        let palette = filerTheme.palette
        let rowView = MarkedRowView()
        rowView.isMarkedRow = viewModel.paneState.markedIndices.contains(row)
        rowView.isVisualMode = vimModeState.mode == .visual
        rowView.markedColor = palette.markedColor
        rowView.visualMarkedColor = palette.visualMarkedColor
        return rowView
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        let selectedRow = tableView.selectedRow
        guard selectedRow >= 0 else {
            return
        }
        viewModel.setCursor(index: selectedRow)
    }

    func tableView(_ tableView: NSTableView, didClick tableColumn: NSTableColumn) {
        let targetSortColumn: DirectoryContents.SortDescriptor.Column
        switch tableColumn.identifier {
        case Column.name:
            targetSortColumn = .name
        case Column.size:
            targetSortColumn = .size
        case Column.modified:
            targetSortColumn = .date
        default:
            return
        }

        let currentSortDescriptor = viewModel.directoryContents.sortDescriptor
        let nextAscending: Bool
        if currentSortDescriptor.column == targetSortColumn {
            nextAscending = !currentSortDescriptor.ascending
        } else {
            nextAscending = true
        }

        if starEffectsEnabled {
            let transition = CATransition()
            transition.type = .fade
            transition.duration = 0.2
            transition.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            scrollView.layer?.add(transition, forKey: "sortTransition")
        }

        viewModel.setSortDescriptor(.init(column: targetSortColumn, ascending: nextAscending))
    }

    func numberOfSections(in collectionView: NSCollectionView) -> Int {
        1
    }

    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        viewModel.directoryContents.displayedItems.count
    }

    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        let item = collectionView.makeItem(withIdentifier: MediaCollectionItem.identifier, for: indexPath)
        guard
            let mediaItem = item as? MediaCollectionItem,
            viewModel.directoryContents.displayedItems.indices.contains(indexPath.item)
        else {
            return item
        }

        let fileItem = viewModel.directoryContents.displayedItems[indexPath.item]
        let isMarked = viewModel.paneState.markedIndices.contains(indexPath.item)
        mediaItem.configure(
            name: fileItem.name,
            thumbnail: icon(for: fileItem, row: indexPath.item),
            isMarked: isMarked,
            palette: filerTheme.palette
        )
        return mediaItem
    }

    func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
        guard let indexPath = indexPaths.first else {
            return
        }
        viewModel.setCursor(index: indexPath.item)
    }

    func collectionView(_ collectionView: NSCollectionView, layout collectionViewLayout: NSCollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> NSSize {
        let insets = mediaCollectionLayout.sectionInset
        let interitemSpacing = mediaCollectionLayout.minimumInteritemSpacing
        let availableWidth = max(120, collectionView.bounds.width - insets.left - insets.right)
        let minWidth: CGFloat = 160
        let columns = max(Int((availableWidth + interitemSpacing) / (minWidth + interitemSpacing)), 1)
        let totalSpacing = CGFloat(max(columns - 1, 0)) * interitemSpacing
        let width = floor((availableWidth - totalSpacing) / CGFloat(columns))
        return NSSize(width: width, height: width * 0.78 + 34)
    }

    func fileTableView(_ tableView: FileTableView, didTrigger action: KeyAction) -> Bool {
        handleKeyAction(action)
    }

    func mediaCollectionView(_ collectionView: MediaCollectionView, didTrigger action: KeyAction) -> Bool {
        handleKeyAction(action)
    }

    private func configureContainerAppearance() {
        view.wantsLayer = true

        headerView.translatesAutoresizingMaskIntoConstraints = false
        headerView.wantsLayer = true

        navigationStackView.translatesAutoresizingMaskIntoConstraints = false
        navigationStackView.orientation = .horizontal
        navigationStackView.alignment = .centerY
        navigationStackView.spacing = 4
        navigationStackView.distribution = .fill

        backPeekButton.translatesAutoresizingMaskIntoConstraints = false
        backPeekButton.isBordered = false
        backPeekButton.font = .systemFont(ofSize: 10)
        backPeekButton.contentTintColor = .secondaryLabelColor
        backPeekButton.target = self
        backPeekButton.action = #selector(handleBackPeekClick(_:))
        backPeekButton.isHidden = true
        backPeekButton.setContentHuggingPriority(.required, for: .horizontal)
        backPeekButton.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)

        forwardPeekButton.translatesAutoresizingMaskIntoConstraints = false
        forwardPeekButton.isBordered = false
        forwardPeekButton.font = .systemFont(ofSize: 10)
        forwardPeekButton.contentTintColor = .secondaryLabelColor
        forwardPeekButton.target = self
        forwardPeekButton.action = #selector(handleForwardPeekClick(_:))
        forwardPeekButton.isHidden = true
        forwardPeekButton.setContentHuggingPriority(.required, for: .horizontal)
        forwardPeekButton.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)

        pathControl.translatesAutoresizingMaskIntoConstraints = false
        pathControl.pathStyle = .standard
        pathControl.controlSize = .small
        pathControl.target = self
        pathControl.action = #selector(handlePathControlClick(_:))

        searchControlsStackView.translatesAutoresizingMaskIntoConstraints = false
        searchControlsStackView.orientation = .horizontal
        searchControlsStackView.alignment = .centerY
        searchControlsStackView.spacing = 6
        searchControlsStackView.setContentHuggingPriority(.required, for: .horizontal)
        searchControlsStackView.setContentCompressionResistancePriority(.required, for: .horizontal)

        displayModeControl.translatesAutoresizingMaskIntoConstraints = false
        displayModeControl.segmentStyle = .rounded
        displayModeControl.selectedSegment = 0
        displayModeControl.target = self
        displayModeControl.action = #selector(handleDisplayModeChanged(_:))
        displayModeControl.setContentHuggingPriority(.required, for: .horizontal)

        mediaRecursiveButton.translatesAutoresizingMaskIntoConstraints = false
        mediaRecursiveButton.target = self
        mediaRecursiveButton.action = #selector(handleMediaRecursiveToggle(_:))
        mediaRecursiveButton.isHidden = true
        mediaRecursiveButton.setContentHuggingPriority(.required, for: .horizontal)

        searchField.translatesAutoresizingMaskIntoConstraints = false
        searchField.controlSize = .small
        searchField.placeholderString = SearchMode.filter.placeholder
        searchField.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        searchField.delegate = self
        searchField.sendsSearchStringImmediately = true
        searchField.sendsWholeSearchString = true
        searchField.setContentHuggingPriority(.defaultLow, for: .horizontal)
        searchField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        configureSearchFieldMenuTemplate()

        bookmarkJumpOverlayView.isHidden = true
    }

    private func configureStarEffects() {
    }

    private func configureTableView() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.headerView = NSTableHeaderView()
        tableView.intercellSpacing = NSSize(width: 8, height: 0)
        tableView.keyActionDelegate = self
        tableView.setVimMode(vimModeState.mode)
        tableView.target = self
        tableView.doubleAction = #selector(handleDoubleClick(_:))
        tableView.backgroundColor = filerTheme.palette.tableBackgroundColor
        tableView.rowHeight = max(24, fileIconSize + 8)

        let nameColumn = NSTableColumn(identifier: Column.name)
        nameColumn.title = "Name"
        nameColumn.width = 440
        nameColumn.minWidth = 180

        let sizeColumn = NSTableColumn(identifier: Column.size)
        sizeColumn.title = "Size"
        sizeColumn.width = 120
        sizeColumn.minWidth = 80

        let modifiedColumn = NSTableColumn(identifier: Column.modified)
        modifiedColumn.title = "Modified"
        modifiedColumn.width = 180
        modifiedColumn.minWidth = 140

        tableView.addTableColumn(nameColumn)
        tableView.addTableColumn(sizeColumn)
        tableView.addTableColumn(modifiedColumn)
        updateColumnHeaderTitles()

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = true

        tableView.didBecomeFirstResponderHandler = { [weak self] in
            self?.onDidRequestActivate?()
        }
    }

    private func configureCollectionView() {
        mediaCollectionLayout.minimumInteritemSpacing = 10
        mediaCollectionLayout.minimumLineSpacing = 10
        mediaCollectionLayout.sectionInset = NSEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)

        mediaCollectionView.translatesAutoresizingMaskIntoConstraints = false
        mediaCollectionView.collectionViewLayout = mediaCollectionLayout
        mediaCollectionView.delegate = self
        mediaCollectionView.dataSource = self
        mediaCollectionView.isSelectable = true
        mediaCollectionView.allowsMultipleSelection = false
        mediaCollectionView.backgroundColors = [filerTheme.palette.tableBackgroundColor]
        mediaCollectionView.register(MediaCollectionItem.self, forItemWithIdentifier: MediaCollectionItem.identifier)
        mediaCollectionView.keyActionDelegate = self
        mediaCollectionView.setVimMode(vimModeState.mode)
        mediaCollectionView.didBecomeFirstResponderHandler = { [weak self] in
            self?.onDidRequestActivate?()
        }

        let doubleClickGesture = NSClickGestureRecognizer(target: self, action: #selector(handleMediaDoubleClick(_:)))
        doubleClickGesture.numberOfClicksRequired = 2
        mediaCollectionView.addGestureRecognizer(doubleClickGesture)
    }

    private func configureLayout() {
        view.addSubview(headerView)
        view.addSubview(scrollView)
        view.addSubview(bookmarkJumpOverlayView)

        navigationStackView.addArrangedSubview(backPeekButton)
        navigationStackView.addArrangedSubview(pathControl)
        navigationStackView.addArrangedSubview(forwardPeekButton)

        headerView.addSubview(navigationStackView)
        headerView.addSubview(searchControlsStackView)
        searchControlsStackView.addArrangedSubview(displayModeControl)
        searchControlsStackView.addArrangedSubview(mediaRecursiveButton)
        searchControlsStackView.addArrangedSubview(searchField)

        pathControl.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        NSLayoutConstraint.activate([
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            headerView.topAnchor.constraint(equalTo: view.topAnchor),
            headerView.heightAnchor.constraint(equalToConstant: 30),

            navigationStackView.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 10),
            navigationStackView.trailingAnchor.constraint(lessThanOrEqualTo: searchControlsStackView.leadingAnchor, constant: -10),
            navigationStackView.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),

            searchControlsStackView.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -10),
            searchControlsStackView.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            searchControlsStackView.leadingAnchor.constraint(greaterThanOrEqualTo: headerView.leadingAnchor, constant: 260),
            searchField.widthAnchor.constraint(greaterThanOrEqualToConstant: 132),
            searchField.widthAnchor.constraint(lessThanOrEqualToConstant: 240),

            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: headerView.bottomAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            bookmarkJumpOverlayView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            bookmarkJumpOverlayView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            bookmarkJumpOverlayView.widthAnchor.constraint(greaterThanOrEqualToConstant: 240),
            bookmarkJumpOverlayView.widthAnchor.constraint(lessThanOrEqualToConstant: 520)
        ])
    }

    private func configureSearchControls() {
        updateSearchModeUI()
        updateSearchMenuSelectionStates()
        updateDisplayModeControls()
    }

    private func applyDisplayMode(_ mode: PaneDisplayMode) {
        currentDisplayMode = mode
        updateDisplayModeControls()

        if mode == .media {
            scrollView.documentView = mediaCollectionView
            mediaCollectionView.reloadData()
        } else {
            scrollView.documentView = tableView
        }

        syncSelectionFromViewModel()
        focusTable()
    }

    private func updateDisplayModeControls() {
        displayModeControl.selectedSegment = currentDisplayMode == .media ? 1 : 0
        mediaRecursiveButton.state = viewModel.mediaRecursiveEnabled ? .on : .off
        mediaRecursiveButton.isHidden = currentDisplayMode != .media
    }

    private func configureContextMenu() {
        let menu = NSMenu()
        menu.delegate = self
        tableView.menu = menu
        mediaCollectionView.menu = menu
    }

    private func configureDragAndDrop() {
        tableView.registerForDraggedTypes([.fileURL])
        tableView.setDraggingSourceOperationMask([.copy, .move], forLocal: true)
        tableView.setDraggingSourceOperationMask([.copy], forLocal: false)
        tableView.dragSourceHandler = fileDragSource
        tableView.dragURLsProvider = { [weak self] in
            self?.viewModel.markedOrSelectedURLs() ?? []
        }
        tableView.dropTargetHandler = fileDropTarget

        mediaCollectionView.setDraggingSourceOperationMask([.copy, .move], forLocal: true)
        mediaCollectionView.setDraggingSourceOperationMask([.copy], forLocal: false)
        mediaCollectionView.dragSourceHandler = fileDragSource
        mediaCollectionView.dragURLsProvider = { [weak self] in
            self?.viewModel.markedOrSelectedURLs() ?? []
        }

        fileDropTarget.onHighlightChanged = { [weak self] highlighted in
            guard let self else {
                return
            }
            self.isDropTargetHighlighted = highlighted
            self.updateActiveAppearance()
            if highlighted {
                self.startDropPulse()
            } else {
                self.stopDropPulse()
            }
        }

        fileDropTarget.onDropCompleted = { [weak self] operation, itemCount in
            guard let self else { return }
            self.stopDropPulse()
            if self.starEffectsEnabled, let layer = self.view.layer {
                let center = CGPoint(x: layer.bounds.midX, y: layer.bounds.midY)
                StarSparkleAnimator.burst(count: 6, in: layer, at: center,
                    color: self.filerTheme.palette.starGlowColor, size: 8, duration: 0.4)
            }
            self.viewModel.refreshCurrentDirectory()
            self.onDropOperationCompleted?(operation, itemCount)
        }

        fileDropTarget.onDropFailed = { [weak self] message in
            self?.presentDropError(message)
        }
    }

    private func bindViewModel() {
        viewModel.onItemsChanged = { [weak self] _ in
            guard let self else {
                return
            }

            self.thumbnailTasks.values.forEach { $0.cancel() }
            self.thumbnailTasks.removeAll()
            self.thumbnailCache.removeAllObjects()

            self.tableView.reloadData()
            self.mediaCollectionView.reloadData()
            self.updateColumnHeaderTitles()
            self.syncSelectionFromViewModel()
            self.publishStatus()
            self.publishSelection()
        }

        viewModel.onCursorChanged = { [weak self] _ in
            guard let self else { return }
            self.syncSelectionFromViewModel()
            self.publishSelection()

            if self.starEffectsEnabled, self.currentDisplayMode == .browser {
                self.animateCursorRipple(at: self.viewModel.paneState.cursorIndex)
            }
        }

        viewModel.onMarkedIndicesChanged = { [weak self] _ in
            guard let self else {
                return
            }

            self.tableView.reloadData()
            self.mediaCollectionView.reloadData()
            self.syncSelectionFromViewModel()
            self.publishStatus()
        }

        viewModel.onDisplayModeChanged = { [weak self] mode in
            self?.applyDisplayMode(mode)
            self?.publishStatus()
            self?.publishSelection()
        }

        viewModel.onMediaRecursiveChanged = { [weak self] _ in
            self?.updateDisplayModeControls()
        }

        viewModel.onDirectoryLoadFailed = { [weak self] directory, error in
            self?.onDirectoryLoadFailed?(directory, error)
        }

        publishStatus()
        publishSelection()
        updateColumnHeaderTitles()
        applyDisplayMode(viewModel.displayMode)
    }

    private func syncSelectionFromViewModel() {
        let row = viewModel.paneState.cursorIndex
        let rowCount = viewModel.directoryContents.displayedItems.count

        guard rowCount > 0 else {
            tableView.deselectAll(nil)
            mediaCollectionView.deselectAll(nil)
            return
        }

        let clampedRow = min(max(row, 0), rowCount - 1)
        if currentDisplayMode == .media {
            let indexPath = IndexPath(item: clampedRow, section: 0)
            mediaCollectionView.selectionIndexPaths = [indexPath]
            mediaCollectionView.scrollToItems(at: [indexPath], scrollPosition: .centeredVertically)
        } else {
            tableView.selectRowIndexes(IndexSet(integer: clampedRow), byExtendingSelection: false)
            tableView.scrollRowToVisible(clampedRow)
        }
    }

    private func publishStatus() {
        let directoryURL = viewModel.paneState.currentDirectory.standardizedFileURL
        pathControl.url = directoryURL
        onStatusChanged?(directoryURL.path, viewModel.directoryContents.displayedItems.count, viewModel.markedCount)
        updateNavigationPeekLabels()
    }

    private func updateNavigationPeekLabels() {
        let history = viewModel.navigationHistory
        if let backURL = history.backStack.last {
            let name = backURL.lastPathComponent.isEmpty ? backURL.path : backURL.lastPathComponent
            backPeekButton.title = "\u{2190} \(name)"
            backPeekButton.isHidden = false
        } else {
            backPeekButton.isHidden = true
        }

        if let forwardURL = history.forwardStack.last {
            let name = forwardURL.lastPathComponent.isEmpty ? forwardURL.path : forwardURL.lastPathComponent
            forwardPeekButton.title = "\(name) \u{2192}"
            forwardPeekButton.isHidden = false
        } else {
            forwardPeekButton.isHidden = true
        }
    }

    @objc
    private func handleBackPeekClick(_ sender: Any?) {
        viewModel.goBack()
    }

    @objc
    private func handleForwardPeekClick(_ sender: Any?) {
        viewModel.goForward()
    }

    private func publishSelection() {
        onSelectionChanged?(viewModel.selectedItem)
    }

    private func updateActiveAppearance() {
        let palette = filerTheme.palette
        let headerColor: NSColor
        if isDropTargetHighlighted {
            headerColor = palette.dropTargetBorderColor
        } else {
            headerColor = isPaneActive ? palette.activeHeaderColor : palette.inactiveHeaderColor
        }

        view.layer?.backgroundColor = palette.paneBackgroundColor.applyingBackgroundOpacity(backgroundOpacity).cgColor
        headerView.layer?.backgroundColor = headerColor.cgColor
        pathControl.alphaValue = isPaneActive ? 1.0 : 0.82
        searchField.textColor = palette.primaryTextColor
        searchField.backgroundColor = palette.filterBarBackgroundColor.applyingBackgroundOpacity(backgroundOpacity)
        tableView.backgroundColor = palette.tableBackgroundColor.applyingBackgroundOpacity(backgroundOpacity)
        mediaCollectionView.backgroundColors = [palette.tableBackgroundColor.applyingBackgroundOpacity(backgroundOpacity)]
        scrollView.backgroundColor = palette.tableBackgroundColor.applyingBackgroundOpacity(backgroundOpacity)
        scrollView.alphaValue = isPaneActive ? palette.activePaneAlpha : palette.inactivePaneAlpha
        bookmarkJumpOverlayView.applyPalette(palette, backgroundOpacity: backgroundOpacity)
    }

    @objc
    private func handlePathControlClick(_ sender: NSPathControl) {
        guard let targetURL = sender.clickedPathItem?.url?.standardizedFileURL else {
            return
        }

        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: targetURL.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            return
        }

        viewModel.navigate(to: targetURL)
    }

    @objc
    private func handleDisplayModeChanged(_ sender: NSSegmentedControl) {
        let mode: PaneDisplayMode = sender.selectedSegment == 1 ? .media : .browser
        viewModel.setDisplayMode(mode)
    }

    @objc
    private func handleMediaRecursiveToggle(_ sender: NSButton) {
        viewModel.setMediaRecursiveEnabled(sender.state == .on)
    }

    @objc
    private func handleMediaDoubleClick(_ recognizer: NSClickGestureRecognizer) {
        let point = recognizer.location(in: mediaCollectionView)
        guard let indexPath = mediaCollectionView.indexPathForItem(at: point) else {
            return
        }

        viewModel.setCursor(index: indexPath.item)
        openSelectedFile()
    }

    private func makeNameCell(for item: FileItem, row: Int) -> NSTableCellView {
        let cell = tableView.makeView(withIdentifier: Cell.name, owner: self) as? FileNameCellView ?? createNameCellView()

        let isMarked = viewModel.paneState.markedIndices.contains(row)
        let palette = filerTheme.palette

        if starEffectsEnabled {
            cell.setMarkStar(visible: isMarked, color: palette.starAccentColor)
            cell.setName(item.name, textColor: palette.primaryTextColor)
        } else {
            cell.setMarkStar(visible: false, color: palette.starAccentColor)
            cell.setName(isMarked ? "* \(item.name)" : item.name, textColor: palette.primaryTextColor)
        }

        cell.setIcon(icon(for: item, row: row), size: fileIconSize)

        return cell
    }

    private func makeTextCell(text: String, alignment: NSTextAlignment) -> NSTableCellView {
        let cell = tableView.makeView(withIdentifier: Cell.text, owner: self) as? NSTableCellView ?? createTextCellView()
        cell.textField?.stringValue = text
        cell.textField?.alignment = alignment
        cell.textField?.textColor = filerTheme.palette.primaryTextColor
        return cell
    }

    private func createNameCellView() -> FileNameCellView {
        let cell = FileNameCellView()
        cell.identifier = Cell.name
        cell.setIcon(nil, size: fileIconSize)
        return cell
    }

    private func createTextCellView() -> NSTableCellView {
        let cell = NSTableCellView()
        cell.identifier = Cell.text

        let textField = NSTextField(labelWithString: "")
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.lineBreakMode = .byTruncatingTail

        cell.textField = textField
        cell.addSubview(textField)

        NSLayoutConstraint.activate([
            textField.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 4),
            textField.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -4),
            textField.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
        ])

        return cell
    }

    private func icon(for item: FileItem, row: Int) -> NSImage {
        if !item.isDirectory && item.url.isMediaFile {
            let thumbnailKey = thumbnailCacheKey(for: item)

            if let thumbnail = thumbnailCache.object(forKey: thumbnailKey) {
                return thumbnail
            }

            scheduleThumbnailLoadIfNeeded(for: item, row: row, key: thumbnailKey)
        }

        return fallbackIcon(for: item)
    }

    private func fallbackIcon(for item: FileItem) -> NSImage {
        let pixelSize = Int(fileIconSize.rounded())
        let cacheKey = "\(item.url.path)#\(pixelSize)" as NSString

        if let cached = iconCache.object(forKey: cacheKey) {
            return cached
        }

        let icon = NSWorkspace.shared.icon(forFile: item.url.path)
        icon.isTemplate = false
        icon.size = NSSize(width: CGFloat(pixelSize), height: CGFloat(pixelSize))
        iconCache.setObject(icon, forKey: cacheKey)
        return icon
    }

    private func thumbnailCacheKey(for item: FileItem) -> NSString {
        let pixelSize = Int(fileIconSize.rounded())
        return "thumb#\(item.url.path)#\(pixelSize)" as NSString
    }

    private func scheduleThumbnailLoadIfNeeded(for item: FileItem, row: Int, key: NSString) {
        guard thumbnailTasks[key] == nil else {
            return
        }

        let targetURL = item.url.standardizedFileURL
        let size = max(16, Int((fileIconSize * 2).rounded()))

        thumbnailTasks[key] = Task { [weak self] in
            guard let self else {
                return
            }

            let thumbnail = await Self.generateThumbnail(for: targetURL, maxPixelSize: size)
            guard !Task.isCancelled else {
                await MainActor.run {
                    self.thumbnailTasks.removeValue(forKey: key)
                }
                return
            }

            await MainActor.run {
                self.thumbnailTasks.removeValue(forKey: key)
                guard let thumbnail else {
                    return
                }

                self.thumbnailCache.setObject(thumbnail, forKey: key)

                guard self.viewModel.directoryContents.displayedItems.indices.contains(row) else {
                    return
                }

                if self.viewModel.directoryContents.displayedItems[row].url.standardizedFileURL != targetURL {
                    return
                }

                let rowIndexes = IndexSet(integer: row)
                let columnIndexes = IndexSet(integersIn: 0 ..< self.tableView.numberOfColumns)
                self.tableView.reloadData(forRowIndexes: rowIndexes, columnIndexes: columnIndexes)
                self.mediaCollectionView.reloadItems(at: [IndexPath(item: row, section: 0)])
            }
        }
    }

    private static func generateThumbnail(for url: URL, maxPixelSize: Int) async -> NSImage? {
        await Task.detached(priority: .utility) {
            if url.isImageFile {
                guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
                    return nil
                }

                let options: [CFString: Any] = [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceShouldCacheImmediately: false,
                    kCGImageSourceCreateThumbnailWithTransform: true,
                    kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
                ]

                guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
                    return nil
                }

                let size = NSSize(width: cgImage.width, height: cgImage.height)
                return NSImage(cgImage: cgImage, size: size)
            }

            if url.isVideoFile {
                let asset = AVURLAsset(url: url)
                let generator = AVAssetImageGenerator(asset: asset)
                generator.appliesPreferredTrackTransform = true
                generator.maximumSize = CGSize(width: maxPixelSize, height: maxPixelSize)

                let time = CMTime(seconds: 0.5, preferredTimescale: 600)
                guard let cgImage = try? generator.copyCGImage(at: time, actualTime: nil) else {
                    return nil
                }

                let size = NSSize(width: cgImage.width, height: cgImage.height)
                return NSImage(cgImage: cgImage, size: size)
            }

            return nil
        }.value
    }

    private func sizeText(for item: FileItem) -> String {
        guard !item.isDirectory || item.isPackage, let size = item.size else {
            return ""
        }
        return Self.byteFormatter.string(fromByteCount: size)
    }

    private func modifiedText(for item: FileItem) -> String {
        guard let date = item.dateModified else {
            return ""
        }
        return Self.dateFormatter.string(from: date)
    }

    private func handleTabPressed() -> Bool {
        onTabPressed?() ?? false
    }

    private var selectedSearchMode: SearchMode {
        currentSearchMode
    }

    private func focusSearch(mode: SearchMode) {
        if selectedSearchMode != mode {
            currentSearchMode = mode
            updateSearchModeUI()
        }

        vimModeState.enterFilterMode()
        tableView.setVimMode(vimModeState.mode)
        mediaCollectionView.setVimMode(vimModeState.mode)

        view.window?.makeFirstResponder(searchField)
        if let editor = searchField.currentEditor() {
            editor.selectAll(nil)
        }

        if starEffectsEnabled {
            let palette = filerTheme.palette
            searchField.wantsLayer = true
            searchField.layer?.shadowColor = palette.starAccentColor.cgColor
            searchField.layer?.shadowRadius = 6
            searchField.layer?.shadowOffset = .zero
            searchField.layer?.shadowOpacity = 0

            let glow = CAKeyframeAnimation(keyPath: "shadowOpacity")
            glow.values = [0.0, 0.6, 0.2]
            glow.keyTimes = [0, 0.5, 1.0]
            glow.duration = 0.3
            glow.isRemovedOnCompletion = false
            glow.fillMode = .forwards
            searchField.layer?.shadowOpacity = 0.2
            searchField.layer?.add(glow, forKey: "searchGlow")
        }
    }

    private func clearSearchAndReturnToTable() {
        searchField.stringValue = ""
        currentSearchMode = .filter
        updateSearchModeUI()
        viewModel.clearFilter()
        viewModel.exitSpotlightSearchMode()

        searchField.layer?.removeAnimation(forKey: "searchGlow")
        searchField.layer?.shadowOpacity = 0

        vimModeState.enterNormalMode()
        tableView.setVimMode(vimModeState.mode)
        mediaCollectionView.setVimMode(vimModeState.mode)
        focusTable()
    }

    private func updateSearchModeUI() {
        let mode = selectedSearchMode
        searchField.placeholderString = mode.placeholder
        updateSearchMenuSelectionStates()
    }

    private func updateSearchMenuSelectionStates() {
        for (mode, item) in searchMenuModeItems {
            item.state = selectedSearchMode == mode ? .on : .off
        }

        for (scope, item) in searchMenuScopeItems {
            item.state = viewModel.spotlightSearchScope == scope ? .on : .off
        }
    }

    private func applySearchFromHeader() {
        let query = searchField.stringValue

        switch selectedSearchMode {
        case .filter:
            viewModel.exitSpotlightSearchMode()
            viewModel.setFilterText(query)
        case .spotlight:
            viewModel.clearFilter()
            let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                viewModel.exitSpotlightSearchMode()
            } else {
                viewModel.enterSpotlightSearchMode()
                viewModel.updateSpotlightSearchQuery(trimmed)
            }
        }
    }

    @discardableResult
    private func handleKeyAction(_ action: KeyAction) -> Bool {
        let handled: Bool

        switch action {
        case .cursorUp:
            viewModel.moveCursorUp()
            handled = true
        case .cursorDown:
            viewModel.moveCursorDown()
            handled = true
        case .cursorLeft:
            addSlideTransition(direction: .fromLeft)
            viewModel.goToParent()
            handled = true
        case .cursorRight:
            addSlideTransition(direction: .fromRight)
            viewModel.enterSelected()
            handled = true
        case .pageUp:
            viewModel.moveCursorPageUp()
            handled = true
        case .pageDown:
            viewModel.moveCursorPageDown()
            handled = true
        case .goToTop:
            viewModel.moveCursorToTop()
            handled = true
        case .goToBottom:
            viewModel.moveCursorToBottom()
            handled = true
        case .goBack:
            viewModel.goBack()
            handled = true
        case .goForward:
            viewModel.goForward()
            handled = true
        case .goToParent:
            viewModel.goToParent()
            handled = true
        case .goHome:
            viewModel.navigate(to: UserPaths.homeDirectoryURL)
            handled = true
        case .goDesktop:
            navigateToUserSubdirectory("Desktop")
            handled = true
        case .goDocuments:
            navigateToUserSubdirectory("Documents")
            handled = true
        case .goDownloads:
            navigateToUserSubdirectory("Downloads")
            handled = true
        case .goApplications:
            viewModel.navigate(to: URL(fileURLWithPath: "/Applications", isDirectory: true))
            handled = true
        case .enterDirectory:
            openSelectedFile()
            handled = true
        case .switchPane:
            handled = handleTabPressed()
        case .toggleMark:
            performToggleMarkAction()
            handled = true
        case .markAll:
            viewModel.markAll()
            if starEffectsEnabled {
                animateMarkCascade(topToBottom: true)
            }
            handled = true
        case .clearMarks:
            if starEffectsEnabled {
                animateMarkCascade(topToBottom: false)
            }
            viewModel.clearMarks()
            handled = true
        case .enterVisualMode:
            if vimModeState.mode != .visual {
                vimModeState.enterVisualMode(anchorIndex: viewModel.paneState.cursorIndex)
                tableView.setVimMode(vimModeState.mode)
                mediaCollectionView.setVimMode(vimModeState.mode)
                viewModel.enterVisualMode()

                if starEffectsEnabled {
                    flashRow(at: viewModel.paneState.cursorIndex,
                        color: filerTheme.palette.starAccentColor.withAlphaComponent(0.4), duration: 0.3)
                }
            }
            handled = true
        case .exitVisualMode:
            vimModeState.exitVisualMode()
            tableView.setVimMode(vimModeState.mode)
            mediaCollectionView.setVimMode(vimModeState.mode)
            viewModel.exitVisualMode()
            handled = true
        case .openFile:
            openSelectedFile()
            handled = true
        case .openFileInFinder:
            revealSelectedInFinder()
            handled = true
        case .copySelectedItemPath:
            copySelectedItemPathToPasteboard()
            handled = true
        case .toggleMediaMode:
            viewModel.toggleDisplayMode()
            handled = true
        case .toggleMediaRecursive:
            viewModel.toggleMediaRecursive()
            handled = true
        case .copy, .paste, .move, .delete, .rename, .createDirectory, .undo, .togglePreview, .toggleSidebar, .toggleLeftPane, .toggleRightPane, .toggleSinglePane, .equalizePaneWidths, .openBookmarkSearch, .openHistory, .addBookmark, .batchRename, .syncPanes:
            handled = onFileOperationRequested?(action) ?? false
        case .enterFilterMode:
            focusSearch(mode: .filter)
            handled = true
        case .enterSpotlightSearch:
            focusSearch(mode: .spotlight)
            handled = true
        case .clearFilter:
            clearSearchAndReturnToTable()
            handled = true
        case .toggleHiddenFiles:
            viewModel.toggleHiddenFiles()
            handled = true
        case .sortByName:
            viewModel.sortByName()
            handled = true
        case .sortBySize:
            viewModel.sortBySize()
            handled = true
        case .sortByDate:
            viewModel.sortByDate()
            handled = true
        case .sortBySelectionOrder:
            viewModel.sortBySelectionOrder()
            handled = true
        case .reverseSortOrder:
            viewModel.reverseSortOrder()
            handled = true
        case .refresh:
            viewModel.refresh()
            handled = true
        case .quit:
            NSApp.terminate(nil)
            handled = true
        }

        return handled
    }

    private func performToggleMarkAction() {
        let itemCount = viewModel.directoryContents.displayedItems.count
        let cursorIndexBeforeToggle = viewModel.paneState.cursorIndex
        let wasMarked = viewModel.paneState.markedIndices.contains(cursorIndexBeforeToggle)

        viewModel.toggleMark()

        if starEffectsEnabled, !wasMarked,
           let rowView = tableView.rowView(atRow: cursorIndexBeforeToggle, makeIfNecessary: false),
           let viewLayer = view.layer {
            let palette = filerTheme.palette
            let starLocalCenter = CGPoint(x: 4 + fileIconSize + 3 + 6, y: rowView.bounds.midY)
            let starCenter = rowView.convert(starLocalCenter, to: view)
            StarSparkleAnimator.burst(count: 4, in: viewLayer, at: starCenter,
                color: palette.starGlowColor, size: 4, duration: 0.25)
        }

        guard shouldAdvanceCursorAfterSpaceMark(
            itemCount: itemCount,
            cursorIndexBeforeToggle: cursorIndexBeforeToggle
        ) else {
            return
        }

        viewModel.setCursor(index: cursorIndexBeforeToggle + 1)
    }

    private func shouldAdvanceCursorAfterSpaceMark(itemCount: Int, cursorIndexBeforeToggle: Int) -> Bool {
        guard itemCount > 0, cursorIndexBeforeToggle + 1 < itemCount else {
            return false
        }

        guard let keyEvent = NSApp.currentEvent?.keyEvent else {
            return false
        }

        return keyEvent.key == "Space" && keyEvent.modifiers.isEmpty
    }

    @objc
    private func handleDoubleClick(_ sender: Any?) {
        guard tableView.clickedRow >= 0 else {
            return
        }
        openSelectedFile()
    }

    private func openSelectedFile() {
        guard let item = viewModel.selectedItem else {
            return
        }

        if item.isDirectory && !item.isPackage {
            viewModel.enterSelected()
        } else {
            NSWorkspace.shared.open(item.url)
        }
    }

    private func revealSelectedInFinder() {
        guard let item = viewModel.selectedItem else {
            return
        }
        NSWorkspace.shared.activateFileViewerSelecting([item.url])
    }

    private func navigateToUserSubdirectory(_ name: String) {
        let url = URL(fileURLWithPath: UserPaths.homeDirectoryPath + "/\(name)", isDirectory: true)
        viewModel.navigate(to: url)
    }

    private func copySelectedItemPathToPasteboard() {
        guard let item = viewModel.selectedItem else {
            NSSound.beep()
            return
        }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(item.url.standardizedFileURL.path, forType: .string)
    }

    private func presentDropError(_ message: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Drop Failed"
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    func controlTextDidBeginEditing(_ obj: Notification) {
        guard (obj.object as? NSControl) === searchField else {
            return
        }

        vimModeState.enterFilterMode()
        tableView.setVimMode(vimModeState.mode)
        mediaCollectionView.setVimMode(vimModeState.mode)
    }

    func controlTextDidChange(_ obj: Notification) {
        guard (obj.object as? NSControl) === searchField else {
            return
        }

        applySearchFromHeader()
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        guard control === searchField else {
            return false
        }

        if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
            clearSearchAndReturnToTable()
            return true
        }

        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            if selectedSearchMode == .spotlight {
                viewModel.enterSelected()
                viewModel.exitSpotlightSearchMode()
                searchField.stringValue = ""
                currentSearchMode = .filter
                updateSearchModeUI()
            }

            vimModeState.enterNormalMode()
            tableView.setVimMode(vimModeState.mode)
            mediaCollectionView.setVimMode(vimModeState.mode)
            focusTable()
            return true
        }

        return false
    }

    private func configureSearchFieldMenuTemplate() {
        let menu = NSMenu(title: "Search Options")
        searchMenuModeItems.removeAll(keepingCapacity: true)
        searchMenuScopeItems.removeAll(keepingCapacity: true)

        let modeHeader = NSMenuItem(title: "Search Mode", action: nil, keyEquivalent: "")
        modeHeader.isEnabled = false
        menu.addItem(modeHeader)

        for mode in [SearchMode.filter, .spotlight] {
            let item = NSMenuItem(title: mode.menuTitle, action: #selector(handleSearchModeMenuSelection(_:)), keyEquivalent: "")
            item.target = self
            item.tag = mode.rawValue
            menu.addItem(item)
            searchMenuModeItems[mode] = item
        }

        menu.addItem(NSMenuItem.separator())

        let scopeHeader = NSMenuItem(title: "Spotlight Scope", action: nil, keyEquivalent: "")
        scopeHeader.isEnabled = false
        menu.addItem(scopeHeader)

        for scope in SpotlightSearchScope.allCases {
            let item = NSMenuItem(title: scope.displayName, action: #selector(handleSpotlightScopeMenuSelection(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = scope.rawValue
            menu.addItem(item)
            searchMenuScopeItems[scope] = item
        }

        searchField.searchMenuTemplate = menu
        updateSearchMenuSelectionStates()
    }

    @objc
    private func handleSearchModeMenuSelection(_ sender: NSMenuItem) {
        guard let mode = SearchMode(rawValue: sender.tag), selectedSearchMode != mode else {
            return
        }

        currentSearchMode = mode
        updateSearchModeUI()
        applySearchFromHeader()
    }

    @objc
    private func handleSpotlightScopeMenuSelection(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
              let scope = SpotlightSearchScope(rawValue: rawValue) else {
            return
        }

        viewModel.setSpotlightSearchScope(scope)
        onSpotlightSearchScopeChanged?(scope)
        updateSearchMenuSelectionStates()
        applySearchFromHeader()
    }

    // MARK: - Context Menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let clickedRow: Int
        if currentDisplayMode == .media {
            if let selectedIndex = mediaCollectionView.selectionIndexPaths.first?.item {
                clickedRow = selectedIndex
            } else {
                clickedRow = -1
            }
        } else {
            clickedRow = tableView.clickedRow
        }
        let hasClickedItem = viewModel.directoryContents.displayedItems.indices.contains(clickedRow)
        let clickedItem = hasClickedItem ? viewModel.directoryContents.displayedItems[clickedRow] : nil
        let contextItem = clickedItem ?? viewModel.selectedItem
        let hasContextItem = contextItem != nil

        let openTitle: String
        if let contextItem, contextItem.isDirectory && !contextItem.isPackage {
            openTitle = "Open"
        } else {
            openTitle = "Open with Default App"
        }

        menu.addItem(makeContextMenuItem(
            title: openTitle,
            action: .openFile,
            shortcutActions: [.enterDirectory, .openFile],
            requiresContextItem: true,
            enabled: hasContextItem
        ))
        menu.addItem(makeContextMenuItem(
            title: "Show in Finder",
            action: .openFileInFinder,
            requiresContextItem: true,
            enabled: hasContextItem
        ))

        menu.addItem(NSMenuItem.separator())

        menu.addItem(makeContextMenuItem(
            title: "Toggle Mark",
            action: .toggleMark,
            requiresContextItem: true,
            enabled: hasContextItem
        ))
        menu.addItem(makeContextMenuItem(
            title: "Mark All",
            action: .markAll,
            enabled: !viewModel.directoryContents.displayedItems.isEmpty
        ))
        menu.addItem(makeContextMenuItem(
            title: "Clear Marks",
            action: .clearMarks,
            enabled: viewModel.markedCount > 0
        ))

        if vimModeState.mode == .visual {
            menu.addItem(makeContextMenuItem(title: "End Visual Selection", action: .exitVisualMode))
        } else {
            menu.addItem(makeContextMenuItem(
                title: "Start Visual Selection",
                action: .enterVisualMode,
                requiresContextItem: true,
                enabled: hasContextItem
            ))
        }

        menu.addItem(NSMenuItem.separator())

        menu.addItem(makeContextMenuItem(
            title: "Copy",
            action: .copy,
            requiresContextItem: true,
            enabled: hasContextItem
        ))
        menu.addItem(makeContextMenuItem(
            title: "Copy File/Folder Path",
            action: .copySelectedItemPath,
            requiresContextItem: true,
            enabled: hasContextItem
        ))
        menu.addItem(makeContextMenuItem(
            title: "Cut",
            action: .move,
            requiresContextItem: true,
            enabled: hasContextItem
        ))
        menu.addItem(makeContextMenuItem(title: "Paste", action: .paste))

        menu.addItem(NSMenuItem.separator())

        menu.addItem(makeContextMenuItem(
            title: "Rename...",
            action: .rename,
            requiresContextItem: true,
            enabled: hasContextItem
        ))
        menu.addItem(makeContextMenuItem(
            title: "Move to Trash",
            action: .delete,
            requiresContextItem: true,
            enabled: hasContextItem
        ))
        menu.addItem(makeContextMenuItem(title: "New Folder", action: .createDirectory))
        menu.addItem(makeContextMenuItem(
            title: "Batch Rename...",
            action: .batchRename,
            requiresContextItem: true,
            enabled: hasContextItem
        ))
        menu.addItem(makeContextMenuItem(title: "Sync Panes...", action: .syncPanes))

        menu.addItem(NSMenuItem.separator())

        menu.addItem(makeContextMenuItem(title: "Filter...", action: .enterFilterMode))
        menu.addItem(makeContextMenuItem(title: "Spotlight Search...", action: .enterSpotlightSearch))
        menu.addItem(makeContextMenuItem(title: "Clear Filter", action: .clearFilter))
        menu.addItem(makeContextMenuItem(title: "Bookmark Search...", action: .openBookmarkSearch))
        menu.addItem(makeContextMenuItem(title: "History...", action: .openHistory))
        menu.addItem(makeContextMenuItem(title: "Add Bookmark...", action: .addBookmark))

        menu.addItem(NSMenuItem.separator())

        menu.addItem(makeContextMenuItem(title: "Back", action: .goBack))
        menu.addItem(makeContextMenuItem(title: "Forward", action: .goForward))
        menu.addItem(makeContextMenuItem(title: "Enclosing Folder", action: .goToParent))
        menu.addItem(makeContextMenuItem(title: "Home", action: .goHome))
        menu.addItem(makeContextMenuItem(title: "Desktop", action: .goDesktop))
        menu.addItem(makeContextMenuItem(title: "Documents", action: .goDocuments))
        menu.addItem(makeContextMenuItem(title: "Downloads", action: .goDownloads))
        menu.addItem(makeContextMenuItem(title: "Applications", action: .goApplications))
        menu.addItem(makeContextMenuItem(title: "Refresh", action: .refresh))
        menu.addItem(makeContextMenuItem(title: "Toggle Hidden Files", action: .toggleHiddenFiles))
        menu.addItem(makeSortMenuItem())
        menu.addItem(makeContextMenuItem(title: "Toggle Media Mode", action: .toggleMediaMode))
        menu.addItem(makeContextMenuItem(title: "Toggle Media Recursive", action: .toggleMediaRecursive))

        menu.addItem(NSMenuItem.separator())

        menu.addItem(makeContextMenuItem(title: "Toggle Sidebar", action: .toggleSidebar))
        menu.addItem(makeContextMenuItem(title: "Toggle Preview", action: .togglePreview))
        menu.addItem(makeContextMenuItem(title: "Toggle Left Pane", action: .toggleLeftPane))
        menu.addItem(makeContextMenuItem(title: "Toggle Right Pane", action: .toggleRightPane))
        menu.addItem(makeContextMenuItem(title: "Equalize Pane Widths", action: .equalizePaneWidths))
        menu.addItem(makeContextMenuItem(title: "Switch Pane", action: .switchPane))
    }

    private func makeSortMenuItem() -> NSMenuItem {
        let item = NSMenuItem(title: "Sort", action: nil, keyEquivalent: "")
        let submenu = NSMenu(title: "Sort")

        submenu.addItem(makeContextMenuItem(title: "By Name", action: .sortByName))
        submenu.addItem(makeContextMenuItem(title: "By Size", action: .sortBySize))
        submenu.addItem(makeContextMenuItem(title: "By Date", action: .sortByDate))
        submenu.addItem(makeContextMenuItem(title: "By Selection Order", action: .sortBySelectionOrder))
        submenu.addItem(makeContextMenuItem(title: "Reverse Sort Order", action: .reverseSortOrder))

        item.submenu = submenu
        return item
    }

    private func updateColumnHeaderTitles() {
        let currentSort = viewModel.directoryContents.sortDescriptor

        for column in tableView.tableColumns {
            let baseTitle: String
            let mappedSortColumn: DirectoryContents.SortDescriptor.Column?

            switch column.identifier {
            case Column.name:
                baseTitle = "Name"
                mappedSortColumn = .name
            case Column.size:
                baseTitle = "Size"
                mappedSortColumn = .size
            case Column.modified:
                baseTitle = "Modified"
                mappedSortColumn = .date
            default:
                continue
            }

            if let mappedSortColumn, mappedSortColumn == currentSort.column {
                column.title = "\(baseTitle) \(currentSort.ascending ? "↑" : "↓")"
            } else {
                column.title = baseTitle
            }
        }
    }

    private func makeContextMenuItem(
        title: String,
        action keyAction: KeyAction,
        shortcutActions: [KeyAction]? = nil,
        requiresContextItem: Bool = false,
        enabled: Bool = true
    ) -> NSMenuItem {
        let actionsForShortcut = shortcutActions ?? [keyAction]
        let item = NSMenuItem(
            title: contextMenuTitle(title, actions: actionsForShortcut),
            action: #selector(contextMenuPerformAction(_:)),
            keyEquivalent: ""
        )
        item.target = self
        item.representedObject = keyAction
        item.tag = requiresContextItem ? 1 : 0
        item.isEnabled = enabled
        return item
    }

    private func contextMenuTitle(_ title: String, actions: [KeyAction]) -> String {
        var seen = Set<String>()
        var shortcuts: [String] = []

        for action in actions {
            for shortcut in preferredShortcuts(for: action) where !seen.contains(shortcut) {
                seen.insert(shortcut)
                shortcuts.append(shortcut)
            }
        }

        guard !shortcuts.isEmpty else {
            return title
        }

        return "\(title) (\(shortcuts.joined(separator: " / ")))"
    }

    private func preferredShortcuts(for action: KeyAction) -> [String] {
        let normal = keybindingManager.shortcuts(for: action, mode: .normal)
        if !normal.isEmpty {
            return normal
        }

        let visual = keybindingManager.shortcuts(for: action, mode: .visual)
        if !visual.isEmpty {
            return visual
        }

        return keybindingManager.shortcuts(for: action, mode: .filter)
    }

    @objc
    private func contextMenuPerformAction(_ sender: NSMenuItem) {
        guard let action = sender.representedObject as? KeyAction else {
            return
        }

        let requiresContextItem = sender.tag == 1
        guard resolveContextSelectionIfNeeded(requiresContextItem: requiresContextItem) else {
            return
        }

        _ = handleKeyAction(action)
    }

    private func resolveContextSelectionIfNeeded(requiresContextItem: Bool) -> Bool {
        guard requiresContextItem else {
            return true
        }

        let clickedRow: Int
        if currentDisplayMode == .media {
            if let selectedIndex = mediaCollectionView.selectionIndexPaths.first?.item {
                clickedRow = selectedIndex
            } else {
                clickedRow = -1
            }
        } else {
            clickedRow = tableView.clickedRow
        }
        if viewModel.directoryContents.displayedItems.indices.contains(clickedRow) {
            viewModel.setCursor(index: clickedRow)
            return true
        }

        return viewModel.selectedItem != nil
    }

    // MARK: - Animation Helpers

    private func addSlideTransition(direction: CATransitionSubtype) {
        guard starEffectsEnabled else { return }
        let transition = CATransition()
        transition.type = .push
        transition.subtype = direction
        transition.duration = 0.18
        transition.timingFunction = CAMediaTimingFunction(name: .easeOut)
        scrollView.layer?.add(transition, forKey: "directoryTransition")
    }

    private func flashRow(at row: Int, color: NSColor, duration: CFTimeInterval) {
        guard let rowView = tableView.rowView(atRow: row, makeIfNecessary: false) else { return }
        rowView.wantsLayer = true
        let flash = CALayer()
        flash.frame = rowView.bounds
        flash.backgroundColor = color.cgColor
        flash.cornerRadius = 2
        rowView.layer?.addSublayer(flash)

        let fadeOut = CABasicAnimation(keyPath: "opacity")
        fadeOut.fromValue = 1.0
        fadeOut.toValue = 0.0
        fadeOut.duration = duration
        fadeOut.isRemovedOnCompletion = false
        fadeOut.fillMode = .forwards
        fadeOut.delegate = StarSparkleAnimator.makeRemovalDelegate(for: flash)
        flash.add(fadeOut, forKey: "rowFlash")
    }

    private func animateCursorRipple(at row: Int) {
        lastCursorRippleLayer?.removeFromSuperlayer()
        lastCursorRippleLayer = nil

        guard let rowView = tableView.rowView(atRow: row, makeIfNecessary: false) else { return }
        rowView.wantsLayer = true

        let palette = filerTheme.palette
        let alpha: CGFloat = vimModeState.mode == .visual ? 0.3 : 0.15
        let duration: CFTimeInterval = vimModeState.mode == .visual ? 0.25 : 0.2

        let ripple = CALayer()
        ripple.frame = rowView.bounds
        ripple.backgroundColor = palette.starAccentColor.withAlphaComponent(alpha).cgColor
        ripple.cornerRadius = 2
        rowView.layer?.addSublayer(ripple)
        lastCursorRippleLayer = ripple

        let fadeOut = CABasicAnimation(keyPath: "opacity")
        fadeOut.fromValue = 1.0
        fadeOut.toValue = 0.0
        fadeOut.duration = duration
        fadeOut.isRemovedOnCompletion = false
        fadeOut.fillMode = .forwards
        fadeOut.delegate = StarSparkleAnimator.makeRemovalDelegate(for: ripple)
        ripple.add(fadeOut, forKey: "cursorRipple")
    }

    private func animateMarkCascade(topToBottom: Bool) {
        let visibleRange = tableView.rows(in: tableView.visibleRect)
        guard visibleRange.length > 0 else { return }

        let rows = Array(visibleRange.location ..< NSMaxRange(visibleRange))
        let orderedRows = topToBottom ? rows : rows.reversed()
        let palette = filerTheme.palette

        for (i, row) in orderedRows.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.02) { [weak self] in
                guard let self else { return }
                self.flashRow(at: row, color: palette.starGlowColor.withAlphaComponent(0.25), duration: 0.3)
            }
        }
    }

    private func startDropPulse() {
        guard starEffectsEnabled else { return }
        let pulse = CABasicAnimation(keyPath: "borderWidth")
        pulse.fromValue = 1.0
        pulse.toValue = 2.5
        pulse.duration = 0.8
        pulse.autoreverses = true
        pulse.repeatCount = .infinity
        view.layer?.add(pulse, forKey: "dropPulse")
    }

    private func stopDropPulse() {
        view.layer?.removeAnimation(forKey: "dropPulse")
    }
}
