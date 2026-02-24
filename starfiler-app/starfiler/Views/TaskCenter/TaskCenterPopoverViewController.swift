import AppKit

final class TaskCenterPopoverViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
    private let viewModel: TaskCenterViewModel
    private let scrollView = NSScrollView()
    private let tableView = NSTableView()
    private let headerLabel = NSTextField(labelWithString: "Task Center")
    private let clearButton = NSButton(title: "Clear", target: nil, action: nil)
    private let emptyLabel = NSTextField(labelWithString: "No operations")

    private static let rowIdentifier = NSUserInterfaceItemIdentifier("TaskCenterEntryRow")
    private static let popoverWidth: CGFloat = 420
    private static let popoverMaxHeight: CGFloat = 500
    private static let rowHeight: CGFloat = 52

    init(viewModel: TaskCenterViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: Self.popoverWidth, height: 200))
        self.view = container
        setupUI()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        viewModel.onEntriesChanged = { [weak self] in
            self?.reloadData()
        }
        reloadData()
    }

    private func setupUI() {
        headerLabel.translatesAutoresizingMaskIntoConstraints = false
        headerLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        headerLabel.textColor = .labelColor

        clearButton.translatesAutoresizingMaskIntoConstraints = false
        clearButton.bezelStyle = .inline
        clearButton.controlSize = .small
        clearButton.font = .systemFont(ofSize: 11)
        clearButton.target = self
        clearButton.action = #selector(clearHistory)

        let headerStack = NSStackView(views: [headerLabel, clearButton])
        headerStack.translatesAutoresizingMaskIntoConstraints = false
        headerStack.orientation = .horizontal
        headerStack.distribution = .fill
        headerStack.edgeInsets = NSEdgeInsets(top: 8, left: 12, bottom: 4, right: 12)

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("main"))
        column.width = Self.popoverWidth - 2
        tableView.addTableColumn(column)
        tableView.headerView = nil
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = Self.rowHeight
        tableView.style = .plain
        tableView.selectionHighlightStyle = .none
        tableView.intercellSpacing = NSSize(width: 0, height: 1)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false

        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        emptyLabel.font = .systemFont(ofSize: 12)
        emptyLabel.textColor = .tertiaryLabelColor
        emptyLabel.alignment = .center
        emptyLabel.isHidden = true

        view.addSubview(headerStack)
        view.addSubview(scrollView)
        view.addSubview(emptyLabel)

        NSLayoutConstraint.activate([
            headerStack.topAnchor.constraint(equalTo: view.topAnchor),
            headerStack.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerStack.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            scrollView.topAnchor.constraint(equalTo: headerStack.bottomAnchor, constant: 4),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            emptyLabel.centerXAnchor.constraint(equalTo: scrollView.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: scrollView.centerYAnchor)
        ])
    }

    private func reloadData() {
        tableView.reloadData()

        let isEmpty = viewModel.entries.isEmpty
        emptyLabel.isHidden = !isEmpty
        scrollView.isHidden = isEmpty
        clearButton.isHidden = viewModel.historyEntries.isEmpty

        updatePreferredContentSize()
    }

    private func updatePreferredContentSize() {
        let headerHeight: CGFloat = 36
        let entryCount = viewModel.entries.count
        let contentHeight = headerHeight + CGFloat(entryCount) * Self.rowHeight + 8
        let clampedHeight = max(100, min(contentHeight, Self.popoverMaxHeight))
        self.preferredContentSize = NSSize(width: Self.popoverWidth, height: clampedHeight)
    }

    @objc private func clearHistory() {
        viewModel.clearHistory()
    }

    // MARK: - NSTableViewDataSource

    func numberOfRows(in tableView: NSTableView) -> Int {
        viewModel.entries.count
    }

    // MARK: - NSTableViewDelegate

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < viewModel.entries.count else {
            return nil
        }

        let entry = viewModel.entries[row]

        let cellView: TaskCenterEntryRowView
        if let reused = tableView.makeView(withIdentifier: Self.rowIdentifier, owner: self) as? TaskCenterEntryRowView {
            cellView = reused
        } else {
            cellView = TaskCenterEntryRowView()
            cellView.identifier = Self.rowIdentifier
        }

        cellView.configure(with: entry)
        cellView.onCancel = { [weak self] in
            self?.viewModel.cancelEntry(entry.id)
        }
        cellView.onRetry = { [weak self] in
            self?.viewModel.retryFailedEntry(entry.id)
        }
        cellView.onCopyErrorDetail = { [weak self] in
            self?.viewModel.copyErrorDetail(for: entry.id)
        }

        return cellView
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        guard row < viewModel.entries.count else {
            return Self.rowHeight
        }
        let entry = viewModel.entries[row]
        if case .failed = entry.status {
            return Self.rowHeight + 8
        }
        return Self.rowHeight
    }
}
