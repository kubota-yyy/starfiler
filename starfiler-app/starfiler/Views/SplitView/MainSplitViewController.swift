import AppKit

private final class ActionToastPresenter {
    private weak var currentToast: NSView?
    private var dismissWorkItem: DispatchWorkItem?

    func show(message: String, in hostView: NSView) {
        dismissWorkItem?.cancel()
        currentToast?.removeFromSuperview()

        let toastView = makeToastView(message: message)
        toastView.alphaValue = 0
        hostView.addSubview(toastView)

        NSLayoutConstraint.activate([
            toastView.trailingAnchor.constraint(equalTo: hostView.trailingAnchor, constant: -16),
            toastView.bottomAnchor.constraint(equalTo: hostView.bottomAnchor, constant: -16),
            toastView.widthAnchor.constraint(lessThanOrEqualToConstant: 380)
        ])

        hostView.layoutSubtreeIfNeeded()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.14
            toastView.animator().alphaValue = 1
        }

        currentToast = toastView
        let dismiss = DispatchWorkItem { [weak self, weak toastView] in
            guard let self, let toastView else {
                return
            }

            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.16
                toastView.animator().alphaValue = 0
            }, completionHandler: {
                toastView.removeFromSuperview()
                if self.currentToast === toastView {
                    self.currentToast = nil
                }
            })
        }
        dismissWorkItem = dismiss
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4, execute: dismiss)
    }

    private func makeToastView(message: String) -> NSView {
        let container = NSVisualEffectView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.material = .hudWindow
        container.blendingMode = .withinWindow
        container.state = .active
        container.wantsLayer = true
        container.layer?.cornerRadius = 10
        container.layer?.masksToBounds = true
        container.layer?.borderWidth = 1
        container.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.35).cgColor

        let label = NSTextField(wrappingLabelWithString: message)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textColor = .labelColor
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.maximumNumberOfLines = 3

        container.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            label.topAnchor.constraint(equalTo: container.topAnchor, constant: 10),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -10)
        ])

        return container
    }
}

final class MainSplitViewController: NSSplitViewController {
    private struct PaneStatus {
        var path: String
        var itemCount: Int
        var markedCount: Int
    }

    private let viewModel: MainViewModel
    private let configManager: ConfigManager
    private let sidebarViewModel: SidebarViewModel
    private let sidebarViewController: SidebarViewController
    private let sidebarSplitItem: NSSplitViewItem
    private let leftPaneViewController: FilePaneViewController
    private let rightPaneViewController: FilePaneViewController
    private let previewPaneViewController: PreviewPaneViewController
    private let previewSplitItem: NSSplitViewItem

    private var bookmarksConfig: BookmarksConfig
    private var bookmarkSearchPanelController: BookmarkSearchPanelController?
    private var batchRenameWindowController: NSWindowController?
    private var syncWindowController: NSWindowController?

    private var leftPaneStatus: PaneStatus
    private var rightPaneStatus: PaneStatus
    private var actionFeedbackEnabled: Bool
    private var fileIconSize: CGFloat
    private let toastPresenter = ActionToastPresenter()

    var onStatusChanged: ((String, Int, Int) -> Void)?
    var onSpotlightSearchScopeChanged: ((SpotlightSearchScope) -> Void)?
    var onImagePreviewRecursiveModeChanged: ((Bool) -> Void)?

