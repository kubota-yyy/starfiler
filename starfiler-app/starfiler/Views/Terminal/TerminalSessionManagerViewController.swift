import AppKit

final class TerminalSessionManagerViewController: NSViewController {
    private let viewModel: TerminalSessionManagerViewModel
    private let listViewModel: TerminalSessionListViewModel

    private let searchField = NSSearchField()
    private let filterSegment = NSSegmentedControl()
    private let headerLabel = NSTextField(labelWithString: "")
    private let scrollView = NSScrollView()
    private let tableView = NSTableView()

    var onCreateSession: ((TerminalSessionCommand) -> Void)?
    var onOpenSession: ((UUID) -> Void)?
    var onCloseSession: ((UUID) -> Void)?

    init(viewModel: TerminalSessionManagerViewModel, listViewModel: TerminalSessionListViewModel) {
        self.viewModel = viewModel
        self.listViewModel = listViewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        let root = NSView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
        root.wantsLayer = true
        root.setAccessibilityIdentifier("sessionManager.container")

        setupSearchField()
        setupFilterSegment()
        setupHeaderLabel()
        setupTableView()

        let searchStack = NSStackView(views: [searchField, filterSegment])
        searchStack.translatesAutoresizingMaskIntoConstraints = false
        searchStack.orientation = .horizontal
        searchStack.spacing = 8

        root.addSubview(searchStack)
        root.addSubview(headerLabel)
        root.addSubview(scrollView)

        NSLayoutConstraint.activate([
            searchStack.topAnchor.constraint(equalTo: root.topAnchor, constant: 12),
            searchStack.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 12),
            searchStack.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -12),

            headerLabel.topAnchor.constraint(equalTo: searchStack.bottomAnchor, constant: 8),
            headerLabel.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 12),
            headerLabel.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -12),

            scrollView.topAnchor.constraint(equalTo: headerLabel.bottomAnchor, constant: 4),
            scrollView.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: root.bottomAnchor),
        ])

        view = root
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        bindViewModel()
        viewModel.reloadSessions()
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        viewModel.reloadSessions()
    }

    private func setupSearchField() {
        searchField.translatesAutoresizingMaskIntoConstraints = false
        searchField.placeholderString = "Search sessions..."
        searchField.delegate = self
        searchField.setAccessibilityIdentifier("sessionManager.searchField")
        searchField.setContentHuggingPriority(.defaultLow, for: .horizontal)
    }

    private func setupFilterSegment() {
        filterSegment.translatesAutoresizingMaskIntoConstraints = false
        filterSegment.segmentStyle = .rounded
        filterSegment.segmentCount = TerminalSessionProviderFilter.allCases.count
        for (index, filter) in TerminalSessionProviderFilter.allCases.enumerated() {
            filterSegment.setLabel(filter.displayName, forSegment: index)
            filterSegment.setWidth(52, forSegment: index)
        }
        filterSegment.selectedSegment = 0
        filterSegment.target = self
        filterSegment.action = #selector(filterChanged)
        filterSegment.setContentHuggingPriority(.required, for: .horizontal)
    }

    private func setupHeaderLabel() {
        headerLabel.translatesAutoresizingMaskIntoConstraints = false
        headerLabel.font = .systemFont(ofSize: 11, weight: .semibold)
        headerLabel.textColor = .secondaryLabelColor
        headerLabel.setAccessibilityIdentifier("sessionManager.headerLabel")
        updateHeaderLabel()
    }

    private func setupTableView() {
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("SessionManagerColumn"))
        column.title = ""
        tableView.addTableColumn(column)
        tableView.headerView = nil
        tableView.rowHeight = 44
        tableView.delegate = self
        tableView.dataSource = self
        tableView.selectionHighlightStyle = .regular
        tableView.style = .plain
        tableView.doubleAction = #selector(tableDoubleClicked)
        tableView.target = self

        let menu = NSMenu()
        menu.delegate = self
        tableView.menu = menu

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
    }

    private func bindViewModel() {
        viewModel.onSessionsChanged = { [weak self] in
            self?.tableView.reloadData()
            self?.updateHeaderLabel()
        }

        viewModel.onOpenSession = { [weak self] id in
            self?.onOpenSession?(id)
        }
    }

    private func updateHeaderLabel() {
        let totalCount = viewModel.displayedSessions().count
        let runningCount = viewModel.runningSessionCount
        if totalCount == 0 {
            headerLabel.stringValue = "セッションなし"
        } else if runningCount > 0 {
            headerLabel.stringValue = "\(totalCount) セッション（実行中 \(runningCount)）"
        } else {
            headerLabel.stringValue = "\(totalCount) セッション"
        }
    }

    private enum DisplayRow {
        case session(TerminalSession)
        case searchResult(TerminalSessionSearchResult)
    }

    private var displayRows: [DisplayRow] {
        if viewModel.isSearching {
            return viewModel.searchResults.map { .searchResult($0) }
        } else {
            return viewModel.displayedSessions().map { .session($0) }
        }
    }

    private func session(at row: Int) -> TerminalSession? {
        let rows = displayRows
        guard row >= 0, row < rows.count else { return nil }
        switch rows[row] {
        case .session(let session):
            return session
        case .searchResult(let result):
            return result.session
        }
    }

    private func searchResult(at row: Int) -> TerminalSessionSearchResult? {
        let rows = displayRows
        guard row >= 0, row < rows.count else { return nil }
        if case .searchResult(let result) = rows[row] {
            return result
        }
        return nil
    }

    @objc private func filterChanged() {
        let index = filterSegment.selectedSegment
        viewModel.providerFilter = TerminalSessionProviderFilter.allCases[index]
    }

    @objc private func tableDoubleClicked() {
        let row = tableView.clickedRow
        guard let session = session(at: row) else { return }
        onOpenSession?(session.id)
    }
}

