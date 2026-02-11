import AppKit

final class SyncViewController: NSViewController {
    private let viewModel: SyncViewModel

    // Path display
    private let leftPathLabel = NSTextField(labelWithString: "")
    private let rightPathLabel = NSTextField(labelWithString: "")

    // Direction selector
    private let directionControl = NSSegmentedControl()

    // Action buttons
    private let compareButton = NSButton()
    private let syncButton = NSButton()
    private let cancelButton = NSButton()

    // Filters
    private let showIdenticalCheck = NSButton(checkboxWithTitle: "Identical", target: nil, action: nil)
    private let showExcludedCheck = NSButton(checkboxWithTitle: "Excluded", target: nil, action: nil)

    // Progress
    private let progressLabel = NSTextField(labelWithString: "")
    private let progressIndicator = NSProgressIndicator()

    // Diff table
    private let tableView = NSTableView()

    // Bottom bar
    private let statusLabel = NSTextField(labelWithString: "")
    private let syncletLoadButton = NSButton()
    private let syncletSaveButton = NSButton()
    private let excludeRulesButton = NSButton()

    // Timer for refreshing from ViewModel
    private var refreshTimer: Timer?

    init(viewModel: SyncViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupLayout()
        refreshUI()
        startRefreshTimer()
    }

    override func viewWillDisappear() {
        super.viewWillDisappear()
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    // MARK: - Setup

    private func setupUI() {
        // Path labels
        leftPathLabel.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        leftPathLabel.lineBreakMode = .byTruncatingMiddle
        leftPathLabel.translatesAutoresizingMaskIntoConstraints = false

        rightPathLabel.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        rightPathLabel.lineBreakMode = .byTruncatingMiddle
        rightPathLabel.translatesAutoresizingMaskIntoConstraints = false

        // Direction
        directionControl.segmentCount = 3
        directionControl.setLabel("L \u{2192} R", forSegment: 0)
        directionControl.setLabel("L \u{2190} R", forSegment: 1)
        directionControl.setLabel("\u{2194} Both", forSegment: 2)
        directionControl.selectedSegment = 0
        directionControl.target = self
        directionControl.action = #selector(directionChanged)
        directionControl.translatesAutoresizingMaskIntoConstraints = false

        // Buttons
        compareButton.title = "Compare"
        compareButton.bezelStyle = .rounded
        compareButton.target = self
        compareButton.action = #selector(compareTapped)
        compareButton.translatesAutoresizingMaskIntoConstraints = false

        syncButton.title = "Sync"
        syncButton.bezelStyle = .rounded
        syncButton.target = self
        syncButton.action = #selector(syncTapped)
        syncButton.keyEquivalent = "\r"
        syncButton.translatesAutoresizingMaskIntoConstraints = false

        cancelButton.title = "Cancel"
        cancelButton.bezelStyle = .rounded
        cancelButton.target = self
        cancelButton.action = #selector(cancelTapped)
        cancelButton.keyEquivalent = "\u{1B}"
        cancelButton.translatesAutoresizingMaskIntoConstraints = false

        // Filters
        showIdenticalCheck.target = self
        showIdenticalCheck.action = #selector(filterChanged)
        showIdenticalCheck.state = .off
        showIdenticalCheck.translatesAutoresizingMaskIntoConstraints = false

        showExcludedCheck.target = self
        showExcludedCheck.action = #selector(filterChanged)
        showExcludedCheck.state = .off
        showExcludedCheck.translatesAutoresizingMaskIntoConstraints = false

        // Progress
        progressLabel.font = .systemFont(ofSize: 11)
        progressLabel.textColor = .secondaryLabelColor
        progressLabel.translatesAutoresizingMaskIntoConstraints = false

        progressIndicator.style = .bar
        progressIndicator.isIndeterminate = true
        progressIndicator.isHidden = true
        progressIndicator.translatesAutoresizingMaskIntoConstraints = false

        // Table
        setupTableColumns()
        tableView.dataSource = self
        tableView.delegate = self
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.allowsMultipleSelection = false
        tableView.headerView = NSTableHeaderView()
        tableView.translatesAutoresizingMaskIntoConstraints = false

        // Status bar
        statusLabel.font = .systemFont(ofSize: 12)
        statusLabel.translatesAutoresizingMaskIntoConstraints = false

        syncletLoadButton.title = "Load Synclet"
        syncletLoadButton.bezelStyle = .rounded
        syncletLoadButton.target = self
        syncletLoadButton.action = #selector(loadSyncletTapped)
        syncletLoadButton.translatesAutoresizingMaskIntoConstraints = false

        syncletSaveButton.title = "Save Synclet"
        syncletSaveButton.bezelStyle = .rounded
        syncletSaveButton.target = self
        syncletSaveButton.action = #selector(saveSyncletTapped)
        syncletSaveButton.translatesAutoresizingMaskIntoConstraints = false

        excludeRulesButton.title = "Exclude Rules..."
        excludeRulesButton.bezelStyle = .rounded
        excludeRulesButton.target = self
        excludeRulesButton.action = #selector(excludeRulesTapped)
        excludeRulesButton.translatesAutoresizingMaskIntoConstraints = false
    }

    private func setupTableColumns() {
        let columns: [(id: String, title: String, width: CGFloat, minWidth: CGFloat)] = [
            ("selected", "\u{2713}", 30, 30),
            ("action", "Action", 40, 40),
            ("status", "Status", 50, 40),
            ("relativePath", "Relative Path", 300, 150),
            ("leftSize", "Left Size", 80, 60),
            ("rightSize", "Right Size", 80, 60),
        ]

        for col in columns {
            let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(col.id))
            column.title = col.title
            column.width = col.width
            column.minWidth = col.minWidth
            if col.id == "selected" || col.id == "action" || col.id == "status" {
                column.maxWidth = col.width + 10
            }
            tableView.addTableColumn(column)
        }
    }

