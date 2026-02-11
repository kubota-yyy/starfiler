import AppKit

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

    override func drawBackground(in dirtyRect: NSRect) {
        guard isMarkedRow else {
            super.drawBackground(in: dirtyRect)
            return
        }

        let color = isVisualMode
            ? NSColor.controlAccentColor.withAlphaComponent(0.22)
            : NSColor.systemOrange.withAlphaComponent(0.14)

        color.setFill()
        dirtyRect.fill()
    }
}

final class FilePaneViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate, KeyActionDelegate {
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

    var onStatusChanged: ((String, Int, Int) -> Void)?
    var onSelectionChanged: ((FileItem?) -> Void)?
    var onTabPressed: (() -> Bool)?
    var onDidRequestActivate: (() -> Void)?
    var onFileOperationRequested: ((KeyAction) -> Bool)?

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
        let rowView = MarkedRowView()
        rowView.isMarkedRow = viewModel.paneState.markedIndices.contains(row)
        rowView.isVisualMode = vimModeState.mode == .visual
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
        let borderColor: NSColor
        if isDropTargetHighlighted {
            borderColor = .systemBlue
        } else {
            borderColor = isPaneActive ? .controlAccentColor : .separatorColor
        }

        let headerColor = isPaneActive
            ? NSColor.controlAccentColor.withAlphaComponent(0.16)
            : NSColor.quaternaryLabelColor.withAlphaComponent(0.1)

        view.layer?.borderColor = borderColor.cgColor
        headerView.layer?.backgroundColor = headerColor.cgColor
        pathLabel.textColor = isPaneActive ? .labelColor : .secondaryLabelColor
        scrollView.alphaValue = isPaneActive ? 1.0 : 0.86
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
            viewModel.enterSelected()
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
        case .copy, .paste, .move, .delete, .rename, .createDirectory, .undo, .togglePreview, .openBookmarks, .addBookmark:
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
}
