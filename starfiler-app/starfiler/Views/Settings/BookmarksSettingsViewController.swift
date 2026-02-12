import AppKit

final class BookmarksSettingsViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
    var onBookmarksChanged: (() -> Void)?

    private struct BookmarkRow {
        let groupName: String
        let isDefaultGroup: Bool
        let displayName: String
        let path: String
        let shortcutKey: String?
        let groupShortcutKey: String?
    }

    private struct EditorResult {
        let groupName: String
        let displayName: String
        let path: String
        let shortcutKey: String?
    }

    private struct GroupEditorResult {
        let name: String
        let shortcutKey: String?
    }

    private let configManager: ConfigManager

    private let descriptionLabel = NSTextField(
        wrappingLabelWithString:
            "Configure group shortcut keys and folder shortcut keys separately. " +
            "Set group keys with the group actions, then assign each folder to a group."
    )
    private let groupActionsStack = NSStackView()
    private let addGroupButton = NSButton(title: "Add Group", target: nil, action: nil)
    private let editGroupButton = NSButton(title: "Edit Group", target: nil, action: nil)
    private let deleteGroupButton = NSButton(title: "Delete Group", target: nil, action: nil)

    private let scrollView = NSScrollView()
    private let tableView = NSTableView()

    private let addButton = NSButton(title: "Add Folder", target: nil, action: nil)
    private let editButton = NSButton(title: "Edit Folder", target: nil, action: nil)
    private let deleteButton = NSButton(title: "Delete Folder", target: nil, action: nil)
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
        descriptionLabel.maximumNumberOfLines = 3
        descriptionLabel.lineBreakMode = .byWordWrapping

        groupActionsStack.translatesAutoresizingMaskIntoConstraints = false
        groupActionsStack.orientation = .horizontal
        groupActionsStack.spacing = 8
        groupActionsStack.alignment = .centerY

        addGroupButton.translatesAutoresizingMaskIntoConstraints = false
        addGroupButton.bezelStyle = .rounded
        addGroupButton.target = self
        addGroupButton.action = #selector(addGroup(_:))

        editGroupButton.translatesAutoresizingMaskIntoConstraints = false
        editGroupButton.bezelStyle = .rounded
        editGroupButton.target = self
        editGroupButton.action = #selector(editGroup(_:))

        deleteGroupButton.translatesAutoresizingMaskIntoConstraints = false
        deleteGroupButton.bezelStyle = .rounded
        deleteGroupButton.target = self
        deleteGroupButton.action = #selector(deleteGroup(_:))

        groupActionsStack.addArrangedSubview(addGroupButton)
        groupActionsStack.addArrangedSubview(editGroupButton)
        groupActionsStack.addArrangedSubview(deleteGroupButton)

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
        groupColumn.width = 140
        groupColumn.minWidth = 100

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
        shortcutColumn.width = 120
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
        view.addSubview(groupActionsStack)
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

            groupActionsStack.topAnchor.constraint(equalTo: descriptionLabel.bottomAnchor, constant: 8),
            groupActionsStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            groupActionsStack.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -12),

            scrollView.topAnchor.constraint(equalTo: groupActionsStack.bottomAnchor, constant: 8),
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
                        isDefaultGroup: group.isDefault,
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
        addButton.isEnabled = !bookmarksConfig.groups.isEmpty

        let hasGroups = !bookmarksConfig.groups.isEmpty
        editGroupButton.isEnabled = hasGroups
        deleteGroupButton.isEnabled = bookmarksConfig.groups.contains { !$0.isDefault }
    }

    private var selectedRow: BookmarkRow? {
        let row = tableView.selectedRow
        guard row >= 0, rows.indices.contains(row) else {
            return nil
        }
        return rows[row]
    }

    @objc
    private func addGroup(_ sender: Any?) {
        guard let result = presentGroupEditor(initialGroup: nil) else {
            return
        }

        var groups = bookmarksConfig.groups
        guard !hasGroup(named: result.name, in: groups) else {
            presentWarning(
                title: "Duplicate Group Name",
                informativeText: "A group named \"\(result.name)\" already exists."
            )
            return
        }

        groups.append(
            BookmarkGroup(
                name: result.name,
                entries: [],
                shortcutKey: result.shortcutKey,
                isDefault: false
            )
        )
        persist(BookmarksConfig(groups: normalizeGroups(groups)))
    }

    @objc
    private func editGroup(_ sender: Any?) {
        guard let groupIndex = selectGroupIndex(
            title: "Edit Group",
            informativeText: "Choose a group to edit.",
            allowDefault: true,
            preferredGroupName: selectedRow?.groupName
        ) else {
            return
        }

        var groups = bookmarksConfig.groups
        let existingGroup = groups[groupIndex]

        guard let result = presentGroupEditor(initialGroup: existingGroup) else {
            return
        }

        guard !hasGroup(named: result.name, in: groups, excludingIndex: groupIndex) else {
            presentWarning(
                title: "Duplicate Group Name",
                informativeText: "A group named \"\(result.name)\" already exists."
            )
            return
        }

        groups[groupIndex].name = result.name
        groups[groupIndex].shortcutKey = result.shortcutKey
        persist(BookmarksConfig(groups: normalizeGroups(groups)))
    }

    @objc
    private func deleteGroup(_ sender: Any?) {
        guard let groupIndex = selectGroupIndex(
            title: "Delete Group",
            informativeText: "Choose a group to delete.",
            allowDefault: false,
            preferredGroupName: selectedRow?.groupName
        ) else {
            return
        }

        let group = bookmarksConfig.groups[groupIndex]
        guard group.entries.isEmpty else {
            presentWarning(
                title: "Group Contains Folders",
                informativeText: "Move or delete all folders in \"\(group.name)\" before deleting the group."
            )
            return
        }

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Delete Group"
        alert.informativeText = "Delete group \"\(group.name)\"?"
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else {
            return
        }

        var groups = bookmarksConfig.groups
        groups.remove(at: groupIndex)
        persist(BookmarksConfig(groups: normalizeGroups(groups)))
    }

    @objc
    private func addBookmark(_ sender: Any?) {
        guard let result = presentFolderEditor(initialRow: nil) else {
            return
        }
        upsertBookmark(with: result, replacing: nil)
    }

    @objc
    private func editBookmark(_ sender: Any?) {
        guard let selectedRow else {
            return
        }
        guard let result = presentFolderEditor(initialRow: selectedRow) else {
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
        alert.messageText = "Delete Folder Bookmark"
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

    private func selectGroupIndex(
        title: String,
        informativeText: String,
        allowDefault: Bool,
        preferredGroupName: String?
    ) -> Int? {
        let candidates = bookmarksConfig.groups.enumerated().compactMap { index, group -> (Int, BookmarkGroup)? in
            guard allowDefault || !group.isDefault else {
                return nil
            }
            return (index, group)
        }

        guard !candidates.isEmpty else {
            presentWarning(
                title: "No Groups",
                informativeText: allowDefault
                    ? "There are no groups available."
                    : "Only the default group exists. It cannot be deleted."
            )
            return nil
        }

        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = title
        alert.informativeText = informativeText
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")

        let popup = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 320, height: 24), pullsDown: false)
        popup.addItems(withTitles: candidates.map { $0.1.name })
        if let preferredGroupName,
           let preferredIndex = candidates.firstIndex(where: { $0.1.name == preferredGroupName }) {
            popup.selectItem(at: preferredIndex)
        } else {
            popup.selectItem(at: 0)
        }
        alert.accessoryView = popup

        guard alert.runModal() == .alertFirstButtonReturn else {
            return nil
        }

        let selected = popup.indexOfSelectedItem
        guard selected >= 0, candidates.indices.contains(selected) else {
            return nil
        }
        return candidates[selected].0
    }

    private func presentGroupEditor(initialGroup: BookmarkGroup?) -> GroupEditorResult? {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = initialGroup == nil ? "Add Group" : "Edit Group"
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")

        let container = NSView(frame: NSRect(x: 0, y: 0, width: 360, height: 112))

        let nameLabel = NSTextField(labelWithString: "Group Name")
        nameLabel.frame = NSRect(x: 0, y: 84, width: 240, height: 20)
        nameLabel.font = .systemFont(ofSize: 11)
        nameLabel.textColor = .secondaryLabelColor

        let nameField = NSTextField(frame: NSRect(x: 0, y: 60, width: 260, height: 24))
        nameField.placeholderString = "Group name"

        let shortcutLabel = NSTextField(labelWithString: "Group Shortcut (1 char, optional)")
        shortcutLabel.frame = NSRect(x: 0, y: 32, width: 240, height: 20)
        shortcutLabel.font = .systemFont(ofSize: 11)
        shortcutLabel.textColor = .secondaryLabelColor

        let shortcutField = NSTextField(frame: NSRect(x: 0, y: 8, width: 70, height: 24))
        shortcutField.alignment = .center
        shortcutField.placeholderString = "Key"

        if let initialGroup {
            nameField.stringValue = initialGroup.name
            shortcutField.stringValue = initialGroup.shortcutKey ?? ""
        }

        container.addSubview(nameLabel)
        container.addSubview(nameField)
        container.addSubview(shortcutLabel)
        container.addSubview(shortcutField)
        alert.accessoryView = container

        guard alert.runModal() == .alertFirstButtonReturn else {
            return nil
        }

        let name = nameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            presentWarning(
                title: "Missing Required Field",
                informativeText: "Group name is required."
            )
            return nil
        }

        return GroupEditorResult(
            name: name,
            shortcutKey: normalizedShortcutKey(shortcutField.stringValue)
        )
    }

    private func presentFolderEditor(initialRow: BookmarkRow?) -> EditorResult? {
        let existingGroups = bookmarksConfig.groups
        guard !existingGroups.isEmpty else {
            presentWarning(
                title: "No Groups",
                informativeText: "Add a group before adding folder bookmarks."
            )
            return nil
        }

        let groupNames = existingGroups.map(\.name)

        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = initialRow == nil ? "Add Folder Bookmark" : "Edit Folder Bookmark"
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")

        let container = NSView(frame: NSRect(x: 0, y: 0, width: 460, height: 186))

        let groupLabel = NSTextField(labelWithString: "Group")
        groupLabel.frame = NSRect(x: 0, y: 160, width: 220, height: 20)
        groupLabel.font = .systemFont(ofSize: 11)
        groupLabel.textColor = .secondaryLabelColor

        let groupPopup = NSPopUpButton(frame: NSRect(x: 0, y: 136, width: 260, height: 24), pullsDown: false)
        groupPopup.addItems(withTitles: groupNames)

        let displayNameLabel = NSTextField(labelWithString: "Display Name")
        displayNameLabel.frame = NSRect(x: 0, y: 108, width: 200, height: 20)
        displayNameLabel.font = .systemFont(ofSize: 11)
        displayNameLabel.textColor = .secondaryLabelColor

        let displayNameField = NSTextField(frame: NSRect(x: 0, y: 84, width: 210, height: 24))
        displayNameField.placeholderString = "Bookmark name"

        let entryShortcutLabel = NSTextField(labelWithString: "Folder Shortcut (1 char, optional)")
        entryShortcutLabel.frame = NSRect(x: 220, y: 108, width: 240, height: 20)
        entryShortcutLabel.font = .systemFont(ofSize: 11)
        entryShortcutLabel.textColor = .secondaryLabelColor

        let entryShortcutField = NSTextField(frame: NSRect(x: 220, y: 84, width: 70, height: 24))
        entryShortcutField.alignment = .center
        entryShortcutField.placeholderString = "Key"

        let pathLabel = NSTextField(labelWithString: "Path")
        pathLabel.frame = NSRect(x: 0, y: 56, width: 210, height: 20)
        pathLabel.font = .systemFont(ofSize: 11)
        pathLabel.textColor = .secondaryLabelColor

        let pathField = NSTextField(frame: NSRect(x: 0, y: 32, width: 460, height: 24))
        pathField.placeholderString = "/path/to/directory"

        container.addSubview(groupLabel)
        container.addSubview(groupPopup)
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
            displayNameField.stringValue = initialRow.displayName
            pathField.stringValue = initialRow.path
            entryShortcutField.stringValue = initialRow.shortcutKey ?? ""
        } else {
            groupPopup.selectItem(at: 0)
        }

        guard alert.runModal() == .alertFirstButtonReturn else {
            return nil
        }

        let selectedGroupIndex = groupPopup.indexOfSelectedItem
        guard selectedGroupIndex >= 0, groupNames.indices.contains(selectedGroupIndex) else {
            return nil
        }

        let groupName = groupNames[selectedGroupIndex].trimmingCharacters(in: .whitespacesAndNewlines)
        let displayName = displayNameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let path = pathField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !groupName.isEmpty, !displayName.isEmpty, !path.isEmpty else {
            presentWarning(
                title: "Missing Required Fields",
                informativeText: "Group, display name, and path are required."
            )
            return nil
        }

        return EditorResult(
            groupName: groupName,
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

        if let existingRow,
           let existingGroupIndex = groups.firstIndex(where: { $0.name == existingRow.groupName }) {
            groups[existingGroupIndex].entries.removeAll { entry in
                entry.path == existingRow.path && entry.displayName == existingRow.displayName
            }
        }

        let newEntry = BookmarkEntry(
            displayName: result.displayName,
            path: result.path,
            shortcutKey: result.shortcutKey
        )

        if let targetGroupIndex = groups.firstIndex(where: { $0.name == result.groupName }) {
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
                    shortcutKey: nil,
                    isDefault: false
                )
            )
        }

        persist(BookmarksConfig(groups: normalizeGroups(groups)))
    }

    private func normalizeGroups(_ groups: [BookmarkGroup]) -> [BookmarkGroup] {
        var normalized = groups.map { group in
            var updated = group
            updated.entries.sort { lhs, rhs in
                lhs.displayName.localizedStandardCompare(rhs.displayName) == .orderedAscending
            }
            return updated
        }

        normalized.sort { lhs, rhs in
            if lhs.isDefault != rhs.isDefault {
                return lhs.isDefault
            }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }

        return normalized
    }

    private func hasGroup(named name: String, in groups: [BookmarkGroup], excludingIndex: Int? = nil) -> Bool {
        groups.enumerated().contains { index, group in
            guard index != excludingIndex else {
                return false
            }
            return group.name.caseInsensitiveCompare(name) == .orderedSame
        }
    }

    private func presentWarning(title: String, informativeText: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = title
        alert.informativeText = informativeText
        alert.addButton(withTitle: "OK")
        alert.runModal()
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
        if row.isDefaultGroup {
            if let entry = row.shortcutKey {
                return "'\(entry)"
            }
            return "-"
        }

        if let group = row.groupShortcutKey, let entry = row.shortcutKey {
            return "'\(group) \(entry)"
        }
        return "-"
    }
}
