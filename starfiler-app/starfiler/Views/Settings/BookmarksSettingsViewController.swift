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

    private struct BookmarkSelectionTarget {
        let groupName: String
        let displayName: String
        let path: String
    }

    private struct BookmarkPosition {
        let groupIndex: Int
        let entryIndex: Int
    }

    private struct BookmarkIdentity: Hashable {
        let groupName: String
        let displayName: String
        let path: String
        let shortcutKey: String?
    }

    private let configManager: ConfigManager
    private let securityScopedBookmarkService: any SecurityScopedBookmarkProviding

    private let descriptionLabel = NSTextField(
        wrappingLabelWithString:
            "Configure group shortcut keys and folder shortcut keys separately. " +
            "Shortcut keys can be a sequence (example: \"r d\" or \"d u\"). " +
            "Set group keys with the group actions, then assign each folder to a group. " +
            "Use Move buttons to reorder groups and folders."
    )
    private let groupActionsStack = NSStackView()
    private let addGroupButton = NSButton(title: "Add Group", target: nil, action: nil)
    private let editGroupButton = NSButton(title: "Edit Group", target: nil, action: nil)
    private let deleteGroupButton = NSButton(title: "Delete Group", target: nil, action: nil)
    private let moveGroupUpButton = NSButton(title: "Move Group Up", target: nil, action: nil)
    private let moveGroupDownButton = NSButton(title: "Move Group Down", target: nil, action: nil)

    private let scrollView = NSScrollView()
    private let tableView = NSTableView()

    private let addButton = NSButton(title: "Add Folder", target: nil, action: nil)
    private let editButton = NSButton(title: "Edit Folder", target: nil, action: nil)
    private let deleteButton = NSButton(title: "Delete Folder", target: nil, action: nil)
    private let moveUpButton = NSButton(title: "Move Up", target: nil, action: nil)
    private let moveDownButton = NSButton(title: "Move Down", target: nil, action: nil)
    private let reloadButton = NSButton(title: "Reload", target: nil, action: nil)
    private let openConfigButton = NSButton(title: "Open Config File", target: nil, action: nil)

    private var bookmarksConfig = BookmarksConfig()
    private var rows: [BookmarkRow] = []
    private weak var folderEditorPathField: NSTextField?

    init(
        configManager: ConfigManager = ConfigManager(),
        securityScopedBookmarkService: any SecurityScopedBookmarkProviding = SecurityScopedBookmarkService.shared
    ) {
        self.configManager = configManager
        self.securityScopedBookmarkService = securityScopedBookmarkService
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

        moveGroupUpButton.translatesAutoresizingMaskIntoConstraints = false
        moveGroupUpButton.bezelStyle = .rounded
        moveGroupUpButton.target = self
        moveGroupUpButton.action = #selector(moveGroupUp(_:))

        moveGroupDownButton.translatesAutoresizingMaskIntoConstraints = false
        moveGroupDownButton.bezelStyle = .rounded
        moveGroupDownButton.target = self
        moveGroupDownButton.action = #selector(moveGroupDown(_:))

        groupActionsStack.addArrangedSubview(addGroupButton)
        groupActionsStack.addArrangedSubview(editGroupButton)
        groupActionsStack.addArrangedSubview(deleteGroupButton)
        groupActionsStack.addArrangedSubview(moveGroupUpButton)
        groupActionsStack.addArrangedSubview(moveGroupDownButton)

        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.rowHeight = 24
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.allowsColumnReordering = false
        tableView.allowsMultipleSelection = true
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
        shortcutColumn.width = 200
        shortcutColumn.minWidth = 140

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

        moveUpButton.translatesAutoresizingMaskIntoConstraints = false
        moveUpButton.bezelStyle = .rounded
        moveUpButton.target = self
        moveUpButton.action = #selector(moveBookmarkUp(_:))

        moveDownButton.translatesAutoresizingMaskIntoConstraints = false
        moveDownButton.bezelStyle = .rounded
        moveDownButton.target = self
        moveDownButton.action = #selector(moveBookmarkDown(_:))

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
        view.addSubview(moveUpButton)
        view.addSubview(moveDownButton)
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

            moveUpButton.leadingAnchor.constraint(equalTo: deleteButton.trailingAnchor, constant: 8),
            moveUpButton.centerYAnchor.constraint(equalTo: addButton.centerYAnchor),

            moveDownButton.leadingAnchor.constraint(equalTo: moveUpButton.trailingAnchor, constant: 8),
            moveDownButton.centerYAnchor.constraint(equalTo: addButton.centerYAnchor),

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
        let hasSelection = !selectedRows.isEmpty
        let hasSingleSelection = selectedRows.count == 1
        editButton.isEnabled = hasSingleSelection
        deleteButton.isEnabled = hasSelection
        moveUpButton.isEnabled = canMoveSelectedBookmarkUp
        moveDownButton.isEnabled = canMoveSelectedBookmarkDown
        addButton.isEnabled = !bookmarksConfig.groups.isEmpty

        let hasGroups = !bookmarksConfig.groups.isEmpty
        editGroupButton.isEnabled = hasGroups
        deleteGroupButton.isEnabled = bookmarksConfig.groups.contains { !$0.isDefault }
        let canMoveGroups = bookmarksConfig.groups.count > 1
        moveGroupUpButton.isEnabled = canMoveGroups
        moveGroupDownButton.isEnabled = canMoveGroups
    }

    private var selectedRow: BookmarkRow? {
        guard selectedRows.count == 1 else {
            return nil
        }
        let row = tableView.selectedRow
        guard row >= 0, rows.indices.contains(row) else {
            return nil
        }
        return rows[row]
    }

    private var selectedRows: [BookmarkRow] {
        tableView.selectedRowIndexes.compactMap { rowIndex in
            guard rows.indices.contains(rowIndex) else {
                return nil
            }
            return rows[rowIndex]
        }
    }

    private var canMoveSelectedBookmarkUp: Bool {
        guard let selectedRow, let position = position(for: selectedRow) else {
            return false
        }
        return position.entryIndex > 0
    }

    private var canMoveSelectedBookmarkDown: Bool {
        guard let selectedRow, let position = position(for: selectedRow) else {
            return false
        }
        return position.entryIndex + 1 < bookmarksConfig.groups[position.groupIndex].entries.count
    }

    private func position(for row: BookmarkRow) -> BookmarkPosition? {
        guard let groupIndex = bookmarksConfig.groups.firstIndex(where: { $0.name == row.groupName }) else {
            return nil
        }

        let entries = bookmarksConfig.groups[groupIndex].entries
        guard let entryIndex = entries.firstIndex(where: { entry in
            entry.path == row.path &&
                entry.displayName == row.displayName &&
                entry.shortcutKey == row.shortcutKey
        }) else {
            return nil
        }

        return BookmarkPosition(groupIndex: groupIndex, entryIndex: entryIndex)
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

        guard validateNoShortcutConflict(in: groups) else {
            return
        }
        persist(BookmarksConfig(groups: groups))
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

        let oldName = groups[groupIndex].name
        groups[groupIndex].name = result.name
        groups[groupIndex].shortcutKey = result.shortcutKey

        guard validateNoShortcutConflict(in: groups) else {
            return
        }

        let selectionTarget: BookmarkSelectionTarget?
        if let selectedRow, selectedRow.groupName == oldName {
            selectionTarget = BookmarkSelectionTarget(
                groupName: result.name,
                displayName: selectedRow.displayName,
                path: selectedRow.path
            )
        } else {
            selectionTarget = nil
        }
        persist(BookmarksConfig(groups: groups), selecting: selectionTarget)
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
        persist(BookmarksConfig(groups: groups))
    }

    @objc
    private func moveGroupUp(_ sender: Any?) {
        moveGroup(by: -1)
    }

    @objc
    private func moveGroupDown(_ sender: Any?) {
        moveGroup(by: 1)
    }

    private func moveGroup(by delta: Int) {
        guard bookmarksConfig.groups.count > 1 else {
            return
        }

        guard let groupIndex = selectGroupIndex(
            title: delta < 0 ? "Move Group Up" : "Move Group Down",
            informativeText: "Choose a group to move.",
            allowDefault: true,
            preferredGroupName: selectedRow?.groupName
        ) else {
            return
        }

        let destinationIndex = groupIndex + delta
        guard bookmarksConfig.groups.indices.contains(destinationIndex) else {
            NSSound.beep()
            return
        }

        var groups = bookmarksConfig.groups
        groups.swapAt(groupIndex, destinationIndex)

        let movedGroup = groups[destinationIndex]
        let selectionTarget = movedGroup.entries.first.map {
            BookmarkSelectionTarget(groupName: movedGroup.name, displayName: $0.displayName, path: $0.path)
        }
        persist(BookmarksConfig(groups: groups), selecting: selectionTarget)
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
        let selectedBookmarks = selectedRows
        guard !selectedBookmarks.isEmpty else {
            return
        }

        let selectionCount = selectedBookmarks.count
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = selectionCount == 1 ? "Delete Folder Bookmark" : "Delete Folder Bookmarks"
        if selectionCount == 1, let selectedRow = selectedBookmarks.first {
            alert.informativeText = "Delete \"\(selectedRow.displayName)\" from group \"\(selectedRow.groupName)\"?"
        } else {
            alert.informativeText = "Delete \(selectionCount) selected bookmarks?"
        }
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else {
            return
        }

        var groups = bookmarksConfig.groups
        let selectedKeys = Set(
            selectedBookmarks.map { row in
                BookmarkIdentity(
                    groupName: row.groupName,
                    displayName: row.displayName,
                    path: row.path,
                    shortcutKey: row.shortcutKey
                )
            }
        )
        for groupIndex in groups.indices {
            let groupName = groups[groupIndex].name
            groups[groupIndex].entries.removeAll { entry in
                selectedKeys.contains(
                    BookmarkIdentity(
                        groupName: groupName,
                        displayName: entry.displayName,
                        path: entry.path,
                        shortcutKey: entry.shortcutKey
                    )
                )
            }
        }

        persist(BookmarksConfig(groups: groups))
    }

    @objc
    private func moveBookmarkUp(_ sender: Any?) {
        moveSelectedBookmark(by: -1)
    }

    @objc
    private func moveBookmarkDown(_ sender: Any?) {
        moveSelectedBookmark(by: 1)
    }

    private func moveSelectedBookmark(by delta: Int) {
        guard let selectedRow, let position = position(for: selectedRow) else {
            return
        }

        var groups = bookmarksConfig.groups
        let destinationIndex = position.entryIndex + delta
        guard groups[position.groupIndex].entries.indices.contains(destinationIndex) else {
            NSSound.beep()
            return
        }

        groups[position.groupIndex].entries.swapAt(position.entryIndex, destinationIndex)
        let movedEntry = groups[position.groupIndex].entries[destinationIndex]
        let selectionTarget = BookmarkSelectionTarget(
            groupName: groups[position.groupIndex].name,
            displayName: movedEntry.displayName,
            path: movedEntry.path
        )
        persist(BookmarksConfig(groups: groups), selecting: selectionTarget)
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

    @objc
    private func browseFolderBookmarkPath(_ sender: Any?) {
        guard let pathField = folderEditorPathField else {
            return
        }

        let panel = NSOpenPanel()
        panel.title = "Choose Folder"
        panel.message = "Select a folder to bookmark."
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true

        let rawPath = pathField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if !rawPath.isEmpty {
            let currentURL = URL(fileURLWithPath: rawPath, isDirectory: true).standardizedFileURL
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: currentURL.path, isDirectory: &isDirectory), isDirectory.boolValue {
                panel.directoryURL = currentURL
            } else {
                let parentURL = currentURL.deletingLastPathComponent().standardizedFileURL
                if FileManager.default.fileExists(atPath: parentURL.path, isDirectory: &isDirectory), isDirectory.boolValue {
                    panel.directoryURL = parentURL
                }
            }
        }

        guard panel.runModal() == .OK, let selectedURL = panel.url else {
            return
        }

        pathField.stringValue = selectedURL.standardizedFileURL.path
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

        let shortcutLabel = NSTextField(labelWithString: "Group Shortcut Sequence (optional)")
        shortcutLabel.frame = NSRect(x: 0, y: 32, width: 240, height: 20)
        shortcutLabel.font = .systemFont(ofSize: 11)
        shortcutLabel.textColor = .secondaryLabelColor

        let shortcutField = NSTextField(frame: NSRect(x: 0, y: 8, width: 210, height: 24))
        shortcutField.placeholderString = "e.g. r"

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

        let entryShortcutLabel = NSTextField(labelWithString: "Folder Shortcut Sequence (optional)")
        entryShortcutLabel.frame = NSRect(x: 220, y: 108, width: 240, height: 20)
        entryShortcutLabel.font = .systemFont(ofSize: 11)
        entryShortcutLabel.textColor = .secondaryLabelColor

        let entryShortcutField = NSTextField(frame: NSRect(x: 220, y: 84, width: 170, height: 24))
        entryShortcutField.placeholderString = "e.g. d u"

        let pathLabel = NSTextField(labelWithString: "Path")
        pathLabel.frame = NSRect(x: 0, y: 56, width: 210, height: 20)
        pathLabel.font = .systemFont(ofSize: 11)
        pathLabel.textColor = .secondaryLabelColor

        let pathField = NSTextField(frame: NSRect(x: 0, y: 32, width: 348, height: 24))
        pathField.placeholderString = "/path/to/directory"

        let browsePathButton = NSButton(title: "Browse...", target: self, action: #selector(browseFolderBookmarkPath(_:)))
        browsePathButton.frame = NSRect(x: 356, y: 32, width: 104, height: 24)
        browsePathButton.bezelStyle = .rounded

        container.addSubview(groupLabel)
        container.addSubview(groupPopup)
        container.addSubview(displayNameLabel)
        container.addSubview(displayNameField)
        container.addSubview(entryShortcutLabel)
        container.addSubview(entryShortcutField)
        container.addSubview(pathLabel)
        container.addSubview(pathField)
        container.addSubview(browsePathButton)
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

        folderEditorPathField = pathField
        defer {
            folderEditorPathField = nil
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
        BookmarkShortcut.canonical(from: raw)
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

        guard validateNoShortcutConflict(in: groups) else {
            return
        }

        persist(BookmarksConfig(groups: groups))
        persistSecurityScopedBookmark(for: result.path)
    }

    private func validateNoShortcutConflict(in groups: [BookmarkGroup]) -> Bool {
        let config = BookmarksConfig(groups: groups)
        guard let conflict = config.firstShortcutConflict() else {
            return true
        }

        presentWarning(
            title: "Shortcut Conflict",
            informativeText:
                "Shortcut \"\(conflict.sequenceDisplayText)\" is already used by " +
                "\"\(conflict.existing.entryLabel)\" (group: \(conflict.existing.groupName)).\n\n" +
                "Change the shortcut and try again."
        )
        return false
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

    private func persist(_ config: BookmarksConfig, selecting selectionTarget: BookmarkSelectionTarget? = nil) {
        do {
            try configManager.saveBookmarksConfig(config)
            bookmarksConfig = config
            rows = flattenRows(from: config)
            tableView.reloadData()
            if let selectionTarget {
                selectRow(matching: selectionTarget)
            }
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

    private func persistSecurityScopedBookmark(for path: String) {
        let normalizedPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedPath.isEmpty else {
            return
        }

        let resolvedPath = UserPaths.resolveBookmarkPath(normalizedPath)
        let url = URL(fileURLWithPath: resolvedPath, isDirectory: true).standardizedFileURL
        Task { [weak self] in
            guard let self else {
                return
            }

            do {
                try await self.securityScopedBookmarkService.saveBookmark(for: url)
            } catch {
                await MainActor.run {
                    let alert = NSAlert()
                    alert.alertStyle = .warning
                    alert.messageText = "Bookmark saved without access permission"
                    alert.informativeText =
                        "Path: \(url.path)\n\n" +
                        "Open the folder once via Browse and save again to grant sandbox access.\n\n" +
                        error.localizedDescription
                    alert.addButton(withTitle: "OK")
                    alert.runModal()
                }
            }
        }
    }

    private func selectRow(matching target: BookmarkSelectionTarget) {
        guard let rowIndex = rows.firstIndex(where: { row in
            row.groupName == target.groupName &&
                row.displayName == target.displayName &&
                row.path == target.path
        }) else {
            return
        }

        tableView.selectRowIndexes(IndexSet(integer: rowIndex), byExtendingSelection: false)
        tableView.scrollRowToVisible(rowIndex)
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
        if let hint = BookmarkShortcut.hint(
            groupShortcut: row.groupShortcutKey,
            entryShortcut: row.shortcutKey,
            isDefaultGroup: row.isDefaultGroup
        ) {
            return hint
        }
        return "-"
    }
}
