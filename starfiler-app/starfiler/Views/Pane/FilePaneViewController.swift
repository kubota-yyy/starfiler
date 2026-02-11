import AppKit
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

    private func configureView() {
        identifier = NSUserInterfaceItemIdentifier("nameCell")

        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.imageScaling = .scaleProportionallyUpOrDown

        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.lineBreakMode = .byTruncatingMiddle

        textField = nameLabel
        imageView = iconView

        addSubview(iconView)
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

            nameLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 8),
            nameLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            nameLabel.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }
}

final class FilePaneViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate, NSMenuDelegate, KeyActionDelegate, NSTextFieldDelegate, NSSearchFieldDelegate {
    private enum SearchMode: Int {
        case filter = 0
        case spotlight = 1

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
    private let pathControl = NSPathControl()
    private let searchControlsStackView = NSStackView()
    private let searchModeControl = NSSegmentedControl(labels: ["Filter", "Spotlight"], trackingMode: .selectOne, target: nil, action: nil)
    private let searchField = NSSearchField()
    private let spotlightScopePopUpButton = NSPopUpButton()
    private let scrollView = NSScrollView()
    private let tableView = FileTableView()
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
    private var isUpdatingSearchControls = false

    var onStatusChanged: ((String, Int, Int) -> Void)?
    var onSelectionChanged: ((FileItem?) -> Void)?
    var onTabPressed: (() -> Bool)?
    var onDidRequestActivate: (() -> Void)?
    var onFileOperationRequested: ((KeyAction) -> Bool)?
    var onBookmarkJump: ((String) -> Void)?
    var onDropOperationCompleted: ((NSDragOperation, Int) -> Void)?
    var onSpotlightSearchScopeChanged: ((SpotlightSearchScope) -> Void)?

    init(viewModel: FilePaneViewModel) {
        self.viewModel = viewModel
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
        configureLayout()
        configureSearchControls()
        configureDragAndDrop()
        configureContextMenu()
        bindViewModel()
        setActive(false)
    }

    deinit {
        thumbnailTasks.values.forEach { $0.cancel() }
        thumbnailTasks.removeAll()
    }

    func focusTable() {
        view.window?.makeFirstResponder(tableView)
    }

    func setActive(_ active: Bool) {
        isPaneActive = active
        updateActiveAppearance()
    }

    func updateBookmarksConfig(_ config: BookmarksConfig) {
        tableView.setBookmarkJumpConfig(config)
        tableView.onBookmarkJump = { [weak self] path in
            self?.onBookmarkJump?(path)
        }
        tableView.onBookmarkJumpPending = { [weak self] hint in
            self?.showBookmarkJumpHint(hint)
        }
    }

    func reloadKeybindings() {
        keybindingManager = KeybindingManager()
        tableView.reloadKeybindings()
    }

    func setSpotlightSearchScope(_ scope: SpotlightSearchScope) {
        viewModel.setSpotlightSearchScope(scope)
        guard isViewLoaded else {
            return
        }
        selectSpotlightScope(scope)

        let trimmed = searchField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if selectedSearchMode == .spotlight, !trimmed.isEmpty {
            applySearchFromHeader()
        }
    }

    private func showBookmarkJumpHint(_ hint: BookmarkJumpHint) {
        onStatusChanged?(hint.statusText, viewModel.directoryContents.displayedItems.count, viewModel.markedCount)
    }

    func applyTheme(_ theme: FilerTheme, backgroundOpacity: CGFloat = 1.0) {
        filerTheme = theme
        self.backgroundOpacity = backgroundOpacity
        tableView.reloadData()
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

        viewModel.setSortDescriptor(.init(column: targetSortColumn, ascending: nextAscending))
    }

    func fileTableView(_ tableView: FileTableView, didTrigger action: KeyAction) -> Bool {
        handleKeyAction(action)
    }

