import AppKit

final class KeybindingsViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
    var onKeybindingsChanged: (() -> Void)?

    private let scrollView = NSScrollView()
    private let tableView = NSTableView()
    private let segmentedControl = NSSegmentedControl()
    private let resetButton = NSButton(title: "Reset to Defaults", target: nil, action: nil)
    private let openConfigButton = NSButton(title: "Open Config File", target: nil, action: nil)

    private static let modes = ["normal", "visual", "filter", "menu"]

    private var currentMode: String = "normal"
    private var displayedBindings: [(sequence: String, action: String, isReadOnly: Bool)] = []
    private var allBindings: [String: [(sequence: String, action: String, isReadOnly: Bool)]] = [:]

    override func loadView() {
        view = NSView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        loadBindings()
        loadMenuBindings()
        configureUI()
        configureLayout()
        reloadTable()
    }

    private func loadBindings() {
        let defaultBindings = loadDefaultBindings()
        let userBindings = loadUserBindings()
        let merged = mergeBindings(defaultBindings: defaultBindings, userBindings: userBindings)

        for key in allBindings.keys where key != "menu" {
            allBindings.removeValue(forKey: key)
        }
        for (modeName, bindings) in merged {
            var entries: [(String, String, Bool)] = []
            for (sequence, action) in bindings.sorted(by: { $0.value < $1.value }) {
                entries.append((sequence, action, false))
            }
            allBindings[modeName] = entries
        }
    }

    private func loadMenuBindings() {
        let menuShortcuts: [(String, String)] = [
            ("\u{2318}N", "New Folder"),
            ("\u{2318}\u{21A9}", "Open"),
            ("\u{2318}Z", "Undo"),
            ("\u{2318}C", "Copy"),
            ("\u{2318}V", "Paste"),
            ("\u{232B}", "Move to Trash"),
            ("\u{2318}A", "Select All"),
            ("\u{2318}S", "Toggle Sidebar"),
            ("\u{2318}P", "Toggle Preview"),
            ("\u{2318}.", "Toggle Hidden Files"),
            ("\u{2318}R", "Refresh"),
            ("\u{2318}[", "Go Back"),
            ("\u{2318}]", "Go Forward"),
            ("Esc", "Enclosing Folder"),
            ("\u{2318}\u{21E7}H", "Home"),
            ("\u{2318}\u{21E7}D", "Desktop"),
            ("\u{2318}\u{21E7}O", "Documents"),
            ("\u{2318}\u{2325}L", "Downloads"),
            ("\u{2318}\u{21E7}A", "Applications"),
            ("\u{2318}W", "Close Window"),
            ("\u{2318}M", "Minimize"),
            ("Tab", "Switch Pane"),
            ("\u{2318},", "Settings"),
            ("\u{2318}Q", "Quit"),
        ]
        allBindings["menu"] = menuShortcuts.map { ($0.0, $0.1, true) }
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
        let modes = Self.modes
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
        tableView.doubleAction = #selector(handleDoubleClick(_:))
        tableView.target = self

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
        let modes = Self.modes
        let index = sender.selectedSegment
        guard modes.indices.contains(index) else {
            return
        }
        currentMode = modes[index]
        reloadTable()
    }

    @objc
    private func handleDoubleClick(_ sender: Any?) {
        let row = tableView.clickedRow
        guard row >= 0, displayedBindings.indices.contains(row) else {
            return
        }

        let binding = displayedBindings[row]
        if binding.isReadOnly {
            return
        }

        presentKeyRecorder(forRow: row)
    }

    private func presentKeyRecorder(forRow row: Int) {
        let binding = displayedBindings[row]

        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "Edit Keybinding"
        alert.informativeText = "Action: \(formatAction(binding.action))\nCurrent: \(formatSequence(binding.sequence))\n\nPress a new key combination:"
        alert.addButton(withTitle: "Cancel")

        let recorder = KeyRecorderView(frame: NSRect(x: 0, y: 0, width: 280, height: 60))

        var recordedNewSequence: String?
        recorder.onKeyRecorded = { sequence in
            recordedNewSequence = sequence
        }

        alert.accessoryView = recorder

        DispatchQueue.main.async {
            recorder.startRecording(currentBinding: self.formatSequence(binding.sequence))
        }

        let response = alert.runModal()

        if response == .alertFirstButtonReturn, let newSequence = recordedNewSequence {
            if let conflict = findConflict(sequence: newSequence, mode: currentMode, excludingRow: row) {
                let conflictAlert = NSAlert()
                conflictAlert.alertStyle = .warning
                conflictAlert.messageText = "Key Conflict"
                conflictAlert.informativeText = "\"\(formatSequence(newSequence))\" is already bound to \"\(formatAction(conflict))\" in \(currentMode) mode."
                conflictAlert.addButton(withTitle: "OK")
                conflictAlert.runModal()
                return
            }

            saveKeybinding(oldSequence: binding.sequence, newSequence: newSequence, action: binding.action, mode: currentMode)
            loadBindings()
            loadMenuBindings()
            reloadTable()
        }
    }

    private func findConflict(sequence: String, mode: String, excludingRow: Int) -> String? {
        guard let bindings = allBindings[mode] else { return nil }
        for (index, binding) in bindings.enumerated() where index != excludingRow {
            if binding.sequence == sequence {
                return binding.action
            }
        }
        return nil
    }

    private func saveKeybinding(oldSequence: String, newSequence: String, action: String, mode: String) {
        guard let url = KeybindingManager.defaultUserConfigURL() else { return }

        var userConfig: KeybindingsConfig
        if FileManager.default.fileExists(atPath: url.path),
           let data = try? Data(contentsOf: url),
           let existing = try? JSONDecoder().decode(KeybindingsConfig.self, from: data) {
            userConfig = existing
        } else {
            userConfig = KeybindingsConfig(bindings: [:])
        }

        var modeBindings = userConfig.bindings[mode] ?? [:]
        if oldSequence != newSequence {
            modeBindings.removeValue(forKey: oldSequence)
        }
        modeBindings[newSequence] = action
        userConfig.bindings[mode] = modeBindings

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(userConfig) {
            let parentDir = url.deletingLastPathComponent()
            try? FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)
            try? data.write(to: url, options: [.atomic])
            onKeybindingsChanged?()
        }
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
            onKeybindingsChanged?()
        }

        loadBindings()
        loadMenuBindings()
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

        let textColor: NSColor = binding.isReadOnly ? .tertiaryLabelColor : .labelColor

        switch identifier.rawValue {
        case "sequence":
            cell.textField?.stringValue = formatSequence(binding.sequence)
            cell.textField?.textColor = textColor
        case "action":
            cell.textField?.stringValue = formatAction(binding.action)
            cell.textField?.textColor = textColor
        default:
            cell.textField?.stringValue = ""
        }

        return cell
    }

    private func formatSequence(_ sequence: String) -> String {
        sequence
            .replacingOccurrences(of: "Ctrl-", with: "^")
            .replacingOccurrences(of: "Shift-", with: "\u{21E7}")
            .replacingOccurrences(of: "Alt-", with: "\u{2325}")
            .replacingOccurrences(of: "Cmd-", with: "\u{2318}")
    }

    private func formatAction(_ action: String) -> String {
        if action.contains(" ") { return action }
        let words = action.reduce(into: "") { result, char in
            if char.isUppercase && !result.isEmpty {
                result.append(" ")
            }
            result.append(char)
        }
        return words.prefix(1).uppercased() + words.dropFirst()
    }
}
