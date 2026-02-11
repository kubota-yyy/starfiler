import AppKit

final class KeybindingsViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
    private let scrollView = NSScrollView()
    private let tableView = NSTableView()
    private let segmentedControl = NSSegmentedControl()
    private let resetButton = NSButton(title: "Reset to Defaults", target: nil, action: nil)
    private let openConfigButton = NSButton(title: "Open Config File", target: nil, action: nil)

    private var currentMode: String = "normal"
    private var displayedBindings: [(sequence: String, action: String)] = []
    private var allBindings: [String: [(sequence: String, action: String)]] = [:]

    override func loadView() {
        view = NSView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        loadBindings()
        configureUI()
        configureLayout()
        reloadTable()
    }

    private func loadBindings() {
        let defaultBindings = loadDefaultBindings()
        let userBindings = loadUserBindings()
        let merged = mergeBindings(defaultBindings: defaultBindings, userBindings: userBindings)

        allBindings = [:]
        for (modeName, bindings) in merged {
            var entries: [(String, String)] = []
            for (sequence, action) in bindings.sorted(by: { $0.value < $1.value }) {
                entries.append((sequence, action))
            }
            allBindings[modeName] = entries
        }
    }

    private func loadDefaultBindings() -> [String: [String: String]] {
        guard let url = Bundle.main.url(forResource: "DefaultKeybindings", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let config = try? JSONDecoder().decode(KeybindingsConfig.self, from: data) else {
            return [:]
        }
        return config.bindings
    }

    private func loadUserBindings() -> [String: [String: String]] {
        guard let url = KeybindingManager.defaultUserConfigURL(),
              FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let config = try? JSONDecoder().decode(KeybindingsConfig.self, from: data) else {
            return [:]
        }
        return config.bindings
    }

    private func mergeBindings(
        defaultBindings: [String: [String: String]],
        userBindings: [String: [String: String]]
    ) -> [String: [String: String]] {
        var merged = defaultBindings
        for (modeName, modeBindings) in userBindings {
            var existing = merged[modeName] ?? [:]
            for (sequence, action) in modeBindings {
                existing[sequence] = action
            }
            merged[modeName] = existing
        }
        return merged
    }

    private func configureUI() {
        let modes = ["normal", "visual", "filter"]
        segmentedControl.segmentCount = modes.count
        for (index, mode) in modes.enumerated() {
            segmentedControl.setLabel(mode.capitalized, forSegment: index)
        }
        segmentedControl.selectedSegment = 0
        segmentedControl.translatesAutoresizingMaskIntoConstraints = false
        segmentedControl.target = self
        segmentedControl.action = #selector(modeChanged(_:))

        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.rowHeight = 24
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.allowsColumnReordering = false

        let sequenceColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("sequence"))
        sequenceColumn.title = "Key Sequence"
        sequenceColumn.width = 200
        sequenceColumn.minWidth = 120

        let actionColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("action"))
        actionColumn.title = "Action"
        actionColumn.width = 300
        actionColumn.minWidth = 150

        tableView.addTableColumn(sequenceColumn)
        tableView.addTableColumn(actionColumn)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true

        resetButton.translatesAutoresizingMaskIntoConstraints = false
        resetButton.bezelStyle = .rounded
        resetButton.target = self
        resetButton.action = #selector(resetToDefaults(_:))

        openConfigButton.translatesAutoresizingMaskIntoConstraints = false
        openConfigButton.bezelStyle = .rounded
        openConfigButton.target = self
        openConfigButton.action = #selector(openConfigFile(_:))
    }

    private func configureLayout() {
        view.addSubview(segmentedControl)
        view.addSubview(scrollView)
        view.addSubview(resetButton)
        view.addSubview(openConfigButton)

        NSLayoutConstraint.activate([
            segmentedControl.topAnchor.constraint(equalTo: view.topAnchor, constant: 12),
            segmentedControl.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            scrollView.topAnchor.constraint(equalTo: segmentedControl.bottomAnchor, constant: 8),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            scrollView.bottomAnchor.constraint(equalTo: resetButton.topAnchor, constant: -8),

            resetButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            resetButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -12),

            openConfigButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            openConfigButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -12),
        ])
    }

    private func reloadTable() {
        displayedBindings = allBindings[currentMode] ?? []
        tableView.reloadData()
    }

    @objc
    private func modeChanged(_ sender: NSSegmentedControl) {
        let modes = ["normal", "visual", "filter"]
        let index = sender.selectedSegment
        guard modes.indices.contains(index) else {
            return
        }
        currentMode = modes[index]
        reloadTable()
    }

    @objc
    private func resetToDefaults(_ sender: Any?) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Reset Keybindings"
        alert.informativeText = "This will delete your custom keybindings and restore the defaults. Continue?"
        alert.addButton(withTitle: "Reset")
        alert.addButton(withTitle: "Cancel")

        guard alert.runModal() == .alertFirstButtonReturn else {
            return
        }

        if let url = KeybindingManager.defaultUserConfigURL(),
           FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.removeItem(at: url)
        }

        loadBindings()
        reloadTable()
    }

    @objc
    private func openConfigFile(_ sender: Any?) {
        guard let url = KeybindingManager.defaultUserConfigURL() else {
            return
        }

        if !FileManager.default.fileExists(atPath: url.path) {
            let defaultBindings = loadDefaultBindings()
            let config = KeybindingsConfig(bindings: defaultBindings)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            if let data = try? encoder.encode(config) {
                let parentDir = url.deletingLastPathComponent()
                try? FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)
                try? data.write(to: url, options: [.atomic])
            }
        }

        NSWorkspace.shared.open(url)
    }

    // MARK: - NSTableViewDataSource

    func numberOfRows(in tableView: NSTableView) -> Int {
        displayedBindings.count
    }

    // MARK: - NSTableViewDelegate

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard displayedBindings.indices.contains(row) else {
            return nil
        }

        let binding = displayedBindings[row]
        let identifier = tableColumn?.identifier ?? NSUserInterfaceItemIdentifier("")

        let cellIdentifier = NSUserInterfaceItemIdentifier("keybindCell")
        let cell: NSTableCellView

        if let existing = tableView.makeView(withIdentifier: cellIdentifier, owner: self) as? NSTableCellView {
            cell = existing
        } else {
            cell = NSTableCellView()
            cell.identifier = cellIdentifier

            let textField = NSTextField(labelWithString: "")
            textField.translatesAutoresizingMaskIntoConstraints = false
            textField.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
            cell.textField = textField
            cell.addSubview(textField)

            NSLayoutConstraint.activate([
                textField.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 4),
                textField.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -4),
                textField.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            ])
        }

        switch identifier.rawValue {
        case "sequence":
            cell.textField?.stringValue = formatSequence(binding.sequence)
        case "action":
            cell.textField?.stringValue = formatAction(binding.action)
        default:
            cell.textField?.stringValue = ""
        }

        return cell
    }

    private func formatSequence(_ sequence: String) -> String {
        sequence
            .replacingOccurrences(of: "Ctrl-", with: "^")
            .replacingOccurrences(of: "Shift-", with: "⇧")
            .replacingOccurrences(of: "Alt-", with: "⌥")
            .replacingOccurrences(of: "Cmd-", with: "⌘")
    }

    private func formatAction(_ action: String) -> String {
        let words = action.reduce(into: "") { result, char in
            if char.isUppercase && !result.isEmpty {
                result.append(" ")
            }
            result.append(char)
        }
        return words.prefix(1).uppercased() + words.dropFirst()
    }
}