// MARK: - NSSearchFieldDelegate

extension TerminalSessionManagerViewController: NSSearchFieldDelegate {
    func controlTextDidChange(_ obj: Notification) {
        viewModel.searchQuery = searchField.stringValue
    }
}

// MARK: - NSTableViewDataSource

extension TerminalSessionManagerViewController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        displayRows.count
    }
}

// MARK: - NSTableViewDelegate

extension TerminalSessionManagerViewController: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cellId = NSUserInterfaceItemIdentifier("SessionManagerCell")
        let cell: SessionManagerCellView
        if let reused = tableView.makeView(withIdentifier: cellId, owner: nil) as? SessionManagerCellView {
            cell = reused
        } else {
            cell = SessionManagerCellView(frame: .zero)
            cell.identifier = cellId
        }

        if let result = searchResult(at: row) {
            cell.configure(with: result.session, snippet: result.matchedLines.first)
        } else if let session = session(at: row) {
            cell.configure(with: session, snippet: nil)
        }

        return cell
    }
}

// MARK: - NSMenuDelegate

extension TerminalSessionManagerViewController: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let row = tableView.clickedRow
        guard let session = session(at: row) else { return }

        let openItem = NSMenuItem(title: "Open Session", action: #selector(contextOpenSession(_:)), keyEquivalent: "")
        openItem.target = self
        openItem.representedObject = session.id
        menu.addItem(openItem)

        menu.addItem(NSMenuItem.separator())

        let renameItem = NSMenuItem(title: "Rename Session…", action: #selector(contextRenameSession(_:)), keyEquivalent: "")
        renameItem.target = self
        renameItem.representedObject = session.id
        menu.addItem(renameItem)

        let pinTitle = session.isPinned ? "Unpin" : "Pin"
        let pinItem = NSMenuItem(title: pinTitle, action: #selector(contextTogglePin(_:)), keyEquivalent: "")
        pinItem.target = self
        pinItem.representedObject = session.id
        menu.addItem(pinItem)

        menu.addItem(NSMenuItem.separator())

        let closeItem = NSMenuItem(title: "Close Session", action: #selector(contextCloseSession(_:)), keyEquivalent: "")
        closeItem.target = self
        closeItem.representedObject = session.id
        menu.addItem(closeItem)
    }

    @objc private func contextOpenSession(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? UUID else { return }
        onOpenSession?(id)
    }

    @objc private func contextRenameSession(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? UUID else { return }
        let alert = NSAlert()
        alert.messageText = "Rename Session"
        alert.informativeText = "Enter new name:"
        alert.addButton(withTitle: "Rename")
        alert.addButton(withTitle: "Cancel")
        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 250, height: 24))
        if let session = viewModel.sessions.first(where: { $0.id == id }) {
            input.stringValue = session.title
        }
        alert.accessoryView = input
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            let newTitle = input.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !newTitle.isEmpty {
                viewModel.renameSession(id: id, title: newTitle)
            }
        }
    }

    @objc private func contextTogglePin(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? UUID else { return }
        if let session = viewModel.sessions.first(where: { $0.id == id }) {
            if session.isPinned {
                viewModel.unpinSession(id: id)
            } else {
                viewModel.pinSession(id: id)
            }
        }
    }

    @objc private func contextCloseSession(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? UUID else { return }
        onCloseSession?(id)
    }
}