    private func setupLayout() {
        let pathBar = NSStackView(views: [
            makeLabel("Left:"), leftPathLabel, makeLabel("Right:"), rightPathLabel
        ])
        pathBar.orientation = .horizontal
        pathBar.spacing = 6
        pathBar.translatesAutoresizingMaskIntoConstraints = false

        let controlBar = NSStackView(views: [
            makeLabel("Direction:"), directionControl,
            NSView(), // spacer
            compareButton, syncButton, cancelButton
        ])
        controlBar.orientation = .horizontal
        controlBar.spacing = 8
        controlBar.translatesAutoresizingMaskIntoConstraints = false

        let filterBar = NSStackView(views: [
            makeLabel("Show:"), showIdenticalCheck, showExcludedCheck,
            NSView(), // spacer
            excludeRulesButton
        ])
        filterBar.orientation = .horizontal
        filterBar.spacing = 8
        filterBar.translatesAutoresizingMaskIntoConstraints = false

        let progressBar = NSStackView(views: [progressLabel, progressIndicator])
        progressBar.orientation = .horizontal
        progressBar.spacing = 8
        progressBar.translatesAutoresizingMaskIntoConstraints = false

        let scrollView = NSScrollView()
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        let bottomBar = NSStackView(views: [
            statusLabel, NSView(), syncletLoadButton, syncletSaveButton
        ])
        bottomBar.orientation = .horizontal
        bottomBar.spacing = 8
        bottomBar.translatesAutoresizingMaskIntoConstraints = false

        for subview in [pathBar, controlBar, filterBar, progressBar, scrollView, bottomBar] {
            view.addSubview(subview)
        }

        NSLayoutConstraint.activate([
            pathBar.topAnchor.constraint(equalTo: view.topAnchor, constant: 12),
            pathBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            pathBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),

            controlBar.topAnchor.constraint(equalTo: pathBar.bottomAnchor, constant: 8),
            controlBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            controlBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),

            filterBar.topAnchor.constraint(equalTo: controlBar.bottomAnchor, constant: 8),
            filterBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            filterBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),

