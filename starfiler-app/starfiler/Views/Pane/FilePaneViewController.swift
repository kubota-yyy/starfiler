import AppKit

final class FilePaneViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
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
    private let scrollView = NSScrollView()
    private let tableView = FileTableView()

    var onStatusChanged: ((String, Int) -> Void)?

    init(viewModel: FilePaneViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = NSView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureTableView()
        configureLayout()
        bindViewModel()
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        view.window?.makeFirstResponder(tableView)
    }

    func focusTable() {
        view.window?.makeFirstResponder(tableView)
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
            return makeNameCell(for: item)
        case Column.size:
            return makeTextCell(text: sizeText(for: item), alignment: .right)
        case Column.modified:
            return makeTextCell(text: modifiedText(for: item), alignment: .left)
        default:
            return nil
        }
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        let selectedRow = tableView.selectedRow
        guard selectedRow >= 0 else {
            return
        }
        viewModel.setCursor(index: selectedRow)
    }

    private func configureTableView() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.headerView = NSTableHeaderView()
        tableView.intercellSpacing = NSSize(width: 8, height: 0)

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

        tableView.keyDownHandler = { [weak self] event in
            self?.handleKeyEvent(event) ?? false
        }
    }

    private func configureLayout() {
        view.addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func bindViewModel() {
        viewModel.onItemsChanged = { [weak self] _ in
            guard let self else {
                return
            }

            self.tableView.reloadData()
            self.syncSelectionFromViewModel()
            self.publishStatus()
        }

        viewModel.onCursorChanged = { [weak self] _ in
            self?.syncSelectionFromViewModel()
        }

        publishStatus()
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
        onStatusChanged?(viewModel.paneState.currentDirectory.path, viewModel.directoryContents.displayedItems.count)
    }

    private func makeNameCell(for item: FileItem) -> NSTableCellView {
        let cell = tableView.makeView(withIdentifier: Cell.name, owner: self) as? NSTableCellView ?? createNameCellView()
        cell.textField?.stringValue = item.name

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

    private func handleKeyEvent(_ event: NSEvent) -> Bool {
        switch event.keyCode {
        case 125: // Down
            viewModel.moveCursor(by: 1)
            return true
        case 126: // Up
            viewModel.moveCursor(by: -1)
            return true
        case 36, 76: // Return / Enter
            viewModel.enterSelected()
            return true
        case 51: // Backspace
            viewModel.goToParent()
            return true
        default:
            return false
        }
    }
}