// MARK: - SessionManagerCellView

final class SessionManagerCellView: NSTableCellView {
    private let statusDot = NSView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let providerLabel = NSTextField(labelWithString: "")
    private let cwdLabel = NSTextField(labelWithString: "")
    private let snippetLabel = NSTextField(labelWithString: "")
    private let pinIcon = NSImageView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        statusDot.translatesAutoresizingMaskIntoConstraints = false
        statusDot.wantsLayer = true
        statusDot.layer?.cornerRadius = 4

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .systemFont(ofSize: 13, weight: .medium)
        titleLabel.lineBreakMode = .byTruncatingTail

        providerLabel.translatesAutoresizingMaskIntoConstraints = false
        providerLabel.font = .systemFont(ofSize: 10, weight: .regular)
        providerLabel.textColor = .tertiaryLabelColor

        cwdLabel.translatesAutoresizingMaskIntoConstraints = false
        cwdLabel.font = .systemFont(ofSize: 10, weight: .regular)
        cwdLabel.textColor = .tertiaryLabelColor
        cwdLabel.lineBreakMode = .byTruncatingMiddle

        snippetLabel.translatesAutoresizingMaskIntoConstraints = false
        snippetLabel.font = .systemFont(ofSize: 10, weight: .regular)
        snippetLabel.textColor = .secondaryLabelColor
        snippetLabel.lineBreakMode = .byTruncatingTail

        pinIcon.translatesAutoresizingMaskIntoConstraints = false
        pinIcon.image = NSImage(systemSymbolName: "pin.fill", accessibilityDescription: "Pinned")
        pinIcon.contentTintColor = .tertiaryLabelColor
        pinIcon.imageScaling = .scaleProportionallyDown
        pinIcon.isHidden = true

        addSubview(statusDot)
        addSubview(titleLabel)
        addSubview(providerLabel)
        addSubview(cwdLabel)
        addSubview(snippetLabel)
        addSubview(pinIcon)

        NSLayoutConstraint.activate([
            statusDot.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            statusDot.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            statusDot.widthAnchor.constraint(equalToConstant: 8),
            statusDot.heightAnchor.constraint(equalToConstant: 8),

            pinIcon.leadingAnchor.constraint(equalTo: statusDot.trailingAnchor, constant: 4),
            pinIcon.centerYAnchor.constraint(equalTo: statusDot.centerYAnchor),
            pinIcon.widthAnchor.constraint(equalToConstant: 12),
            pinIcon.heightAnchor.constraint(equalToConstant: 12),

            titleLabel.leadingAnchor.constraint(equalTo: pinIcon.trailingAnchor, constant: 4),
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: providerLabel.leadingAnchor, constant: -8),

            providerLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            providerLabel.topAnchor.constraint(equalTo: topAnchor, constant: 6),

            cwdLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            cwdLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 1),
            cwdLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),

            snippetLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            snippetLabel.topAnchor.constraint(equalTo: cwdLabel.bottomAnchor, constant: 1),
            snippetLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
        ])
    }

    func configure(with session: TerminalSession, snippet: String?) {
        titleLabel.stringValue = session.title
        providerLabel.stringValue = session.command.displayName
        cwdLabel.stringValue = session.workingDirectory.path
        statusDot.layer?.backgroundColor = statusColor(for: session.status).cgColor
        pinIcon.isHidden = !session.isPinned

        if let snippet, !snippet.isEmpty {
            snippetLabel.stringValue = snippet
            snippetLabel.isHidden = false
        } else {
            snippetLabel.isHidden = true
        }
    }

    private func statusColor(for status: TerminalSessionStatus) -> NSColor {
        switch status {
        case .launching: return .systemYellow
        case .running: return .systemGreen
        case .waitingForInput: return .systemYellow
        case .completed: return .systemGray
        case .error: return .systemRed
        case .stopped: return .systemGray
        }
    }
}