            progressBar.topAnchor.constraint(equalTo: filterBar.bottomAnchor, constant: 4),
            progressBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            progressBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),

            scrollView.topAnchor.constraint(equalTo: progressBar.bottomAnchor, constant: 4),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),

            bottomBar.topAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: 8),
            bottomBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            bottomBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            bottomBar.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -12),
        ])
    }

    private func makeLabel(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.setContentHuggingPriority(.required, for: .horizontal)
        return label
    }

    // MARK: - Refresh

    private func startRefreshTimer() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            self?.refreshUI()
        }
    }

    private func refreshUI() {
        leftPathLabel.stringValue = viewModel.leftDirectory.path
        rightPathLabel.stringValue = viewModel.rightDirectory.path

        switch viewModel.phase {
        case .idle:
            progressLabel.stringValue = "Press Compare to start."
            progressIndicator.isHidden = true
            progressIndicator.stopAnimation(nil)
        case .comparing:
            progressLabel.stringValue = "Comparing... \(viewModel.scanProgress) files scanned"
            progressIndicator.isHidden = false
            progressIndicator.isIndeterminate = true
            progressIndicator.startAnimation(nil)
        case .previewReady:
            progressLabel.stringValue = "\(viewModel.items.count) items found"
            progressIndicator.isHidden = true
            progressIndicator.stopAnimation(nil)
        case .syncing:
            progressLabel.stringValue = "Syncing \(viewModel.syncProgress)/\(viewModel.syncTotal): \(viewModel.currentSyncFile)"
            progressIndicator.isHidden = false
            progressIndicator.isIndeterminate = false
            progressIndicator.maxValue = Double(viewModel.syncTotal)
            progressIndicator.doubleValue = Double(viewModel.syncProgress)
        case .completed:
            progressLabel.stringValue = "Sync complete."
            progressIndicator.isHidden = true
            progressIndicator.stopAnimation(nil)
        case .error(let msg):
            progressLabel.stringValue = "Error: \(msg)"
            progressIndicator.isHidden = true
            progressIndicator.stopAnimation(nil)
        }

        compareButton.isEnabled = !viewModel.isBusy
        syncButton.isEnabled = viewModel.canSync
        cancelButton.isEnabled = viewModel.isBusy

        statusLabel.stringValue = viewModel.statusSummary

        tableView.reloadData()
    }

    // MARK: - Actions

    @objc private func directionChanged() {
        let directions: [SyncDirection] = [.leftToRight, .rightToLeft, .bidirectional]
        let index = directionControl.selectedSegment
        guard directions.indices.contains(index) else { return }
        viewModel.direction = directions[index]
        refreshUI()
    }

    @objc private func compareTapped() {
        viewModel.compare()
    }

    @objc private func syncTapped() {
        viewModel.executeSync()
    }

    @objc private func cancelTapped() {
        viewModel.cancel()
    }

    @objc private func filterChanged() {
        viewModel.showIdentical = showIdenticalCheck.state == .on
        viewModel.showExcluded = showExcludedCheck.state == .on
        tableView.reloadData()
    }

    @objc private func excludeRulesTapped() {
        presentExcludeRulesSheet()
    }

    @objc private func loadSyncletTapped() {
        guard !viewModel.synclets.isEmpty else {
            let alert = NSAlert()
            alert.messageText = "No Synclets"
            alert.informativeText = "Save a synclet first."
            alert.addButton(withTitle: "OK")
            alert.runModal()
            return
        }

        let alert = NSAlert()
        alert.messageText = "Load Synclet"
        alert.addButton(withTitle: "Load")
        alert.addButton(withTitle: "Cancel")

        let popup = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 300, height: 26), pullsDown: false)
        for synclet in viewModel.synclets {
            popup.addItem(withTitle: synclet.name)
        }
        alert.accessoryView = popup

        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let index = popup.indexOfSelectedItem
        guard viewModel.synclets.indices.contains(index) else { return }
        viewModel.loadSynclet(viewModel.synclets[index])
        refreshUI()
    }

    @objc private func saveSyncletTapped() {
        let alert = NSAlert()
        alert.messageText = "Save Synclet"
        alert.informativeText = "Enter a name for this sync configuration."
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")

        let field = NSTextField(string: "")
        field.frame = NSRect(x: 0, y: 0, width: 300, height: 24)
        field.placeholderString = "Synclet name"
        alert.accessoryView = field

        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let name = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }

        viewModel.saveSynclet(name: name)
    }

    private func presentExcludeRulesSheet() {
        let alert = NSAlert()
        alert.messageText = "Exclude Rules"
        alert.informativeText = "Glob patterns to exclude (one per line):"
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")

        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 300, height: 120))
        textView.isEditable = true
        textView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.string = viewModel.excludeRules
            .map { ($0.isEnabled ? "" : "# ") + $0.pattern }
            .joined(separator: "\n")

        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 300, height: 120))
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder
        alert.accessoryView = scrollView

        guard alert.runModal() == .alertFirstButtonReturn else { return }

        let lines = textView.string.split(separator: "\n", omittingEmptySubsequences: true)
        var newRules: [SyncExcludeRule] = []
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("# ") {
                let pattern = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                if !pattern.isEmpty {
                    newRules.append(SyncExcludeRule(pattern: pattern, isEnabled: false))
                }
            } else if !trimmed.isEmpty {
                newRules.append(SyncExcludeRule(pattern: trimmed))
            }
        }
        viewModel.excludeRules = newRules
        if case .previewReady = viewModel.phase { viewModel.compare() }
    }

    // MARK: - Helpers

    private func formatSize(_ bytes: Int64?) -> String {
        guard let bytes else { return "--" }
        if bytes < 1024 { return "\(bytes) B" }
        if bytes < 1024 * 1024 { return String(format: "%.1f KB", Double(bytes) / 1024) }
        return String(format: "%.1f MB", Double(bytes) / (1024 * 1024))
    }
}