    private func configureContainerAppearance() {
        view.wantsLayer = true
        view.layer?.cornerRadius = 6
        view.layer?.borderWidth = 2
        view.layer?.masksToBounds = true

        headerView.translatesAutoresizingMaskIntoConstraints = false
        headerView.wantsLayer = true

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

        searchModeControl.translatesAutoresizingMaskIntoConstraints = false
        searchModeControl.segmentStyle = .rounded
        searchModeControl.selectedSegment = SearchMode.filter.rawValue
        searchModeControl.target = self
        searchModeControl.action = #selector(searchModeChanged(_:))
        searchModeControl.setWidth(74, forSegment: 0)
        searchModeControl.setWidth(94, forSegment: 1)

        searchField.translatesAutoresizingMaskIntoConstraints = false
        searchField.placeholderString = SearchMode.filter.placeholder
        searchField.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        searchField.delegate = self
        searchField.sendsSearchStringImmediately = true
        searchField.sendsWholeSearchString = true
        searchField.setContentHuggingPriority(.defaultLow, for: .horizontal)
        searchField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        spotlightScopePopUpButton.translatesAutoresizingMaskIntoConstraints = false
        spotlightScopePopUpButton.target = self
        spotlightScopePopUpButton.action = #selector(spotlightScopeChanged(_:))
        spotlightScopePopUpButton.addItems(withTitles: SpotlightSearchScope.allCases.map(\.displayName))
        spotlightScopePopUpButton.setContentHuggingPriority(.required, for: .horizontal)
        spotlightScopePopUpButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        spotlightScopePopUpButton.isHidden = true
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

    private func configureLayout() {
        view.addSubview(headerView)
        view.addSubview(scrollView)

        headerView.addSubview(pathControl)
        headerView.addSubview(searchControlsStackView)
        searchControlsStackView.addArrangedSubview(searchModeControl)
        searchControlsStackView.addArrangedSubview(searchField)
        searchControlsStackView.addArrangedSubview(spotlightScopePopUpButton)

        NSLayoutConstraint.activate([
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            headerView.topAnchor.constraint(equalTo: view.topAnchor),
            headerView.heightAnchor.constraint(equalToConstant: 34),

            pathControl.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 10),
            pathControl.trailingAnchor.constraint(lessThanOrEqualTo: searchControlsStackView.leadingAnchor, constant: -10),
            pathControl.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),

            searchControlsStackView.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -10),
            searchControlsStackView.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            searchControlsStackView.leadingAnchor.constraint(greaterThanOrEqualTo: headerView.leadingAnchor, constant: 260),
            searchField.widthAnchor.constraint(greaterThanOrEqualToConstant: 160),
            searchField.widthAnchor.constraint(lessThanOrEqualToConstant: 340),

            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: headerView.bottomAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func configureSearchControls() {
        selectSpotlightScope(viewModel.spotlightSearchScope)
        updateSearchModeUI()
    }

    private func configureContextMenu() {
        let menu = NSMenu()
        menu.delegate = self
        tableView.menu = menu
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

        fileDropTarget.onHighlightChanged = { [weak self] highlighted in
            guard let self else {
                return
            }
            self.isDropTargetHighlighted = highlighted
            self.updateActiveAppearance()
        }

        fileDropTarget.onDropCompleted = { [weak self] operation, itemCount in
            self?.viewModel.refreshCurrentDirectory()
            self?.onDropOperationCompleted?(operation, itemCount)
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
            self.updateColumnHeaderTitles()
            self.syncSelectionFromViewModel()
            self.publishStatus()
            self.publishSelection()
        }

        viewModel.onCursorChanged = { [weak self] _ in
            self?.syncSelectionFromViewModel()
            self?.publishSelection()
        }

        viewModel.onMarkedIndicesChanged = { [weak self] _ in
            guard let self else {
                return
            }

            self.tableView.reloadData()
            self.syncSelectionFromViewModel()
            self.publishStatus()
        }

        publishStatus()
        publishSelection()
        updateColumnHeaderTitles()
    }

    private func syncSelectionFromViewModel() {
        let row = viewModel.paneState.cursorIndex
        let rowCount = viewModel.directoryContents.displayedItems.count

        guard rowCount > 0 else {
            tableView.deselectAll(nil)
            return
        }

        let clampedRow = min(max(row, 0), rowCount - 1)
        tableView.selectRowIndexes(IndexSet(integer: clampedRow), byExtendingSelection: false)
        tableView.scrollRowToVisible(clampedRow)
    }

    private func publishStatus() {
        let directoryURL = viewModel.paneState.currentDirectory.standardizedFileURL
        pathControl.url = directoryURL
        onStatusChanged?(directoryURL.path, viewModel.directoryContents.displayedItems.count, viewModel.markedCount)
    }

    private func publishSelection() {
        onSelectionChanged?(viewModel.selectedItem)
    }

    private func updateActiveAppearance() {
        let palette = filerTheme.palette
        let borderColor: NSColor
        if isDropTargetHighlighted {
            borderColor = palette.dropTargetBorderColor
        } else {
            borderColor = isPaneActive ? palette.activeBorderColor : palette.inactiveBorderColor
        }

        let headerColor = isPaneActive ? palette.activeHeaderColor : palette.inactiveHeaderColor

        view.layer?.borderColor = borderColor.cgColor
        view.layer?.backgroundColor = palette.paneBackgroundColor.applyingBackgroundOpacity(backgroundOpacity).cgColor
        headerView.layer?.backgroundColor = headerColor.cgColor
        pathControl.alphaValue = isPaneActive ? 1.0 : 0.82
        searchField.textColor = palette.primaryTextColor
        searchField.backgroundColor = palette.filterBarBackgroundColor.applyingBackgroundOpacity(backgroundOpacity)
        spotlightScopePopUpButton.contentTintColor = isPaneActive ? palette.activePathTextColor : palette.inactivePathTextColor
        tableView.backgroundColor = palette.tableBackgroundColor.applyingBackgroundOpacity(backgroundOpacity)
        scrollView.backgroundColor = palette.tableBackgroundColor.applyingBackgroundOpacity(backgroundOpacity)
        scrollView.alphaValue = isPaneActive ? palette.activePaneAlpha : palette.inactivePaneAlpha
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

    private func makeNameCell(for item: FileItem, row: Int) -> NSTableCellView {
        let cell = tableView.makeView(withIdentifier: Cell.name, owner: self) as? FileNameCellView ?? createNameCellView()

        let isMarked = viewModel.paneState.markedIndices.contains(row)
        cell.setName(isMarked ? "* \(item.name)" : item.name, textColor: filerTheme.palette.primaryTextColor)
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
        if !item.isDirectory && item.url.isImageFile {
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
            }
        }
    }

    private static func generateThumbnail(for url: URL, maxPixelSize: Int) async -> NSImage? {
        await Task.detached(priority: .utility) {
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
        SearchMode(rawValue: searchModeControl.selectedSegment) ?? .filter
    }

    private func focusSearch(mode: SearchMode) {
        if selectedSearchMode != mode {
            searchModeControl.selectedSegment = mode.rawValue
            updateSearchModeUI()
        }

        vimModeState.enterFilterMode()
        tableView.setVimMode(vimModeState.mode)

        view.window?.makeFirstResponder(searchField)
        if let editor = searchField.currentEditor() {
            editor.selectAll(nil)
        }
    }

    private func clearSearchAndReturnToTable() {
        searchField.stringValue = ""
        searchModeControl.selectedSegment = SearchMode.filter.rawValue
        updateSearchModeUI()
        viewModel.clearFilter()
        viewModel.exitSpotlightSearchMode()

        vimModeState.enterNormalMode()
        tableView.setVimMode(vimModeState.mode)
        focusTable()
    }

    private func updateSearchModeUI() {
        let mode = selectedSearchMode
        searchField.placeholderString = mode.placeholder
        spotlightScopePopUpButton.isHidden = mode != .spotlight
    }

    private func selectSpotlightScope(_ scope: SpotlightSearchScope) {
        guard let index = SpotlightSearchScope.allCases.firstIndex(of: scope) else {
            return
        }

        isUpdatingSearchControls = true
        spotlightScopePopUpButton.selectItem(at: index)
        isUpdatingSearchControls = false
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

    @objc
    private func searchModeChanged(_ sender: NSSegmentedControl) {
        guard SearchMode(rawValue: sender.selectedSegment) != nil else {
            return
        }

        updateSearchModeUI()
        applySearchFromHeader()
    }

    @objc
    private func spotlightScopeChanged(_ sender: NSPopUpButton) {
        guard !isUpdatingSearchControls else {
            return
        }

        let index = sender.indexOfSelectedItem
        guard SpotlightSearchScope.allCases.indices.contains(index) else {
            return
        }

        let scope = SpotlightSearchScope.allCases[index]
        viewModel.setSpotlightSearchScope(scope)
        onSpotlightSearchScopeChanged?(scope)
        applySearchFromHeader()
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
            viewModel.goToParent()
            handled = true
        case .cursorRight:
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
        case .enterDirectory:
            openSelectedFile()
            handled = true
        case .switchPane:
            handled = handleTabPressed()
        case .toggleMark:
            viewModel.toggleMark()
            handled = true
        case .markAll:
            viewModel.markAll()
            handled = true
        case .clearMarks:
            viewModel.clearMarks()
            handled = true
        case .enterVisualMode:
            if vimModeState.mode != .visual {
                vimModeState.enterVisualMode(anchorIndex: viewModel.paneState.cursorIndex)
                tableView.setVimMode(vimModeState.mode)
                viewModel.enterVisualMode()
            }
            handled = true
        case .exitVisualMode:
            vimModeState.exitVisualMode()
            tableView.setVimMode(vimModeState.mode)
            viewModel.exitVisualMode()
            handled = true
        case .openFile:
            openSelectedFile()
            handled = true
        case .openFileInFinder:
            revealSelectedInFinder()
            handled = true
        case .copy, .paste, .move, .delete, .rename, .createDirectory, .undo, .togglePreview, .toggleSidebar, .openBookmarkSearch, .openHistory, .addBookmark, .batchRename, .syncPanes:
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
                searchModeControl.selectedSegment = SearchMode.filter.rawValue
                updateSearchModeUI()
            }

            vimModeState.enterNormalMode()
            tableView.setVimMode(vimModeState.mode)
            focusTable()
            return true
        }

        return false
    }

    // MARK: - Context Menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let clickedRow = tableView.clickedRow
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
            title: "Reveal in Finder",
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
        menu.addItem(makeContextMenuItem(title: "Refresh", action: .refresh))
        menu.addItem(makeContextMenuItem(title: "Toggle Hidden Files", action: .toggleHiddenFiles))
        menu.addItem(makeSortMenuItem())

        menu.addItem(NSMenuItem.separator())

        menu.addItem(makeContextMenuItem(title: "Toggle Sidebar", action: .toggleSidebar))
        menu.addItem(makeContextMenuItem(title: "Toggle Preview", action: .togglePreview))
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

        let clickedRow = tableView.clickedRow
        if viewModel.directoryContents.displayedItems.indices.contains(clickedRow) {
            viewModel.setCursor(index: clickedRow)
            return true
        }

        return viewModel.selectedItem != nil
    }
}
