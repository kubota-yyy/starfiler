import AppKit

private final class AppearanceTrackingView: NSView {
    var onAppearanceChanged: (() -> Void)?

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        onAppearanceChanged?()
    }
}

private struct FilerThemePalette {
    let activeBorderColor: NSColor
    let inactiveBorderColor: NSColor
    let dropTargetBorderColor: NSColor
    let activeHeaderColor: NSColor
    let inactiveHeaderColor: NSColor
    let activePathTextColor: NSColor
    let inactivePathTextColor: NSColor
    let markedColor: NSColor
    let visualMarkedColor: NSColor
    let activePaneAlpha: CGFloat
    let inactivePaneAlpha: CGFloat
}

private extension FilerTheme {
    static func dynamicColor(light: NSColor, dark: NSColor) -> NSColor {
        NSColor(name: nil) { appearance in
            let bestMatch = appearance.bestMatch(from: [.aqua, .darkAqua])
            return bestMatch == .darkAqua ? dark : light
        }
    }

    var palette: FilerThemePalette {
        switch self {
        case .system:
            return FilerThemePalette(
                activeBorderColor: .controlAccentColor,
                inactiveBorderColor: .separatorColor,
                dropTargetBorderColor: .systemBlue,
                activeHeaderColor: NSColor.controlAccentColor.withAlphaComponent(0.16),
                inactiveHeaderColor: NSColor.quaternaryLabelColor.withAlphaComponent(0.1),
                activePathTextColor: .labelColor,
                inactivePathTextColor: .secondaryLabelColor,
                markedColor: NSColor.systemOrange.withAlphaComponent(0.14),
                visualMarkedColor: NSColor.controlAccentColor.withAlphaComponent(0.22),
                activePaneAlpha: 1.0,
                inactivePaneAlpha: 0.86
            )
        case .ocean:
            return FilerThemePalette(
                activeBorderColor: Self.dynamicColor(light: NSColor(calibratedRed: 0.12, green: 0.44, blue: 0.78, alpha: 1.0), dark: NSColor(calibratedRed: 0.22, green: 0.62, blue: 0.98, alpha: 1.0)),
                inactiveBorderColor: Self.dynamicColor(light: NSColor(calibratedRed: 0.58, green: 0.68, blue: 0.76, alpha: 1.0), dark: NSColor(calibratedRed: 0.36, green: 0.46, blue: 0.56, alpha: 1.0)),
                dropTargetBorderColor: Self.dynamicColor(light: NSColor(calibratedRed: 0.08, green: 0.52, blue: 0.86, alpha: 1.0), dark: NSColor(calibratedRed: 0.34, green: 0.7, blue: 1.0, alpha: 1.0)),
                activeHeaderColor: Self.dynamicColor(light: NSColor(calibratedRed: 0.12, green: 0.44, blue: 0.78, alpha: 0.18), dark: NSColor(calibratedRed: 0.2, green: 0.56, blue: 0.92, alpha: 0.3)),
                inactiveHeaderColor: Self.dynamicColor(light: NSColor(calibratedRed: 0.44, green: 0.6, blue: 0.74, alpha: 0.12), dark: NSColor(calibratedRed: 0.22, green: 0.3, blue: 0.42, alpha: 0.22)),
                activePathTextColor: .labelColor,
                inactivePathTextColor: .secondaryLabelColor,
                markedColor: Self.dynamicColor(light: NSColor(calibratedRed: 0.22, green: 0.62, blue: 0.94, alpha: 0.16), dark: NSColor(calibratedRed: 0.16, green: 0.52, blue: 0.86, alpha: 0.34)),
                visualMarkedColor: Self.dynamicColor(light: NSColor(calibratedRed: 0.04, green: 0.48, blue: 0.88, alpha: 0.24), dark: NSColor(calibratedRed: 0.24, green: 0.62, blue: 1.0, alpha: 0.4)),
                activePaneAlpha: 1.0,
                inactivePaneAlpha: 0.9
            )
        case .forest:
            return FilerThemePalette(
                activeBorderColor: Self.dynamicColor(light: NSColor(calibratedRed: 0.16, green: 0.5, blue: 0.34, alpha: 1.0), dark: NSColor(calibratedRed: 0.3, green: 0.72, blue: 0.48, alpha: 1.0)),
                inactiveBorderColor: Self.dynamicColor(light: NSColor(calibratedRed: 0.56, green: 0.68, blue: 0.58, alpha: 1.0), dark: NSColor(calibratedRed: 0.34, green: 0.46, blue: 0.36, alpha: 1.0)),
                dropTargetBorderColor: Self.dynamicColor(light: NSColor(calibratedRed: 0.08, green: 0.62, blue: 0.38, alpha: 1.0), dark: NSColor(calibratedRed: 0.24, green: 0.82, blue: 0.54, alpha: 1.0)),
                activeHeaderColor: Self.dynamicColor(light: NSColor(calibratedRed: 0.16, green: 0.5, blue: 0.34, alpha: 0.18), dark: NSColor(calibratedRed: 0.2, green: 0.56, blue: 0.36, alpha: 0.32)),
                inactiveHeaderColor: Self.dynamicColor(light: NSColor(calibratedRed: 0.46, green: 0.6, blue: 0.5, alpha: 0.12), dark: NSColor(calibratedRed: 0.22, green: 0.32, blue: 0.26, alpha: 0.24)),
                activePathTextColor: .labelColor,
                inactivePathTextColor: .secondaryLabelColor,
                markedColor: Self.dynamicColor(light: NSColor(calibratedRed: 0.26, green: 0.64, blue: 0.34, alpha: 0.18), dark: NSColor(calibratedRed: 0.18, green: 0.52, blue: 0.28, alpha: 0.34)),
                visualMarkedColor: Self.dynamicColor(light: NSColor(calibratedRed: 0.16, green: 0.56, blue: 0.3, alpha: 0.26), dark: NSColor(calibratedRed: 0.24, green: 0.7, blue: 0.4, alpha: 0.42)),
                activePaneAlpha: 1.0,
                inactivePaneAlpha: 0.9
            )
        case .sunset:
            return FilerThemePalette(
                activeBorderColor: Self.dynamicColor(light: NSColor(calibratedRed: 0.82, green: 0.36, blue: 0.18, alpha: 1.0), dark: NSColor(calibratedRed: 0.98, green: 0.54, blue: 0.24, alpha: 1.0)),
                inactiveBorderColor: Self.dynamicColor(light: NSColor(calibratedRed: 0.76, green: 0.62, blue: 0.52, alpha: 1.0), dark: NSColor(calibratedRed: 0.52, green: 0.42, blue: 0.36, alpha: 1.0)),
                dropTargetBorderColor: Self.dynamicColor(light: NSColor(calibratedRed: 0.94, green: 0.44, blue: 0.16, alpha: 1.0), dark: NSColor(calibratedRed: 1.0, green: 0.62, blue: 0.28, alpha: 1.0)),
                activeHeaderColor: Self.dynamicColor(light: NSColor(calibratedRed: 0.86, green: 0.44, blue: 0.2, alpha: 0.18), dark: NSColor(calibratedRed: 0.92, green: 0.5, blue: 0.24, alpha: 0.32)),
                inactiveHeaderColor: Self.dynamicColor(light: NSColor(calibratedRed: 0.78, green: 0.62, blue: 0.54, alpha: 0.12), dark: NSColor(calibratedRed: 0.42, green: 0.32, blue: 0.28, alpha: 0.24)),
                activePathTextColor: .labelColor,
                inactivePathTextColor: .secondaryLabelColor,
                markedColor: Self.dynamicColor(light: NSColor(calibratedRed: 0.92, green: 0.5, blue: 0.2, alpha: 0.18), dark: NSColor(calibratedRed: 0.74, green: 0.34, blue: 0.16, alpha: 0.34)),
                visualMarkedColor: Self.dynamicColor(light: NSColor(calibratedRed: 0.94, green: 0.42, blue: 0.18, alpha: 0.28), dark: NSColor(calibratedRed: 0.92, green: 0.48, blue: 0.22, alpha: 0.44)),
                activePaneAlpha: 1.0,
                inactivePaneAlpha: 0.9
            )
        }
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

final class FilePaneViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate, NSMenuDelegate, KeyActionDelegate {
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
    private let headerView = NSView()
    private let pathLabel = NSTextField(labelWithString: "")
    private let scrollView = NSScrollView()
    private let tableView = FileTableView()
    private let filterBarViewController = FilterBarViewController()
    private let spotlightBarViewController = FilterBarViewController(prompt: "?", placeholder: "Search with Spotlight...")
    private let fileDragSource = FileDragSource()

    private lazy var fileDropTarget = FileDropTarget { [weak self] in
        self?.viewModel.paneState.currentDirectory ?? UserPaths.homeDirectoryURL
    }

    private var isPaneActive = false
    private var isDropTargetHighlighted = false
    private var vimModeState = VimModeState()
    private var filerTheme: FilerTheme = .system

    var onStatusChanged: ((String, Int, Int) -> Void)?
    var onSelectionChanged: ((FileItem?) -> Void)?
    var onTabPressed: (() -> Bool)?
    var onDidRequestActivate: (() -> Void)?
    var onFileOperationRequested: ((KeyAction) -> Bool)?
    var onBookmarkJump: ((String) -> Void)?

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
        configureFilterBar()
        configureSpotlightBar()
        configureDragAndDrop()
        configureContextMenu()
        bindViewModel()
        setActive(false)
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

    private func showBookmarkJumpHint(_ hint: String) {
        onStatusChanged?(hint, viewModel.directoryContents.displayedItems.count, viewModel.markedCount)
    }

    func applyTheme(_ theme: FilerTheme) {
        filerTheme = theme
        tableView.reloadData()
        updateActiveAppearance()
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

        pathLabel.translatesAutoresizingMaskIntoConstraints = false
        pathLabel.lineBreakMode = .byTruncatingMiddle
        pathLabel.font = .monospacedSystemFont(ofSize: 12, weight: .semibold)
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
        tableView.backgroundColor = .textBackgroundColor

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

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true

        tableView.didBecomeFirstResponderHandler = { [weak self] in
            self?.onDidRequestActivate?()
        }
    }

    private func configureLayout() {
        view.addSubview(headerView)
        view.addSubview(scrollView)

        headerView.addSubview(pathLabel)

        NSLayoutConstraint.activate([
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            headerView.topAnchor.constraint(equalTo: view.topAnchor),
            headerView.heightAnchor.constraint(equalToConstant: 28),

            pathLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 10),
            pathLabel.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -10),
            pathLabel.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),

            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: headerView.bottomAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func configureFilterBar() {
        addChild(filterBarViewController)

        let filterView = filterBarViewController.view
        view.addSubview(filterView)

        NSLayoutConstraint.activate([
            filterView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            filterView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
            filterView.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 8)
        ])

        filterBarViewController.onTextChanged = { [weak self] text in
            self?.viewModel.setFilterText(text)
        }

        filterBarViewController.onDidClose = { [weak self] _ in
            guard let self else {
                return
            }

            self.vimModeState.enterNormalMode()
            self.tableView.setVimMode(self.vimModeState.mode)
            self.focusTable()
        }
    }

    private func configureSpotlightBar() {
        addChild(spotlightBarViewController)

        let spotlightView = spotlightBarViewController.view
        view.addSubview(spotlightView)

        NSLayoutConstraint.activate([
            spotlightView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            spotlightView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
            spotlightView.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 8)
        ])

        spotlightBarViewController.onTextChanged = { [weak self] text in
            self?.viewModel.updateSpotlightSearchQuery(text)
        }

        spotlightBarViewController.onDidClose = { [weak self] reason in
            guard let self else {
                return
            }

            if reason == .submit {
                self.viewModel.enterSelected()
            }
            self.viewModel.exitSpotlightSearchMode()

            self.vimModeState.enterNormalMode()
            self.tableView.setVimMode(self.vimModeState.mode)
            self.focusTable()
        }
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

        fileDropTarget.onDropCompleted = { [weak self] in
            self?.viewModel.refreshCurrentDirectory()
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

            self.tableView.reloadData()
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
        let path = viewModel.paneState.currentDirectory.path
        pathLabel.stringValue = path
        onStatusChanged?(path, viewModel.directoryContents.displayedItems.count, viewModel.markedCount)
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
        headerView.layer?.backgroundColor = headerColor.cgColor
        pathLabel.textColor = isPaneActive ? palette.activePathTextColor : palette.inactivePathTextColor
        scrollView.alphaValue = isPaneActive ? palette.activePaneAlpha : palette.inactivePaneAlpha
    }

    private func makeNameCell(for item: FileItem, row: Int) -> NSTableCellView {
        let cell = tableView.makeView(withIdentifier: Cell.name, owner: self) as? NSTableCellView ?? createNameCellView()

        let isMarked = viewModel.paneState.markedIndices.contains(row)
        cell.textField?.stringValue = isMarked ? "* \(item.name)" : item.name

        let icon = NSWorkspace.shared.icon(forFile: item.url.path)
        icon.size = NSSize(width: 16, height: 16)
        cell.imageView?.image = icon

        return cell
    }

    private func makeTextCell(text: String, alignment: NSTextAlignment) -> NSTableCellView {
        let cell = tableView.makeView(withIdentifier: Cell.text, owner: self) as? NSTableCellView ?? createTextCellView()
        cell.textField?.stringValue = text
        cell.textField?.alignment = alignment
        return cell
    }

    private func createNameCellView() -> NSTableCellView {
        let cell = NSTableCellView()
        cell.identifier = Cell.name

        let imageView = NSImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false

        let textField = NSTextField(labelWithString: "")
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.lineBreakMode = .byTruncatingMiddle

        cell.imageView = imageView
        cell.textField = textField

        cell.addSubview(imageView)
        cell.addSubview(textField)

        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 4),
            imageView.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            imageView.widthAnchor.constraint(equalToConstant: 16),
            imageView.heightAnchor.constraint(equalToConstant: 16),

            textField.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 8),
            textField.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -4),
            textField.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
        ])

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

    private func showFilterBar() {
        if spotlightBarViewController.isVisible {
            spotlightBarViewController.close()
        }

        vimModeState.enterFilterMode()
        tableView.setVimMode(vimModeState.mode)
        filterBarViewController.show(currentText: viewModel.directoryContents.filterText)
    }

    private func closeFilterBar() {
        filterBarViewController.close()
    }

    private func showSpotlightSearchBar() {
        if filterBarViewController.isVisible {
            filterBarViewController.close()
        }

        viewModel.enterSpotlightSearchMode()
        vimModeState.enterFilterMode()
        tableView.setVimMode(vimModeState.mode)
        spotlightBarViewController.show(currentText: "")
    }

    private func closeSpotlightSearchBar() {
        spotlightBarViewController.close()
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
            showFilterBar()
            handled = true
        case .enterSpotlightSearch:
            showSpotlightSearchBar()
            handled = true
        case .clearFilter:
            if filterBarViewController.isVisible {
                closeFilterBar()
            } else if spotlightBarViewController.isVisible {
                closeSpotlightSearchBar()
            } else {
                viewModel.clearFilter()
                vimModeState.enterNormalMode()
                tableView.setVimMode(vimModeState.mode)
            }
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

    // MARK: - Context Menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let clickedRow = tableView.clickedRow
        guard clickedRow >= 0, viewModel.directoryContents.displayedItems.indices.contains(clickedRow) else {
            return
        }

        let item = viewModel.directoryContents.displayedItems[clickedRow]

        if item.isDirectory && !item.isPackage {
            let openItem = NSMenuItem(title: "Open", action: #selector(contextMenuOpen(_:)), keyEquivalent: "")
            openItem.target = self
            menu.addItem(openItem)
        } else {
            let openItem = NSMenuItem(title: "Open with Default App", action: #selector(contextMenuOpen(_:)), keyEquivalent: "")
            openItem.target = self
            menu.addItem(openItem)
        }

        let revealItem = NSMenuItem(title: "Reveal in Finder", action: #selector(contextMenuRevealInFinder(_:)), keyEquivalent: "")
        revealItem.target = self
        menu.addItem(revealItem)

        menu.addItem(NSMenuItem.separator())

        let copyItem = NSMenuItem(title: "Copy", action: #selector(contextMenuCopy(_:)), keyEquivalent: "")
        copyItem.target = self
        menu.addItem(copyItem)

        let moveItem = NSMenuItem(title: "Cut", action: #selector(contextMenuCut(_:)), keyEquivalent: "")
        moveItem.target = self
        menu.addItem(moveItem)

        menu.addItem(NSMenuItem.separator())

        let renameItem = NSMenuItem(title: "Rename...", action: #selector(contextMenuRename(_:)), keyEquivalent: "")
        renameItem.target = self
        menu.addItem(renameItem)

        let deleteItem = NSMenuItem(title: "Move to Trash", action: #selector(contextMenuDelete(_:)), keyEquivalent: "")
        deleteItem.target = self
        menu.addItem(deleteItem)

        menu.addItem(NSMenuItem.separator())

        let newFolderItem = NSMenuItem(title: "New Folder", action: #selector(contextMenuNewFolder(_:)), keyEquivalent: "")
        newFolderItem.target = self
        menu.addItem(newFolderItem)
    }

    @objc private func contextMenuOpen(_ sender: Any?) {
        let clickedRow = tableView.clickedRow
        guard clickedRow >= 0 else {
            return
        }
        viewModel.setCursor(index: clickedRow)
        openSelectedFile()
    }

    @objc private func contextMenuRevealInFinder(_ sender: Any?) {
        let clickedRow = tableView.clickedRow
        guard clickedRow >= 0,
              viewModel.directoryContents.displayedItems.indices.contains(clickedRow) else {
            return
        }
        let item = viewModel.directoryContents.displayedItems[clickedRow]
        NSWorkspace.shared.activateFileViewerSelecting([item.url])
    }

    @objc private func contextMenuCopy(_ sender: Any?) {
        onFileOperationRequested?(.copy)
    }

    @objc private func contextMenuCut(_ sender: Any?) {
        onFileOperationRequested?(.move)
    }

    @objc private func contextMenuRename(_ sender: Any?) {
        onFileOperationRequested?(.rename)
    }

    @objc private func contextMenuDelete(_ sender: Any?) {
        onFileOperationRequested?(.delete)
    }

    @objc private func contextMenuNewFolder(_ sender: Any?) {
        onFileOperationRequested?(.createDirectory)
    }
}
