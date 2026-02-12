import AppKit

final class TerminalSessionListView: NSView {
    private let scrollView = NSScrollView()
    private let tableView = NSTableView()
    private let headerView = NSView()
    private let addButton = NSButton()

    private var sessions: [TerminalSession] = []
    private var activeSessionId: UUID?
    private var isUpdatingSelection = false

    var onSessionSelected: ((UUID) -> Void)?
    var onSessionCloseRequested: ((UUID) -> Void)?
    var onAddClaudeSession: (() -> Void)?
    var onAddCodexSession: (() -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        wantsLayer = true

        headerView.translatesAutoresizingMaskIntoConstraints = false

        let headerLabel = NSTextField(labelWithString: "Sessions")
        headerLabel.translatesAutoresizingMaskIntoConstraints = false
        headerLabel.font = .systemFont(ofSize: 11, weight: .semibold)
        headerLabel.textColor = .secondaryLabelColor
        headerView.addSubview(headerLabel)

        addButton.translatesAutoresizingMaskIntoConstraints = false
        addButton.bezelStyle = .inline
        addButton.image = NSImage(systemSymbolName: "plus", accessibilityDescription: "New Session")
        addButton.imageScaling = .scaleProportionallyDown
        addButton.isBordered = false
        addButton.target = self
        addButton.action = #selector(addButtonClicked)
        headerView.addSubview(addButton)

        NSLayoutConstraint.activate([
            headerLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 8),
            headerLabel.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),

            addButton.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -4),
            addButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            addButton.widthAnchor.constraint(equalToConstant: 20),
            addButton.heightAnchor.constraint(equalToConstant: 20),
        ])

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("SessionColumn"))
        column.title = ""
        tableView.addTableColumn(column)
        tableView.headerView = nil
        tableView.rowHeight = 28
        tableView.delegate = self
        tableView.dataSource = self
        tableView.selectionHighlightStyle = .regular
        tableView.style = .plain

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder

        addSubview(headerView)
        addSubview(scrollView)

        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: topAnchor),
            headerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            headerView.heightAnchor.constraint(equalToConstant: 28),

            scrollView.topAnchor.constraint(equalTo: headerView.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    func update(sessions: [TerminalSession], activeSessionId: UUID?) {
        self.sessions = sessions
        self.activeSessionId = activeSessionId
        tableView.reloadData()

        isUpdatingSelection = true
        if let activeId = activeSessionId,
           let index = sessions.firstIndex(where: { $0.id == activeId }) {
            tableView.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
        }
        isUpdatingSelection = false
    }

    func applyTheme(_ palette: FilerThemePalette) {
        layer?.backgroundColor = palette.sidebarBackgroundColor.cgColor
    }

    @objc private func addButtonClicked() {
        let menu = NSMenu()
        let claudeItem = NSMenuItem(title: "Claude Code", action: #selector(addClaude), keyEquivalent: "")
        claudeItem.target = self
        let codexItem = NSMenuItem(title: "Codex CLI", action: #selector(addCodex), keyEquivalent: "")
        codexItem.target = self
        menu.addItem(claudeItem)
        menu.addItem(codexItem)

        let point = NSPoint(x: addButton.bounds.minX, y: addButton.bounds.minY)
        menu.popUp(positioning: nil, at: point, in: addButton)
    }

    @objc private func addClaude() {
        onAddClaudeSession?()
    }

    @objc private func addCodex() {
        onAddCodexSession?()
    }
}

extension TerminalSessionListView: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        sessions.count
    }
}

extension TerminalSessionListView: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < sessions.count else { return nil }

        let session = sessions[row]
        let cellId = TerminalSessionCellView.identifier
        let cell: TerminalSessionCellView

        if let reused = tableView.makeView(withIdentifier: cellId, owner: nil) as? TerminalSessionCellView {
            cell = reused
        } else {
            cell = TerminalSessionCellView(frame: .zero)
            cell.identifier = cellId
        }

        cell.configure(with: session, isActive: session.id == activeSessionId)
        cell.onCloseClicked = { [weak self] in
            self?.onSessionCloseRequested?(session.id)
        }
        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        guard !isUpdatingSelection else { return }
        let row = tableView.selectedRow
        guard row >= 0, row < sessions.count else { return }
        onSessionSelected?(sessions[row].id)
    }
}