// MARK: - NSTableViewDataSource & NSTableViewDelegate

extension SyncViewController: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int {
        viewModel.filteredItems.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let identifier = tableColumn?.identifier ?? NSUserInterfaceItemIdentifier("cell")
        let items = viewModel.filteredItems
        guard row < items.count else { return nil }
        let item = items[row]

        switch identifier.rawValue {
        case "selected":
            let check = NSButton(checkboxWithTitle: "", target: self, action: #selector(checkboxToggled(_:)))
            check.state = item.isSelected ? .on : .off
            check.tag = row
            return check

        case "action":
            let cellView = reusableTextCell(tableView: tableView, identifier: identifier)
            cellView.textField?.stringValue = item.action.displayArrow
            cellView.textField?.alignment = .center
            return cellView

        case "status":
            let cellView = reusableTextCell(tableView: tableView, identifier: identifier)
            cellView.textField?.stringValue = item.status.displaySymbol
            cellView.textField?.alignment = .center
            switch item.status {
            case .identical: cellView.textField?.textColor = .systemGreen
            case .leftOnly, .rightOnly: cellView.textField?.textColor = .systemBlue
            case .leftNewer, .rightNewer: cellView.textField?.textColor = .systemOrange
            case .conflict: cellView.textField?.textColor = .systemRed
            case .excluded: cellView.textField?.textColor = .secondaryLabelColor
            }
            return cellView

        case "relativePath":
            let cellView = reusableTextCell(tableView: tableView, identifier: identifier)
            let prefix = item.isDirectory ? "\u{1F4C1} " : ""
            cellView.textField?.stringValue = prefix + item.relativePath
            cellView.textField?.textColor = .labelColor
            return cellView

        case "leftSize":
            let cellView = reusableTextCell(tableView: tableView, identifier: identifier)
            cellView.textField?.stringValue = formatSize(item.leftSize)
            cellView.textField?.alignment = .right
            cellView.textField?.textColor = .secondaryLabelColor
            return cellView

        case "rightSize":
            let cellView = reusableTextCell(tableView: tableView, identifier: identifier)
            cellView.textField?.stringValue = formatSize(item.rightSize)
            cellView.textField?.alignment = .right
            cellView.textField?.textColor = .secondaryLabelColor
            return cellView

        default:
            return nil
        }
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        22
    }

    @objc private func checkboxToggled(_ sender: NSButton) {
        let filteredItems = viewModel.filteredItems
        let row = sender.tag
        guard row < filteredItems.count else { return }
        let filteredItem = filteredItems[row]
        if let realIndex = viewModel.items.firstIndex(where: { $0.id == filteredItem.id }) {
            viewModel.toggleItemSelection(at: realIndex)
        }
    }

    private func reusableTextCell(tableView: NSTableView, identifier: NSUserInterfaceItemIdentifier) -> NSTableCellView {
        if let existing = tableView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView {
            return existing
        }
        let cellView = NSTableCellView()
        cellView.identifier = identifier
        let textField = NSTextField(labelWithString: "")
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.lineBreakMode = .byTruncatingTail
        textField.font = .systemFont(ofSize: 12)
        cellView.addSubview(textField)
        cellView.textField = textField
        NSLayoutConstraint.activate([
            textField.leadingAnchor.constraint(equalTo: cellView.leadingAnchor, constant: 2),
            textField.trailingAnchor.constraint(equalTo: cellView.trailingAnchor, constant: -2),
            textField.centerYAnchor.constraint(equalTo: cellView.centerYAnchor),
        ])
        return cellView
    }
}