    init(viewModel: MainViewModel, configManager: ConfigManager, actionFeedbackEnabled: Bool, fileIconSize: CGFloat) {
        self.viewModel = viewModel
        self.configManager = configManager
        self.actionFeedbackEnabled = actionFeedbackEnabled
        self.fileIconSize = fileIconSize

        self.sidebarViewModel = SidebarViewModel(
            configManager: configManager,
            visitHistoryService: viewModel.visitHistoryService
        )
        self.sidebarViewController = SidebarViewController(viewModel: sidebarViewModel)
        self.sidebarSplitItem = NSSplitViewItem(sidebarWithViewController: sidebarViewController)

        self.leftPaneViewController = FilePaneViewController(viewModel: viewModel.leftPane)
        self.rightPaneViewController = FilePaneViewController(viewModel: viewModel.rightPane)
        self.previewPaneViewController = PreviewPaneViewController(viewModel: viewModel.previewPane)
        self.previewSplitItem = NSSplitViewItem(viewController: previewPaneViewController)
        self.bookmarksConfig = configManager.loadBookmarksConfig()

        self.leftPaneStatus = PaneStatus(
            path: viewModel.leftPane.paneState.currentDirectory.path,
            itemCount: viewModel.leftPane.directoryContents.displayedItems.count,
            markedCount: viewModel.leftPane.markedCount
        )
        self.rightPaneStatus = PaneStatus(
            path: viewModel.rightPane.paneState.currentDirectory.path,
            itemCount: viewModel.rightPane.directoryContents.displayedItems.count,
            markedCount: viewModel.rightPane.markedCount
        )

        super.init(nibName: nil, bundle: nil)

        viewModel.requestTextInput = { [weak self] prompt in
            self?.presentTextPrompt(prompt)
        }
        viewModel.onFileOperationCompleted = { [weak self] record, context in
            self?.handleFileOperationCompleted(record, context: context)
        }

        configureSplitView()
        bindPaneControllers()
        bindSidebar()
        bindVisitHistory()
        refreshActivePaneUI(focusActivePane: false)
        viewModel.refreshPreviewForActivePane()
        applySidebarVisibility(animated: false)
        applyPreviewPaneVisibility(animated: false)

        propagateBookmarksConfig()
        setSpotlightSearchScope(viewModel.leftPane.spotlightSearchScope)
        setFileIconSize(fileIconSize)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func focusActivePane() {
        paneViewController(for: viewModel.activePaneSide).focusTable()
    }

    func togglePreviewPane() {
        viewModel.togglePreviewPane()
        applyPreviewPaneVisibility(animated: true)
    }

    func toggleSidebarPane() {
        viewModel.toggleSidebar()
        applySidebarVisibility(animated: true)
    }

    func setFilerTheme(_ theme: FilerTheme, backgroundOpacity: CGFloat = 1.0) {
        let palette = theme.palette
        splitView.wantsLayer = true
        splitView.layer?.backgroundColor = palette.windowBackgroundColor.applyingBackgroundOpacity(backgroundOpacity).cgColor

        leftPaneViewController.applyTheme(theme, backgroundOpacity: backgroundOpacity)
        rightPaneViewController.applyTheme(theme, backgroundOpacity: backgroundOpacity)
        sidebarViewController.applyTheme(theme, backgroundOpacity: backgroundOpacity)
        previewPaneViewController.applyTheme(theme, backgroundOpacity: backgroundOpacity)
    }

    func reloadBookmarksConfig() {
        bookmarksConfig = configManager.loadBookmarksConfig()
        propagateBookmarksConfig()
        sidebarViewController.reloadData()
    }

    func reloadKeybindings() {
        leftPaneViewController.reloadKeybindings()
        rightPaneViewController.reloadKeybindings()
    }

    func setActionFeedbackEnabled(_ enabled: Bool) {
        actionFeedbackEnabled = enabled
    }

    func setSpotlightSearchScope(_ scope: SpotlightSearchScope) {
        viewModel.setSpotlightSearchScope(scope)
        leftPaneViewController.setSpotlightSearchScope(scope)
        rightPaneViewController.setSpotlightSearchScope(scope)
    }

    func setFileIconSize(_ size: CGFloat) {
        let clampedSize = min(max(size, 12), 40)
        fileIconSize = clampedSize
        leftPaneViewController.setFileIconSize(clampedSize)
        rightPaneViewController.setFileIconSize(clampedSize)
    }

    private func configureSplitView() {
        splitView.isVertical = true
        splitView.dividerStyle = .thin
        splitView.autosaveName = "MainSplitViewV2"

        sidebarSplitItem.minimumThickness = 140
        sidebarSplitItem.maximumThickness = 240
        sidebarSplitItem.canCollapse = true
        addSplitViewItem(sidebarSplitItem)

        let leftItem = NSSplitViewItem(viewController: leftPaneViewController)
        leftItem.minimumThickness = 280
        addSplitViewItem(leftItem)

        let rightItem = NSSplitViewItem(viewController: rightPaneViewController)
        rightItem.minimumThickness = 280
        addSplitViewItem(rightItem)

        previewSplitItem.minimumThickness = 260
        previewSplitItem.canCollapse = true
        addSplitViewItem(previewSplitItem)
    }

    private func bindPaneControllers() {
        leftPaneViewController.onTabPressed = { [weak self] in
            self?.handleTabSwitch() ?? false
        }
        rightPaneViewController.onTabPressed = { [weak self] in
            self?.handleTabSwitch() ?? false
        }

        leftPaneViewController.onDidRequestActivate = { [weak self] in
            self?.setActivePane(.left)
        }
        rightPaneViewController.onDidRequestActivate = { [weak self] in
            self?.setActivePane(.right)
        }

        leftPaneViewController.onSelectionChanged = { [weak self] _ in
            self?.viewModel.updatePreviewSelection(for: .left)
        }
        rightPaneViewController.onSelectionChanged = { [weak self] _ in
            self?.viewModel.updatePreviewSelection(for: .right)
        }

        leftPaneViewController.onStatusChanged = { [weak self] path, itemCount, markedCount in
            self?.updatePaneStatus(side: .left, path: path, itemCount: itemCount, markedCount: markedCount)
        }
        rightPaneViewController.onStatusChanged = { [weak self] path, itemCount, markedCount in
            self?.updatePaneStatus(side: .right, path: path, itemCount: itemCount, markedCount: markedCount)
        }

        leftPaneViewController.onFileOperationRequested = { [weak self] action in
            self?.handleGlobalAction(action) ?? false
        }
        rightPaneViewController.onFileOperationRequested = { [weak self] action in
            self?.handleGlobalAction(action) ?? false
        }

        leftPaneViewController.onBookmarkJump = { [weak self] path in
            self?.navigateToSearchResult(BookmarkSearchViewModel.SearchResult(
                groupName: "", displayName: "", path: path, shortcutHint: nil
            ))
        }
        rightPaneViewController.onBookmarkJump = { [weak self] path in
            self?.navigateToSearchResult(BookmarkSearchViewModel.SearchResult(
                groupName: "", displayName: "", path: path, shortcutHint: nil
            ))
        }

        leftPaneViewController.onDropOperationCompleted = { [weak self] operation, itemCount in
            self?.handleDropOperationCompleted(operation: operation, itemCount: itemCount)
        }
        rightPaneViewController.onDropOperationCompleted = { [weak self] operation, itemCount in
            self?.handleDropOperationCompleted(operation: operation, itemCount: itemCount)
        }

        leftPaneViewController.onSpotlightSearchScopeChanged = { [weak self] scope in
            self?.handleSpotlightSearchScopeChanged(scope)
        }
        rightPaneViewController.onSpotlightSearchScopeChanged = { [weak self] scope in
            self?.handleSpotlightSearchScopeChanged(scope)
        }

        previewPaneViewController.onRecursiveModeChanged = { [weak self] enabled in
            self?.viewModel.previewPane.setRecursiveEnabled(enabled)
            self?.onImagePreviewRecursiveModeChanged?(enabled)
        }

        previewPaneViewController.onImageSelectionChanged = { [weak self] selectedURL in
            self?.viewModel.previewPane.setSelectedFileURL(selectedURL)
        }

        previewPaneViewController.onNavigateRequested = { [weak self] destination in
            self?.viewModel.activePane.navigate(to: destination)
        }
    }

    private func bindSidebar() {
        sidebarViewController.onNavigateRequested = { [weak self] url in
            self?.viewModel.activePane.navigate(to: url)
        }
    }

    private func handleTabSwitch() -> Bool {
        viewModel.switchActivePane()
        refreshActivePaneUI(focusActivePane: true)
        return true
    }

    private func setActivePane(_ side: PaneSide) {
        guard viewModel.activePaneSide != side else {
            return
        }

        viewModel.setActivePane(side)
        refreshActivePaneUI(focusActivePane: false)
    }

    private func handleGlobalAction(_ action: KeyAction) -> Bool {
        switch action {
        case .copy:
            viewModel.copyMarked()
            return true
        case .paste:
            viewModel.paste()
            return true
        case .move:
            viewModel.cutMarked()
            return true
        case .delete:
            viewModel.deleteMarked()
            return true
        case .rename:
            viewModel.rename()
            return true
        case .createDirectory:
            viewModel.createDirectory()
            return true
        case .undo:
            viewModel.undo()
            return true
        case .togglePreview:
            togglePreviewPane()
            return true
        case .toggleSidebar:
            toggleSidebarPane()
            return true
        case .openBookmarkSearch:
            presentBookmarkSearchPanel()
            return true
        case .openHistory:
            presentBookmarkSearchPanel()
            return true
        case .addBookmark:
            presentAddBookmarkAlert()
            return true
        case .batchRename:
            presentBatchRenameWindow()
            return true
        case .syncPanes:
            presentSyncWindow()
            return true
        default:
            return false
        }
    }

    private func handleFileOperationCompleted(_ record: FileOperationRecord, context: FileOperationCompletionContext) {
        let message: String?
        switch context {
        case .undo:
            message = "Action undone"
        case .normal:
            message = actionMessage(for: record.result)
        }

        guard let message else {
            return
        }

        showActionToast(message)
    }

    private func handleDropOperationCompleted(operation: NSDragOperation, itemCount: Int) {
        guard itemCount > 0 else {
            return
        }

        let message: String
        switch operation {
        case .move:
            message = "\(itemCount) \(itemLabel(for: itemCount)) moved"
        default:
            message = "\(itemCount) \(itemLabel(for: itemCount)) copied"
        }
        showActionToast(message)
    }

    private func handleSpotlightSearchScopeChanged(_ scope: SpotlightSearchScope) {
        setSpotlightSearchScope(scope)
        onSpotlightSearchScopeChanged?(scope)
    }

    private func actionMessage(for result: FileOperationResult) -> String? {
        switch result {
        case .copied(let changes):
            guard !changes.isEmpty else { return nil }
            return "\(changes.count) \(itemLabel(for: changes.count)) copied"
        case .moved(let changes):
            guard !changes.isEmpty else { return nil }
            return "\(changes.count) \(itemLabel(for: changes.count)) moved"
        case .trashed(let changes):
            guard !changes.isEmpty else { return nil }
            return "\(changes.count) \(itemLabel(for: changes.count)) moved to Trash"
        case .renamed(let change):
            guard change.source != change.destination else { return nil }
            return "Renamed to \"\(change.destination.lastPathComponent)\""
        case .createdDirectory(let url):
            return "Created folder \"\(url.lastPathComponent)\""
        case .batchRenamed(let changes):
            guard !changes.isEmpty else { return nil }
            return "\(changes.count) \(itemLabel(for: changes.count)) renamed"
        }
    }

    private func itemLabel(for count: Int) -> String {
        count == 1 ? "item" : "items"
    }

    private func showActionToast(_ message: String) {
        guard actionFeedbackEnabled else {
            return
        }

        toastPresenter.show(message: message, in: view)
    }

    private func refreshActivePaneUI(focusActivePane shouldFocus: Bool) {
        leftPaneViewController.setActive(viewModel.activePaneSide == .left)
        rightPaneViewController.setActive(viewModel.activePaneSide == .right)

        if shouldFocus {
            focusActivePane()
        }

        publishActivePaneStatus()
    }

    private func applySidebarVisibility(animated: Bool) {
        let shouldCollapse = !viewModel.sidebarVisible
        guard sidebarSplitItem.isCollapsed != shouldCollapse else {
            return
        }

        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.18
                sidebarSplitItem.animator().isCollapsed = shouldCollapse
            }
        } else {
            sidebarSplitItem.isCollapsed = shouldCollapse
        }
    }

    private func applyPreviewPaneVisibility(animated: Bool) {
        let shouldCollapse = !viewModel.previewVisible
        guard previewSplitItem.isCollapsed != shouldCollapse else {
            return
        }

        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.18
                previewSplitItem.animator().isCollapsed = shouldCollapse
            }
        } else {
            previewSplitItem.isCollapsed = shouldCollapse
        }
    }

    private func updatePaneStatus(side: PaneSide, path: String, itemCount: Int, markedCount: Int) {
        let status = PaneStatus(path: path, itemCount: itemCount, markedCount: markedCount)

        switch side {
        case .left:
            leftPaneStatus = status
        case .right:
            rightPaneStatus = status
        }

        if side == viewModel.activePaneSide {
            publishActivePaneStatus()
        }
    }

    private func publishActivePaneStatus() {
        let status: PaneStatus

        switch viewModel.activePaneSide {
        case .left:
            status = leftPaneStatus
        case .right:
            status = rightPaneStatus
        }

        onStatusChanged?(status.path, status.itemCount, status.markedCount)
    }

    private func paneViewController(for side: PaneSide) -> FilePaneViewController {
        switch side {
        case .left:
            return leftPaneViewController
        case .right:
            return rightPaneViewController
        }
    }

    private func presentTextPrompt(_ prompt: TextInputPrompt) -> String? {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = prompt.title
        alert.informativeText = prompt.message
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")

        let inputField = NSTextField(string: prompt.defaultValue ?? "")
        inputField.frame = NSRect(x: 0, y: 0, width: 300, height: 24)
        alert.accessoryView = inputField

        guard alert.runModal() == .alertFirstButtonReturn else {
            return nil
        }

        return inputField.stringValue
    }

    private func bindVisitHistory() {
        viewModel.leftPane.onDirectoryChanged = { [weak self] url in
            self?.viewModel.visitHistoryService.recordVisit(to: url)
            self?.sidebarViewModel.reloadSections()
        }
        viewModel.rightPane.onDirectoryChanged = { [weak self] url in
            self?.viewModel.visitHistoryService.recordVisit(to: url)
            self?.sidebarViewModel.reloadSections()
        }
    }

    private func propagateBookmarksConfig() {
        leftPaneViewController.updateBookmarksConfig(bookmarksConfig)
        rightPaneViewController.updateBookmarksConfig(bookmarksConfig)
    }

    private func presentBookmarkSearchPanel() {
        bookmarkSearchPanelController?.dismiss()

        let searchVM = BookmarkSearchViewModel()
        searchVM.load(
            from: bookmarksConfig,
            history: viewModel.visitHistoryService.recentEntries(limit: 20)
        )

        let panel = BookmarkSearchPanelController(viewModel: searchVM)
        panel.onSelectEntry = { [weak self] result in
            self?.navigateToSearchResult(result)
        }
        panel.onDismiss = { [weak self] in
            self?.bookmarkSearchPanelController = nil
            self?.focusActivePane()
        }

        guard let window = view.window else {
            return
        }

        panel.showRelativeTo(window: window)
        bookmarkSearchPanelController = panel
    }

    private func navigateToSearchResult(_ result: BookmarkSearchViewModel.SearchResult) {
        let path = result.path
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) else {
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = "Path not found"
            alert.informativeText = path
            alert.addButton(withTitle: "OK")
            alert.runModal()
            return
        }

        let url = URL(fileURLWithPath: path).standardizedFileURL
        let destination = isDirectory.boolValue
            ? url
            : url.deletingLastPathComponent().standardizedFileURL

        viewModel.activePane.navigate(to: destination)
    }

    private func presentAddBookmarkAlert() {
        let currentDirectory = viewModel.activePane.paneState.currentDirectory.standardizedFileURL
        let defaultDisplayName = currentDirectory.lastPathComponent.isEmpty
            ? currentDirectory.path
            : currentDirectory.lastPathComponent

        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "Add Bookmark"
        alert.informativeText = currentDirectory.path
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")

        let accessoryContainer = NSView(frame: NSRect(x: 0, y: 0, width: 340, height: 134))

        let groupPopup = NSPopUpButton(frame: NSRect(x: 0, y: 104, width: 340, height: 26), pullsDown: false)
        groupPopup.addItems(withTitles: bookmarksConfig.groups.map(\.name))
        groupPopup.addItem(withTitle: "New Group")

        let newGroupField = NSTextField(frame: NSRect(x: 0, y: 78, width: 260, height: 24))
        newGroupField.placeholderString = "New group name"

        let groupShortcutField = NSTextField(frame: NSRect(x: 270, y: 78, width: 70, height: 24))
        groupShortcutField.placeholderString = "Key"
        groupShortcutField.alignment = .center

        let displayNameField = NSTextField(frame: NSRect(x: 0, y: 52, width: 340, height: 24))
        displayNameField.stringValue = defaultDisplayName

        let shortcutLabel = NSTextField(labelWithString: "Shortcut key (1 char):")
        shortcutLabel.frame = NSRect(x: 0, y: 26, width: 200, height: 20)
        shortcutLabel.font = .systemFont(ofSize: 11)
        shortcutLabel.textColor = .secondaryLabelColor

        let shortcutField = NSTextField(frame: NSRect(x: 0, y: 0, width: 70, height: 24))
        shortcutField.placeholderString = "Key"
        shortcutField.alignment = .center

        accessoryContainer.addSubview(groupPopup)
        accessoryContainer.addSubview(newGroupField)
        accessoryContainer.addSubview(groupShortcutField)
        accessoryContainer.addSubview(displayNameField)
        accessoryContainer.addSubview(shortcutLabel)
        accessoryContainer.addSubview(shortcutField)
        alert.accessoryView = accessoryContainer

        guard alert.runModal() == .alertFirstButtonReturn else {
            return
        }

        let selectedGroupIndex = groupPopup.indexOfSelectedItem
        let selectedGroupName: String
        var groupShortcutKey: String?
        if selectedGroupIndex >= 0, selectedGroupIndex < bookmarksConfig.groups.count {
            selectedGroupName = bookmarksConfig.groups[selectedGroupIndex].name
        } else {
            selectedGroupName = newGroupField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            let groupKey = groupShortcutField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            groupShortcutKey = groupKey.isEmpty ? nil : String(groupKey.prefix(1))
        }

        guard !selectedGroupName.isEmpty else {
            return
        }

        let displayName = displayNameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedDisplayName = displayName.isEmpty ? defaultDisplayName : displayName

        let entryShortcut = shortcutField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let entryShortcutKey: String? = entryShortcut.isEmpty ? nil : String(entryShortcut.prefix(1))

        saveBookmark(
            entry: BookmarkEntry(
                displayName: resolvedDisplayName,
                path: currentDirectory.path,
                shortcutKey: entryShortcutKey
            ),
            groupName: selectedGroupName,
            groupShortcutKey: groupShortcutKey
        )
    }

    private func saveBookmark(entry: BookmarkEntry, groupName: String, groupShortcutKey: String? = nil) {
        var groups = bookmarksConfig.groups

        if let groupIndex = groups.firstIndex(where: { $0.name == groupName }) {
            if let entryIndex = groups[groupIndex].entries.firstIndex(where: { $0.path == entry.path }) {
                groups[groupIndex].entries[entryIndex] = entry
            } else {
                groups[groupIndex].entries.append(entry)
            }
        } else {
            groups.append(BookmarkGroup(
                name: groupName,
                entries: [entry],
                shortcutKey: groupShortcutKey
            ))
        }

        bookmarksConfig.groups = groups.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }

        do {
            try configManager.saveBookmarksConfig(bookmarksConfig)
            sidebarViewController.reloadData()
            propagateBookmarksConfig()
            showActionToast("Saved bookmark \"\(entry.displayName)\"")
        } catch {
            let alert = NSAlert()
            alert.alertStyle = .critical
            alert.messageText = "Failed to save bookmark"
            alert.informativeText = error.localizedDescription
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }

    // MARK: - Batch Rename

    func presentBatchRenameWindow() {
        let urls = viewModel.activePane.markedOrSelectedURLs()
        guard !urls.isEmpty else { return }

        let urlSet = Set(urls)
        let items = viewModel.activePane.directoryContents.displayedItems
            .filter { urlSet.contains($0.url) }
        guard !items.isEmpty else { return }

        let allItems = viewModel.activePane.directoryContents.displayedItems

        let batchVM = BatchRenameViewModel(
            sourceFiles: items,
            allDirectoryFiles: allItems,
            configManager: configManager
        )

        batchVM.onApplyRequested = { [weak self] changes in
            self?.viewModel.executeBatchRename(renames: changes)
            self?.batchRenameWindowController?.close()
            self?.batchRenameWindowController = nil
        }

        batchVM.onDismissRequested = { [weak self] in
            self?.batchRenameWindowController?.close()
            self?.batchRenameWindowController = nil
        }

        let vc = BatchRenameViewController(viewModel: batchVM)
        let window = NSWindow(contentViewController: vc)
        window.title = "Batch Rename (\(items.count) files)"
        window.setContentSize(NSSize(width: 720, height: 600))
        window.styleMask = [.titled, .closable, .resizable]
        window.minSize = NSSize(width: 600, height: 400)
        window.center()

        let wc = NSWindowController(window: window)
        wc.showWindow(nil)
        batchRenameWindowController = wc
    }

    // MARK: - Sync Panes

    func presentSyncWindow() {
        let leftDir = viewModel.leftPane.paneState.currentDirectory
        let rightDir = viewModel.rightPane.paneState.currentDirectory

        let syncVM = SyncViewModel(
            leftDirectory: leftDir,
            rightDirectory: rightDir,
            configManager: configManager
        )

        let vc = SyncViewController(viewModel: syncVM)
        let window = NSWindow(contentViewController: vc)
        window.title = "Sync Panes"
        window.setContentSize(NSSize(width: 800, height: 600))
        window.styleMask = [.titled, .closable, .resizable]
        window.minSize = NSSize(width: 640, height: 400)
        window.center()

        let wc = NSWindowController(window: window)
        wc.showWindow(nil)
        syncWindowController = wc
    }
}
