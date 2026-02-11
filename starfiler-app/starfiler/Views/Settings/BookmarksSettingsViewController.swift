import AppKit

final class BookmarksSettingsViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
    var onBookmarksChanged: (() -> Void)?

    private struct BookmarkRow {
        let groupName: String
        let displayName: String
        let path: String
        let shortcutKey: String?
        let groupShortcutKey: String?
    }

    private struct EditorResult {
        let groupName: String
        let groupShortcutKey: String?
        let displayName: String
        let path: String
        let shortcutKey: String?
    }

    private final class GroupSelectionHandler: NSObject {
        private let existingGroups: [BookmarkGroup]
        private let newGroupField: NSTextField
        private let groupShortcutField: NSTextField

        init(existingGroups: [BookmarkGroup], newGroupField: NSTextField, groupShortcutField: NSTextField) {
            self.existingGroups = existingGroups
            self.newGroupField = newGroupField
            self.groupShortcutField = groupShortcutField
            super.init()
        }

        @objc
        func selectionChanged(_ sender: NSPopUpButton) {
            let selectedIndex = sender.indexOfSelectedItem
            let isNewGroup = selectedIndex < 0 || selectedIndex >= existingGroups.count

            newGroupField.isEnabled = isNewGroup
            if isNewGroup {
                return
            }

            let group = existingGroups[selectedIndex]
            newGroupField.stringValue = ""
            groupShortcutField.stringValue = group.shortcutKey ?? ""
        }
    }

    private let configManager: ConfigManager

    private let descriptionLabel = NSTextField(
        wrappingLabelWithString: "Manage bookmark groups, paths, and bookmark jump shortcut keys."
    )
    private let scrollView = NSScrollView()
    private let tableView = NSTableView()

    private let addButton = NSButton(title: "Add", target: nil, action: nil)
    private let editButton = NSButton(title: "Edit", target: nil, action: nil)
    private let deleteButton = NSButton(title: "Delete", target: nil, action: nil)
    private let reloadButton = NSButton(title: "Reload", target: nil, action: nil)
    private let openConfigButton = NSButton(title: "Open Config File", target: nil, action: nil)

    private var bookmarksConfig = BookmarksConfig()
    private var rows: [BookmarkRow] = []

    init(configManager: ConfigManager = ConfigManager()) {
        self.configManager = configManager
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
        configureUI()
        configureLayout()
        reloadFromDisk()
    }

    private func configureUI() {
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        descriptionLabel.font = .systemFont(ofSize: 12)
        descriptionLabel.textColor = .secondaryLabelColor
        descriptionLabel.maximumNumberOfLines = 2
        descriptionLabel.lineBreakMode = .byWordWrapping

        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.rowHeight = 24
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.allowsColumnReordering = false
        tableView.target = self
        tableView.doubleAction = #selector(editBookmark(_:))

        let groupColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("group"))
        groupColumn.title = "Group"
        groupColumn.width = 120
        groupColumn.minWidth = 90

        let nameColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
        nameColumn.title = "Display Name"
        nameColumn.width = 150
        nameColumn.minWidth = 120

        let pathColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("path"))
        pathColumn.title = "Path"
        pathColumn.width = 320
        pathColumn.minWidth = 220

        let shortcutColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("shortcut"))
        shortcutColumn.title = "Shortcut"
        shortcutColumn.width = 110
        shortcutColumn.minWidth = 90

        tableView.addTableColumn(groupColumn)
        tableView.addTableColumn(nameColumn)
        tableView.addTableColumn(pathColumn)
        tableView.addTableColumn(shortcutColumn)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true

        addButton.translatesAutoresizingMaskIntoConstraints = false
        addButton.bezelStyle = .rounded
        addButton.target = self
        addButton.action = #selector(addBookmark(_:))

        editButton.translatesAutoresizingMaskIntoConstraints = false
        editButton.bezelStyle = .rounded
        editButton.target = self
        editButton.action = #selector(editBookmark(_:))

        deleteButton.translatesAutoresizingMaskIntoConstraints = false
        deleteButton.bezelStyle = .rounded
        deleteButton.target = self
        deleteButton.action = #selector(deleteBookmark(_:))

        reloadButton.translatesAutoresizingMaskIntoConstraints = false
        reloadButton.bezelStyle = .rounded
        reloadButton.target = self
        reloadButton.action = #selector(reloadBookmarks(_:))

        openConfigButton.translatesAutoresizingMaskIntoConstraints = false
        openConfigButton.bezelStyle = .rounded
        openConfigButton.target = self
        openConfigButton.action = #selector(openConfigFile(_:))
    }

    private func configureLayout() {
        view.addSubview(descriptionLabel)
        view.addSubview(scrollView)
        view.addSubview(addButton)
        view.addSubview(editButton)
        view.addSubview(deleteButton)
        view.addSubview(reloadButton)
        view.addSubview(openConfigButton)

        NSLayoutConstraint.activate([
            descriptionLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 12),
            descriptionLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            descriptionLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),

            scrollView.topAnchor.constraint(equalTo: descriptionLabel.bottomAnchor, constant: 8),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            scrollView.bottomAnchor.constraint(equalTo: addButton.topAnchor, constant: -8),

            addButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            addButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -12),

            editButton.leadingAnchor.constraint(equalTo: addButton.trailingAnchor, constant: 8),
            editButton.centerYAnchor.constraint(equalTo: addButton.centerYAnchor),

            deleteButton.leadingAnchor.constraint(equalTo: editButton.trailingAnchor, constant: 8),
            deleteButton.centerYAnchor.constraint(equalTo: addButton.centerYAnchor),

            openConfigButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            openConfigButton.centerYAnchor.constraint(equalTo: addButton.centerYAnchor),

            reloadButton.trailingAnchor.constraint(equalTo: openConfigButton.leadingAnchor, constant: -8),
            reloadButton.centerYAnchor.constraint(equalTo: addButton.centerYAnchor),
        ])
    }

    private func reloadFromDisk() {
        bookmarksConfig = configManager.loadBookmarksConfig()
        rows = flattenRows(from: bookmarksConfig)
        tableView.reloadData()
        updateButtonState()
    }

    private func flattenRows(from config: BookmarksConfig) -> [BookmarkRow] {
        var result: [BookmarkRow] = []
        for group in config.groups {
            for entry in group.entries {
                result.append(
                    BookmarkRow(
                        groupName: group.name,
                        displayName: entry.displayName,
                        path: entry.path,
                        shortcutKey: entry.shortcutKey,
                        groupShortcutKey: group.shortcutKey
                    )
                )
            }
        }
        return result
    }

    private func updateButtonState() {
        let hasSelection = selectedRow != nil
        editButton.isEnabled = hasSelection
        deleteButton.isEnabled = hasSelection
    }

    private var selectedRow: BookmarkRow? {
        let row = tableView.selectedRow
        guard row >= 0, rows.indices.contains(row) else {
            return nil
        }
        return rows[row]
    }

    @objc
    private func addBookmark(_ sender: Any?) {
        guard let result = presentEditor(initialRow: nil) else {
            return
        }
        upsertBookmark(with: result, replacing: nil)
    }

    @objc
    private func editBookmark(_ sender: Any?) {
        guard let selectedRow else {
            return
        }
        guard let result = presentEditor(initialRow: selectedRow) else {
            return
        }
        upsertBookmark(with: result, replacing: selectedRow)
    }

    @objc
    private func deleteBookmark(_ sender: Any?) {
        guard let selectedRow else {
            return
        }

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Delete Bookmark"
        alert.informativeText = "Delete \"\(selectedRow.displayName)\" from group \"\(selectedRow.groupName)\"?"
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else {
            return
        }

        var groups = bookmarksConfig.groups
        guard let groupIndex = groups.firstIndex(where: { $0.name == selectedRow.groupName }) else {
            return
        }

        groups[groupIndex].entries.removeAll { entry in
            entry.path == selectedRow.path && entry.displayName == selectedRow.displayName
        }

        if groups[groupIndex].entries.isEmpty, !groups[groupIndex].isDefault {
            groups.remove(at: groupIndex)
        }

        persist(BookmarksConfig(groups: normalizeGroups(groups)))
    }

    @objc
    private func reloadBookmarks(_ sender: Any?) {
        reloadFromDisk()
    }

    @objc
    private func openConfigFile(_ sender: Any?) {
        let url = configManager.bookmarksConfigURL

        if !FileManager.default.fileExists(atPath: url.path) {
            try? configManager.saveBookmarksConfig(bookmarksConfig)
        }

        NSWorkspace.shared.open(url)
    }

    private func presentEditor(initialRow: BookmarkRow?) -> EditorResult? {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = initialRow == nil ? "Add Bookmark" : "Edit Bookmark"
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")

        let existingGroups = bookmarksConfig.groups
        let groupNames = existingGroups.map(\.name)

        let container = NSView(frame: NSRect(x: 0, y: 0, width: 460, height: 230))

        let groupLabel = NSTextField(labelWithString: "Group")
        groupLabel.frame = NSRect(x: 0, y: 204, width: 210, height: 20)
        groupLabel.font = .systemFont(ofSize: 11)
        groupLabel.textColor = .secondaryLabelColor

        let groupPopup = NSPopUpButton(frame: NSRect(x: 0, y: 180, width: 260, height: 24), pullsDown: false)
        groupPopup.addItems(withTitles: groupNames)
        groupPopup.addItem(withTitle: "New Group")

        let groupShortcutLabel = NSTextField(labelWithString: "Group Shortcut (1 char, optional)")
        groupShortcutLabel.frame = NSRect(x: 270, y: 204, width: 190, height: 20)
        groupShortcutLabel.font = .systemFont(ofSize: 11)
        groupShortcutLabel.textColor = .secondaryLabelColor

        let groupShortcutField = NSTextField(frame: NSRect(x: 350, y: 180, width: 70, height: 24))
        groupShortcutField.alignment = .center
        groupShortcutField.placeholderString = "Key"

        let newGroupLabel = NSTextField(labelWithString: "New Group Name (when New Group is selected)")
        newGroupLabel.frame = NSRect(x: 0, y: 152, width: 300, height: 20)
        newGroupLabel.font = .systemFont(ofSize: 11)
        newGroupLabel.textColor = .secondaryLabelColor

        let newGroupField = NSTextField(frame: NSRect(x: 0, y: 128, width: 300, height: 24))
        newGroupField.placeholderString = "Group name"

        let displayNameLabel = NSTextField(labelWithString: "Display Name")
        displayNameLabel.frame = NSRect(x: 0, y: 100, width: 200, height: 20)
        displayNameLabel.font = .systemFont(ofSize: 11)
        displayNameLabel.textColor = .secondaryLabelColor

        let displayNameField = NSTextField(frame: NSRect(x: 0, y: 76, width: 210, height: 24))
        displayNameField.placeholderString = "Bookmark name"

        let entryShortcutLabel = NSTextField(labelWithString: "Entry Shortcut (1 char, optional)")
        entryShortcutLabel.frame = NSRect(x: 220, y: 100, width: 240, height: 20)
        entryShortcutLabel.font = .systemFont(ofSize: 11)
        entryShortcutLabel.textColor = .secondaryLabelColor

        let entryShortcutField = NSTextField(frame: NSRect(x: 220, y: 76, width: 70, height: 24))
        entryShortcutField.alignment = .center
        entryShortcutField.placeholderString = "Key"

        let pathLabel = NSTextField(labelWithString: "Path")
        pathLabel.frame = NSRect(x: 0, y: 48, width: 210, height: 20)
        pathLabel.font = .systemFont(ofSize: 11)
        pathLabel.textColor = .secondaryLabelColor

        let pathField = NSTextField(frame: NSRect(x: 0, y: 24, width: 460, height: 24))
        pathField.placeholderString = "/path/to/directory"

        container.addSubview(groupLabel)
        container.addSubview(groupPopup)
        container.addSubview(groupShortcutLabel)
        container.addSubview(groupShortcutField)
        container.addSubview(newGroupLabel)
        container.addSubview(newGroupField)
        container.addSubview(displayNameLabel)
        container.addSubview(displayNameField)
        container.addSubview(entryShortcutLabel)
        container.addSubview(entryShortcutField)
        container.addSubview(pathLabel)
        container.addSubview(pathField)
        alert.accessoryView = container

        if let initialRow {
            if let selectedIndex = groupNames.firstIndex(of: initialRow.groupName) {
                groupPopup.selectItem(at: selectedIndex)
            }
            groupShortcutField.stringValue = initialRow.groupShortcutKey ?? ""
            displayNameField.stringValue = initialRow.displayName
            pathField.stringValue = initialRow.path
            entryShortcutField.stringValue = initialRow.shortcutKey ?? ""
        } else if let firstGroup = existingGroups.first {
            groupPopup.selectItem(at: 0)
            groupShortcutField.stringValue = firstGroup.shortcutKey ?? ""
        } else {
            groupPopup.selectItem(at: 0)
            newGroupField.isEnabled = true
        }

        let selectionHandler = GroupSelectionHandler(
            existingGroups: existingGroups,
            newGroupField: newGroupField,
            groupShortcutField: groupShortcutField
        )
        groupPopup.target = selectionHandler
        groupPopup.action = #selector(GroupSelectionHandler.selectionChanged(_:))
        selectionHandler.selectionChanged(groupPopup)

        guard alert.runModal() == .alertFirstButtonReturn else {
            return nil
        }

        let selectedGroupIndex = groupPopup.indexOfSelectedItem
        let isNewGroup = selectedGroupIndex < 0 || selectedGroupIndex >= groupNames.count
        let groupName: String
        if isNewGroup {
            groupName = newGroupField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            groupName = groupNames[selectedGroupIndex].trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let displayName = displayNameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let path = pathField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !groupName.isEmpty, !displayName.isEmpty, !path.isEmpty else {
            let invalidAlert = NSAlert()
            invalidAlert.alertStyle = .warning
            invalidAlert.messageText = "Missing Required Fields"
            invalidAlert.informativeText = "Group, display name, and path are required."
            invalidAlert.addButton(withTitle: "OK")
            invalidAlert.runModal()
            return nil
        }

        return EditorResult(
            groupName: groupName,
            groupShortcutKey: normalizedShortcutKey(groupShortcutField.stringValue),
            displayName: displayName,
            path: path,
            shortcutKey: normalizedShortcutKey(entryShortcutField.stringValue)
        )
    }

    private func normalizedShortcutKey(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmed.first else {
            return nil
        }
        return String(first).lowercased()
    }

    private func upsertBookmark(with result: EditorResult, replacing existingRow: BookmarkRow?) {
        var groups = bookmarksConfig.groups

        if let existingRow, let existingGroupIndex = groups.firstIndex(where: { $0.name == existingRow.groupName }) {
            groups[existingGroupIndex].entries.removeAll { entry in
                entry.path == existingRow.path && entry.displayName == existingRow.displayName
            }

            if groups[existingGroupIndex].entries.isEmpty, !groups[existingGroupIndex].isDefault {
                groups.remove(at: existingGroupIndex)
            }
        }

        let newEntry = BookmarkEntry(
            displayName: result.displayName,
            path: result.path,
            shortcutKey: result.shortcutKey
        )

        if let targetGroupIndex = groups.firstIndex(where: { $0.name == result.groupName }) {
            groups[targetGroupIndex].shortcutKey = result.groupShortcutKey

            if let existingEntryIndex = groups[targetGroupIndex].entries.firstIndex(where: { $0.path == result.path }) {
                groups[targetGroupIndex].entries[existingEntryIndex] = newEntry
            } else {
                groups[targetGroupIndex].entries.append(newEntry)
            }
        } else {
            groups.append(
                BookmarkGroup(
                    name: result.groupName,
                    entries: [newEntry],
                    shortcutKey: result.groupShortcutKey,
                    isDefault: false
                )
            )
        }

        persist(BookmarksConfig(groups: normalizeGroups(groups)))
    }

    private func normalizeGroups(_ groups: [BookmarkGroup]) -> [BookmarkGroup] {
        var normalized = groups
            .map { group in
                var updated = group
                updated.entries.sort { lhs, rhs in
                    lhs.displayName.localizedStandardCompare(rhs.displayName) == .orderedAscending
                }
                return updated
            }
            .filter { $0.isDefault || !$0.entries.isEmpty }

        normalized.sort { lhs, rhs in
            if lhs.isDefault != rhs.isDefault {
                return lhs.isDefault
            }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }

        return normalized
    }

    private func persist(_ config: BookmarksConfig) {
        do {
            try configManager.saveBookmarksConfig(config)
            bookmarksConfig = config
            rows = flattenRows(from: config)
            tableView.reloadData()
            updateButtonState()
            onBookmarksChanged?()
        } catch {
            let alert = NSAlert()
            alert.alertStyle = .critical
            alert.messageText = "Failed to save bookmarks"
            alert.informativeText = error.localizedDescription
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        rows.count
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        updateButtonState()
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard rows.indices.contains(row) else {
            return nil
        }

        let item = rows[row]
        let columnID = tableColumn?.identifier.rawValue ?? ""
        let cellIdentifier = NSUserInterfaceItemIdentifier("bookmarkCell-\(columnID)")

        let cell: NSTableCellView
        if let existing = tableView.makeView(withIdentifier: cellIdentifier, owner: self) as? NSTableCellView {
            cell = existing
        } else {
            cell = NSTableCellView()
            cell.identifier = cellIdentifier

            let textField = NSTextField(labelWithString: "")
            textField.translatesAutoresizingMaskIntoConstraints = false
            textField.lineBreakMode = .byTruncatingMiddle
            cell.textField = textField
            cell.addSubview(textField)

            NSLayoutConstraint.activate([
                textField.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 4),
                textField.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -4),
                textField.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            ])
        }

        switch columnID {
        case "group":
            cell.textField?.stringValue = item.groupName
        case "name":
            cell.textField?.stringValue = item.displayName
        case "path":
            cell.textField?.stringValue = item.path
        case "shortcut":
            cell.textField?.stringValue = shortcutDescription(for: item)
        default:
            cell.textField?.stringValue = ""
        }

        return cell
    }

    private func shortcutDescription(for row: BookmarkRow) -> String {
        if let group = row.groupShortcutKey, let entry = row.shortcutKey {
            return "'\(group) \(entry)"
        }
        if let entry = row.shortcutKey {
            return "'\(entry)"
        }
        return "-"
    }
}
