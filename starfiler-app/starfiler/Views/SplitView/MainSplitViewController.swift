import AppKit

final class MainSplitViewController: NSSplitViewController, NSPopoverDelegate {
    private static let defaultSidebarWidth = CGFloat(260)
    private static let defaultPreviewWidth = CGFloat(320)
    private static let sidebarWidthRange: ClosedRange<CGFloat> = CGFloat(AppConfig.sidebarWidthRange.lowerBound) ... CGFloat(AppConfig.sidebarWidthRange.upperBound)
    private static var lastSelectedBookmarkGroupIndex: Int = 0

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
    private let leftSplitItem: NSSplitViewItem
    private let rightSplitItem: NSSplitViewItem
    private let previewPaneViewController: PreviewPaneViewController
    private let previewSplitItem: NSSplitViewItem

    private var bookmarksConfig: BookmarksConfig
    private var bookmarkSearchPanelController: BookmarkSearchPanelController?
    private var markdownPreviewPanelController: MarkdownPreviewPanelController?
    private var batchRenameWindowController: NSWindowController?


    private var leftPaneStatus: PaneStatus
    private var rightPaneStatus: PaneStatus
    private var actionFeedbackEnabled: Bool
    private var fileIconSize: CGFloat
    private var starEffectsEnabled = true
    private var currentFilerTheme: FilerTheme = .system
    private var animationEffectSettings = AnimationEffectSettings.allEnabled
    private let initialSidebarWidth: CGFloat
    private var hasAppliedInitialSidebarWidth = false
    private var lastReportedSidebarWidth: CGFloat
    private var lastReportedPreviewWidth: CGFloat
    private let toastPresenter = ActionToastPresenter()
    private let applicationRelatedItemLocator: any ApplicationRelatedItemLocating = ApplicationRelatedItemLocatorService()
    private var goToPathPopover: NSPopover?
    private weak var goToPathHighlightView: NSView?
    private var shouldRefocusAfterGoToPathDismiss = true

    var onStatusChanged: ((String, Int, Int) -> Void)?
    var onSpotlightSearchScopeChanged: ((SpotlightSearchScope) -> Void)?
    var onPaneVisibilityChanged: ((Bool, Bool) -> Void)?
    var onSidebarWidthChanged: ((CGFloat) -> Void)?
    var onFileIconSizeChanged: ((CGFloat) -> Void)?
    var onTerminalAction: ((KeyAction) -> Void)?

    init(
        viewModel: MainViewModel,
        configManager: ConfigManager,
        actionFeedbackEnabled: Bool,
        fileIconSize: CGFloat,
        initialSidebarWidth: CGFloat = MainSplitViewController.defaultSidebarWidth,
        initialLeftPaneVisible: Bool = true,
        initialRightPaneVisible: Bool = true
    ) {
        let clampedSidebarWidth = Self.clampedSidebarWidth(initialSidebarWidth)
        self.viewModel = viewModel
        self.configManager = configManager
        self.actionFeedbackEnabled = actionFeedbackEnabled
        self.fileIconSize = fileIconSize
        self.initialSidebarWidth = clampedSidebarWidth
        self.lastReportedSidebarWidth = clampedSidebarWidth
        self.lastReportedPreviewWidth = Self.defaultPreviewWidth

        self.sidebarViewModel = SidebarViewModel(
            configManager: configManager,
            visitHistoryService: viewModel.visitHistoryService,
            pinnedItemsService: viewModel.pinnedItemsService
        )
        self.sidebarViewController = SidebarViewController(viewModel: sidebarViewModel)
        self.sidebarSplitItem = NSSplitViewItem(viewController: sidebarViewController)

        self.leftPaneViewController = FilePaneViewController(viewModel: viewModel.leftPane)
        self.rightPaneViewController = FilePaneViewController(viewModel: viewModel.rightPane)
        self.leftSplitItem = NSSplitViewItem(viewController: leftPaneViewController)
        self.rightSplitItem = NSSplitViewItem(viewController: rightPaneViewController)
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
        splitView = BorderlessSplitView()

        viewModel.requestTextInput = { [weak self] prompt in
            self?.presentTextPrompt(prompt)
        }
        viewModel.onFileOperationCompleted = { [weak self] record, context in
            self?.handleFileOperationCompleted(record, context: context)
        }
        viewModel.onFileOperationFailed = { [weak self] message in
            self?.presentErrorAlert(
                title: "File operation failed",
                informativeText: message
            )
        }

        configureSplitView()
        bindPaneControllers()
        bindSidebar()
        bindVisitHistory()
        refreshActivePaneUI(focusActivePane: false)
        viewModel.refreshPreviewForActivePane()
        applySidebarVisibility(animated: false)
        applyPaneVisibility(leftVisible: initialLeftPaneVisible, rightVisible: initialRightPaneVisible, animated: false)
        applyPreviewPaneVisibility(animated: false)
        previewPaneViewController.setPreferredFitViewportWidth(lastReportedPreviewWidth)
        reportPreviewWidthIfNeeded(force: true)

        propagateBookmarksConfig()
        setSpotlightSearchScope(viewModel.leftPane.spotlightSearchScope)
        setFileIconSize(fileIconSize)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        applyInitialSidebarWidthIfNeeded()
    }

    override func splitViewDidResizeSubviews(_ notification: Notification) {
        super.splitViewDidResizeSubviews(notification)
        reportSidebarWidthIfNeeded(force: false)
        reportPreviewWidthIfNeeded(force: false)
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

    func toggleLeftPane() {
        togglePaneVisibility(side: .left, animated: true)
    }

    func toggleRightPane() {
        togglePaneVisibility(side: .right, animated: true)
    }

    func toggleSinglePane() {
        let leftVisible = !leftSplitItem.isCollapsed
        let rightVisible = !rightSplitItem.isCollapsed

        if leftVisible && rightVisible {
            switch viewModel.activePaneSide {
            case .left:
                applyPaneVisibility(leftVisible: true, rightVisible: false, animated: true)
            case .right:
                applyPaneVisibility(leftVisible: false, rightVisible: true, animated: true)
            }
            return
        }

        applyPaneVisibility(leftVisible: true, rightVisible: true, animated: true)
    }

    func equalizePaneWidths() {
        guard !leftSplitItem.isCollapsed, !rightSplitItem.isCollapsed else {
            return
        }

        view.layoutSubtreeIfNeeded()
        let arrangedSubviews = splitView.arrangedSubviews
        guard let leftIndex = arrangedSubviewIndex(for: leftPaneViewController.view, in: arrangedSubviews),
              let rightIndex = arrangedSubviewIndex(for: rightPaneViewController.view, in: arrangedSubviews),
              rightIndex == leftIndex + 1 else {
            return
        }

        let leftMinX = arrangedSubviews[leftIndex].frame.minX
        let rightMaxX = arrangedSubviews[rightIndex].frame.maxX
        let availableWidth = rightMaxX - leftMinX - splitView.dividerThickness
        guard availableWidth > 0 else {
            return
        }

        let targetDividerPosition = leftMinX + (availableWidth / 2)
        splitView.setPosition(targetDividerPosition, ofDividerAt: leftIndex)
    }

    private func arrangedSubviewIndex(for paneView: NSView, in arrangedSubviews: [NSView]) -> Int? {
        arrangedSubviews.firstIndex { arrangedSubview in
            paneView === arrangedSubview || paneView.isDescendant(of: arrangedSubview)
        }
    }

    func setFilerTheme(_ theme: FilerTheme, backgroundOpacity: CGFloat = 1.0) {
        currentFilerTheme = theme
        let palette = theme.palette
        splitView.wantsLayer = true
        splitView.layer?.backgroundColor = palette.windowBackgroundColor.applyingBackgroundOpacity(backgroundOpacity).cgColor

        toastPresenter.palette = palette
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

    func reloadSidebarSections() {
        sidebarViewController.reloadData()
    }

    func reloadKeybindings() {
        leftPaneViewController.reloadKeybindings()
        rightPaneViewController.reloadKeybindings()
    }

    func requestDeleteFromActivePane() {
        let selectedURLs = viewModel.activePane.markedOrSelectedURLs()
            .map(\.standardizedFileURL)
        guard !selectedURLs.isEmpty else {
            return
        }

        let appBundleURLs = selectedURLs.filter(Self.isApplicationBundleUnderApplications)

        guard !appBundleURLs.isEmpty else {
            viewModel.delete(urls: selectedURLs)
            return
        }

        presentApplicationDeletionDialog(selectedURLs: selectedURLs, appBundleURLs: appBundleURLs)
    }

    func presentGoToPathPrompt() {
        let activePaneSide = viewModel.activePaneSide
        let currentPath = viewModel.activePane.paneState.currentDirectory.path
        let paneView = paneViewController(for: activePaneSide).view
        let accentColor = goToPathAccentColor(for: activePaneSide)

        dismissGoToPathPopover(refocusActivePane: false)

        var popoverContentController: GoToPathPopoverViewController?
        let contentController = GoToPathPopoverViewController(
            currentPath: currentPath,
            accentColor: accentColor,
            onSubmit: { [weak self] rawInput in
                guard let self else {
                    return
                }

                let trimmedInput = rawInput.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmedInput.isEmpty else {
                    popoverContentController?.showValidationError("Enter a path")
                    return
                }

                guard let destination = self.resolveNavigationDestination(from: trimmedInput) else {
                    popoverContentController?.showValidationError("Path not found")
                    return
                }

                self.dismissGoToPathPopover(refocusActivePane: true)
                self.navigateActivePane(to: destination)
            },
            onCancel: { [weak self] in
                self?.dismissGoToPathPopover(refocusActivePane: true)
            }
        )
        popoverContentController = contentController

        let popover = NSPopover()
        popover.behavior = .semitransient
        popover.animates = true
        popover.delegate = self
        popover.contentViewController = contentController

        showGoToPathHighlight(on: paneView, accentColor: accentColor)

        let anchorRect = NSRect(x: paneView.bounds.midX - 1, y: paneView.bounds.height - 28, width: 2, height: 2)
        popover.show(relativeTo: anchorRect, of: paneView, preferredEdge: .minY)
        contentController.focusInputField()
        goToPathPopover = popover
    }

    func popoverDidClose(_ notification: Notification) {
        clearGoToPathPresentation(refocusActivePane: shouldRefocusAfterGoToPathDismiss)
        shouldRefocusAfterGoToPathDismiss = true
    }

    private func dismissGoToPathPopover(refocusActivePane: Bool) {
        shouldRefocusAfterGoToPathDismiss = refocusActivePane

        guard let popover = goToPathPopover else {
            clearGoToPathPresentation(refocusActivePane: refocusActivePane)
            return
        }

        popover.performClose(nil)
    }

    private func clearGoToPathPresentation(refocusActivePane: Bool) {
        goToPathPopover?.delegate = nil
        goToPathPopover = nil
        goToPathHighlightView?.removeFromSuperview()
        goToPathHighlightView = nil

        if refocusActivePane {
            focusActivePane()
        }
    }

    private func goToPathAccentColor(for side: PaneSide) -> NSColor {
        switch side {
        case .left:
            return .systemBlue
        case .right:
            return .systemOrange
        }
    }

    private func showGoToPathHighlight(on paneView: NSView, accentColor: NSColor) {
        goToPathHighlightView?.removeFromSuperview()

        let overlay = PaneHighlightOverlayView()
        overlay.translatesAutoresizingMaskIntoConstraints = false
        overlay.wantsLayer = true
        overlay.layer?.borderWidth = 3
        overlay.layer?.cornerRadius = 8
        overlay.layer?.borderColor = accentColor.withAlphaComponent(0.85).cgColor
        overlay.layer?.backgroundColor = accentColor.withAlphaComponent(0.08).cgColor

        paneView.addSubview(overlay)
        NSLayoutConstraint.activate([
            overlay.leadingAnchor.constraint(equalTo: paneView.leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: paneView.trailingAnchor),
            overlay.topAnchor.constraint(equalTo: paneView.topAnchor),
            overlay.bottomAnchor.constraint(equalTo: paneView.bottomAnchor)
        ])

        goToPathHighlightView = overlay
    }

    func embedWindowControlButtons(_ buttons: [NSButton]) {
        sidebarViewController.embedWindowControlButtons(buttons)
    }

    func setActionFeedbackEnabled(_ enabled: Bool) {
        actionFeedbackEnabled = enabled
    }

    func setStarEffectsEnabled(_ enabled: Bool) {
        starEffectsEnabled = enabled
        toastPresenter.starEffectsEnabled = enabled
        leftPaneViewController.setStarEffectsEnabled(enabled)
        rightPaneViewController.setStarEffectsEnabled(enabled)
        previewPaneViewController.setStarEffectsEnabled(enabled)
    }

    func setAnimationEffectSettings(_ settings: AnimationEffectSettings) {
        animationEffectSettings = settings
        leftPaneViewController.setAnimationEffectSettings(settings)
        rightPaneViewController.setAnimationEffectSettings(settings)
        previewPaneViewController.setAnimationEffectSettings(settings)
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

    func currentSidebarWidth() -> CGFloat {
        if sidebarSplitItem.isCollapsed {
            return lastReportedSidebarWidth
        }

        return Self.clampedSidebarWidth(sidebarViewController.view.frame.width)
    }

    private func configureSplitView() {
        splitView.isVertical = true
        splitView.dividerStyle = .thin
        splitView.autosaveName = "MainSplitViewV2"
        splitView.delegate = self

        sidebarSplitItem.minimumThickness = Self.sidebarWidthRange.lowerBound
        sidebarSplitItem.maximumThickness = Self.sidebarWidthRange.upperBound
        sidebarSplitItem.canCollapse = true
        sidebarSplitItem.titlebarSeparatorStyle = .none
        addSplitViewItem(sidebarSplitItem)

        leftSplitItem.minimumThickness = 280
        leftSplitItem.canCollapse = true
        leftSplitItem.titlebarSeparatorStyle = .none
        addSplitViewItem(leftSplitItem)

        rightSplitItem.minimumThickness = 280
        rightSplitItem.canCollapse = true
        rightSplitItem.titlebarSeparatorStyle = .none
        addSplitViewItem(rightSplitItem)

        previewSplitItem.minimumThickness = 260
        previewSplitItem.canCollapse = true
        previewSplitItem.titlebarSeparatorStyle = .none
        addSplitViewItem(previewSplitItem)
        lastReportedPreviewWidth = max(lastReportedPreviewWidth, previewSplitItem.minimumThickness)
    }

    private func bindPaneControllers() {
        bindPaneCallbacks(for: leftPaneViewController, side: .left)
        bindPaneCallbacks(for: rightPaneViewController, side: .right)

        previewPaneViewController.onImageSelectionChanged = { [weak self] selectedURL in
            self?.viewModel.previewPane.setSelectedFileURL(selectedURL)
        }

        previewPaneViewController.onNavigateRequested = { [weak self] destination in
            self?.viewModel.activePane.navigate(to: destination)
        }
    }

    private func bindPaneCallbacks(for pane: FilePaneViewController, side: PaneSide) {
        pane.onTabPressed = { [weak self] in
            self?.handleTabSwitch() ?? false
        }
        pane.onDidRequestActivate = { [weak self] in
            self?.setActivePane(side)
        }
        pane.onSelectionChanged = { [weak self] _ in
            self?.viewModel.updatePreviewSelection(for: side)
        }
        pane.onStatusChanged = { [weak self] path, itemCount, markedCount in
            self?.updatePaneStatus(side: side, path: path, itemCount: itemCount, markedCount: markedCount)
        }
        pane.onFileOperationRequested = { [weak self] action in
            self?.handleGlobalAction(action) ?? false
        }
        pane.onBookmarkJump = { [weak self] path in
            self?.navigateToSearchResult(BookmarkSearchViewModel.SearchResult(
                groupName: "", displayName: "", path: path, shortcutHint: nil
            ))
        }
        pane.onDirectoryLoadFailed = { [weak self] directory, error in
            self?.presentNavigationErrorAlert(for: directory, error: error)
        }
        pane.onDropOperationCompleted = { [weak self] operation, itemCount in
            self?.handleDropOperationCompleted(operation: operation, itemCount: itemCount)
        }
        pane.onSpotlightSearchScopeChanged = { [weak self] scope in
            self?.handleSpotlightSearchScopeChanged(scope)
        }
        pane.onFileIconSizeChanged = { [weak self] size in
            self?.handleFileIconSizeChanged(size)
        }
        pane.onMarkdownPreviewRequested = { [weak self] url in
            self?.presentMarkdownPreview(for: url)
        }
    }

    private func bindSidebar() {
        sidebarViewController.onNavigateRequested = { [weak self] url in
            self?.navigateActivePane(to: url)
        }
        sidebarViewController.onNavigationFailed = { [weak self] message in
            self?.presentErrorAlert(
                title: "Failed to open path",
                informativeText: message
            )
        }
        sidebarViewController.onHistoryJumpRequested = { [weak self] position in
            self?.viewModel.activePane.jumpToHistoryPosition(position)
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
            requestDeleteFromActivePane()
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
        case .toggleLeftPane:
            toggleLeftPane()
            return true
        case .toggleRightPane:
            toggleRightPane()
            return true
        case .toggleSinglePane:
            toggleSinglePane()
            return true
        case .equalizePaneWidths:
            equalizePaneWidths()
            return true
        case .matchOtherPaneDirectory:
            let changed = viewModel.matchOtherPaneDirectoryToActivePane()
            if changed {
                showActionToast("Other pane set to current folder")
            }
            return true
        case .goToOtherPaneDirectory:
            let changed = viewModel.moveActivePaneToOtherPaneDirectory()
            if changed {
                showActionToast("Moved to other pane folder")
            }
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
        case .syncPanesLeftToRight:
            let changed = viewModel.syncPanesLeftToRight()
            if changed { showActionToast("Synced: Left → Right") }
            return true
        case .syncPanesRightToLeft:
            let changed = viewModel.syncPanesRightToLeft()
            if changed { showActionToast("Synced: Right → Left") }
            return true
        case .togglePin:
            let wasPinned = viewModel.isPinnedActiveItem()
            viewModel.togglePinForActivePane()
            sidebarViewModel.reloadSections()
            showActionToast(wasPinned ? "Unpinned" : "Pinned")
            return true
        case .launchClaude, .launchCodex, .toggleTerminalPanel:
            onTerminalAction?(action)
            return true
        default:
            return false
        }
    }

    private struct DeletionChecklistRow {
        let url: URL
        let title: String
    }

    private func presentApplicationDeletionDialog(selectedURLs: [URL], appBundleURLs: [URL]) {
        let relatedItems = applicationRelatedItemLocator.relatedItems(forApplicationsAt: appBundleURLs)

        var rows: [DeletionChecklistRow] = []
        var seenPaths: Set<String> = []

        for url in selectedURLs {
            let path = url.standardizedFileURL.path
            guard seenPaths.insert(path).inserted else {
                continue
            }
            let prefix = Self.isApplicationBundleUnderApplications(url) ? "App" : "Selected"
            rows.append(
                DeletionChecklistRow(
                    url: url,
                    title: "[\(prefix)] \(url.lastPathComponent)  (\(path))"
                )
            )
        }

        for related in relatedItems {
            let normalizedURL = related.url.standardizedFileURL
            let path = normalizedURL.path
            guard seenPaths.insert(path).inserted else {
                continue
            }

            let appName = related.appURL.deletingPathExtension().lastPathComponent
            rows.append(
                DeletionChecklistRow(
                    url: normalizedURL,
                    title: "[\(related.category): \(appName)] \(path)"
                )
            )
        }

        guard !rows.isEmpty else {
            viewModel.delete(urls: selectedURLs)
            return
        }

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Delete app and related files?"
        alert.informativeText = "Checked items will be moved to Trash."
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")

        let accessory = makeDeletionChecklistAccessory(rows: rows)
        alert.accessoryView = accessory.container

        guard alert.runModal() == .alertFirstButtonReturn else {
            focusActivePane()
            return
        }

        let urlsToDelete = accessory.selections.compactMap { selection in
            selection.checkbox.state == .on ? selection.url : nil
        }

        guard !urlsToDelete.isEmpty else {
            focusActivePane()
            return
        }

        viewModel.delete(urls: urlsToDelete)
    }

    private func makeDeletionChecklistAccessory(
        rows: [DeletionChecklistRow]
    ) -> (container: NSView, selections: [(checkbox: NSButton, url: URL)]) {
        var selections: [(checkbox: NSButton, url: URL)] = []
        let contentWidth = CGFloat(620)
        let rowHeight = CGFloat(24)
        let contentHeight = CGFloat(rows.count) * rowHeight
        let documentView = NSView(frame: NSRect(x: 0, y: 0, width: contentWidth, height: max(contentHeight, rowHeight)))

        var y = documentView.frame.height - rowHeight
        for row in rows {
            let checkbox = NSButton(checkboxWithTitle: row.title, target: nil, action: nil)
            checkbox.state = .on
            checkbox.font = .systemFont(ofSize: 12)
            checkbox.lineBreakMode = .byTruncatingMiddle
            checkbox.frame = NSRect(x: 8, y: y, width: contentWidth - 16, height: rowHeight)
            documentView.addSubview(checkbox)
            selections.append((checkbox: checkbox, url: row.url))
            y -= rowHeight
        }

        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.borderType = .bezelBorder
        scrollView.documentView = documentView

        let visibleRowCount = min(max(rows.count, 1), 12)
        let height = CGFloat(visibleRowCount) * rowHeight + 10

        let container = NSView(frame: NSRect(x: 0, y: 0, width: 640, height: height))
        container.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: container.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            scrollView.widthAnchor.constraint(equalToConstant: 640),
            scrollView.heightAnchor.constraint(equalToConstant: height)
        ])

        return (container: container, selections: selections)
    }

    private static func isApplicationBundleUnderApplications(_ url: URL) -> Bool {
        let normalizedURL = url.standardizedFileURL
        return normalizedURL.pathExtension.caseInsensitiveCompare("app") == .orderedSame
            && normalizedURL.path.hasPrefix("/Applications/")
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

    private func handleFileIconSizeChanged(_ size: CGFloat) {
        let clampedSize = min(max(size, 12), 40)
        setFileIconSize(clampedSize)
        onFileIconSizeChanged?(clampedSize)
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
        updateSidebarNavigationHistory()
    }

    private func applySidebarVisibility(animated: Bool) {
        let shouldCollapse = !viewModel.sidebarVisible
        guard sidebarSplitItem.isCollapsed != shouldCollapse else {
            return
        }

        if animated {
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.18
                sidebarSplitItem.animator().isCollapsed = shouldCollapse
            }, completionHandler: { [weak self] in
                self?.restoreSidebarWidthIfNeeded()
                self?.reportSidebarWidthIfNeeded(force: true)
            })
        } else {
            sidebarSplitItem.isCollapsed = shouldCollapse
            restoreSidebarWidthIfNeeded()
            reportSidebarWidthIfNeeded(force: true)
        }
    }

    private func applyPreviewPaneVisibility(animated: Bool) {
        let shouldCollapse = !viewModel.previewVisible
        guard previewSplitItem.isCollapsed != shouldCollapse else {
            return
        }

        if shouldCollapse {
            captureCurrentPreviewWidthIfNeeded()
        } else {
            previewPaneViewController.setPreferredFitViewportWidth(lastReportedPreviewWidth)
        }

        if animated {
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.18
                previewSplitItem.animator().isCollapsed = shouldCollapse
            }, completionHandler: { [weak self] in
                self?.reportPreviewWidthIfNeeded(force: true)
            })
        } else {
            previewSplitItem.isCollapsed = shouldCollapse
            reportPreviewWidthIfNeeded(force: true)
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

    private func applyPaneVisibility(leftVisible: Bool, rightVisible: Bool, animated: Bool) {
        let normalizedLeftVisible: Bool
        let normalizedRightVisible: Bool
        if !leftVisible, !rightVisible {
            normalizedLeftVisible = true
            normalizedRightVisible = false
        } else {
            normalizedLeftVisible = leftVisible
            normalizedRightVisible = rightVisible
        }

        setPaneVisibility(splitItem: leftSplitItem, visible: normalizedLeftVisible, animated: animated)
        setPaneVisibility(splitItem: rightSplitItem, visible: normalizedRightVisible, animated: animated)

        if !normalizedLeftVisible, viewModel.activePaneSide == .left {
            setActivePane(.right)
        } else if !normalizedRightVisible, viewModel.activePaneSide == .right {
            setActivePane(.left)
        }

        onPaneVisibilityChanged?(normalizedLeftVisible, normalizedRightVisible)
    }

    private func togglePaneVisibility(side: PaneSide, animated: Bool) {
        let leftVisible = !leftSplitItem.isCollapsed
        let rightVisible = !rightSplitItem.isCollapsed
        switch side {
        case .left:
            if leftVisible, !rightVisible {
                return
            }
            applyPaneVisibility(leftVisible: !leftVisible, rightVisible: rightVisible, animated: animated)
        case .right:
            if rightVisible, !leftVisible {
                return
            }
            applyPaneVisibility(leftVisible: leftVisible, rightVisible: !rightVisible, animated: animated)
        }
    }

    private func setPaneVisibility(splitItem: NSSplitViewItem, visible: Bool, animated: Bool) {
        let shouldCollapse = !visible
        guard splitItem.isCollapsed != shouldCollapse else {
            return
        }

        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.18
                splitItem.animator().isCollapsed = shouldCollapse
            }
        } else {
            splitItem.isCollapsed = shouldCollapse
        }
    }

    private func paneViewController(for side: PaneSide) -> FilePaneViewController {
        switch side {
        case .left:
            return leftPaneViewController
        case .right:
            return rightPaneViewController
        }
    }

    private func applyInitialSidebarWidthIfNeeded() {
        guard !hasAppliedInitialSidebarWidth else {
            return
        }

        hasAppliedInitialSidebarWidth = true
        if !sidebarSplitItem.isCollapsed, splitView.arrangedSubviews.count > 1 {
            splitView.setPosition(initialSidebarWidth, ofDividerAt: 0)
        }

        reportSidebarWidthIfNeeded(force: true)
    }

    private func restoreSidebarWidthIfNeeded() {
        guard !sidebarSplitItem.isCollapsed, splitView.arrangedSubviews.count > 1 else {
            return
        }

        splitView.setPosition(lastReportedSidebarWidth, ofDividerAt: 0)
    }

    private func reportSidebarWidthIfNeeded(force: Bool) {
        guard !sidebarSplitItem.isCollapsed else {
            return
        }

        let width = Self.clampedSidebarWidth(sidebarViewController.view.frame.width)
        guard force || abs(width - lastReportedSidebarWidth) >= 1 else {
            return
        }

        lastReportedSidebarWidth = width
        onSidebarWidthChanged?(width)
    }

    private func captureCurrentPreviewWidthIfNeeded() {
        guard !previewSplitItem.isCollapsed else {
            return
        }

        let width = max(previewPaneViewController.view.frame.width, previewSplitItem.minimumThickness)
        guard width > 0 else {
            return
        }

        lastReportedPreviewWidth = width
        previewPaneViewController.setPreferredFitViewportWidth(width)
    }

    private func reportPreviewWidthIfNeeded(force: Bool) {
        if previewSplitItem.isCollapsed {
            previewPaneViewController.setPreferredFitViewportWidth(lastReportedPreviewWidth)
            return
        }

        let width = max(previewPaneViewController.view.frame.width, previewSplitItem.minimumThickness)
        guard width > 0 else {
            return
        }

        guard force || abs(width - lastReportedPreviewWidth) >= 1 else {
            previewPaneViewController.setPreferredFitViewportWidth(lastReportedPreviewWidth)
            return
        }

        lastReportedPreviewWidth = width
        previewPaneViewController.setPreferredFitViewportWidth(width)
    }

    private static func clampedSidebarWidth(_ width: CGFloat) -> CGFloat {
        min(max(width, sidebarWidthRange.lowerBound), sidebarWidthRange.upperBound)
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
            self?.updateSidebarNavigationHistory()
        }
        viewModel.rightPane.onDirectoryChanged = { [weak self] url in
            self?.viewModel.visitHistoryService.recordVisit(to: url)
            self?.sidebarViewModel.reloadSections()
            self?.updateSidebarNavigationHistory()
        }
    }

    private func updateSidebarNavigationHistory() {
        let activePane = viewModel.activePane
        let history = activePane.navigationHistory
        sidebarViewModel.updateNavigationHistory(
            backStack: history.backStack,
            currentURL: activePane.paneState.currentDirectory,
            forwardStack: history.forwardStack,
            paneSide: viewModel.activePaneSide
        )
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
        let path = UserPaths.resolveBookmarkPath(result.path)
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) else {
            presentPathNotFoundAlert(path: path)
            return
        }

        let url = URL(fileURLWithPath: path).standardizedFileURL
        let destination = isDirectory.boolValue
            ? url
            : url.deletingLastPathComponent().standardizedFileURL

        navigateActivePane(to: destination)
    }

    private func resolveNavigationDestination(from rawInput: String) -> URL? {
        let sanitizedInput = stripSurroundingQuotes(from: rawInput.trimmingCharacters(in: .whitespacesAndNewlines))
        guard !sanitizedInput.isEmpty else {
            return nil
        }

        let expandedPath = (sanitizedInput as NSString).expandingTildeInPath
        let currentDirectory = viewModel.activePane.paneState.currentDirectory
        let rawURL: URL
        if expandedPath.hasPrefix("/") {
            rawURL = URL(fileURLWithPath: expandedPath)
        } else {
            rawURL = URL(fileURLWithPath: expandedPath, relativeTo: currentDirectory)
        }

        let normalizedURL = rawURL.standardizedFileURL
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: normalizedURL.path, isDirectory: &isDirectory) else {
            return nil
        }

        if isDirectory.boolValue {
            return normalizedURL
        }

        return normalizedURL.deletingLastPathComponent().standardizedFileURL
    }

    private func stripSurroundingQuotes(from value: String) -> String {
        guard value.count >= 2 else {
            return value
        }

        if (value.hasPrefix("\"") && value.hasSuffix("\"")) || (value.hasPrefix("'") && value.hasSuffix("'")) {
            return String(value.dropFirst().dropLast())
        }

        return value
    }

    private func navigateActivePane(to destination: URL) {
        let normalizedDestination = destination.standardizedFileURL
        Task { [weak self] in
            guard let self else {
                return
            }

            do {
                try await self.viewModel.securityScopedBookmarkService.startAccessing(normalizedDestination)
                await self.viewModel.securityScopedBookmarkService.stopAccessing(normalizedDestination)
                await MainActor.run {
                    self.viewModel.activePane.navigate(to: normalizedDestination)
                }
            } catch let bookmarkError as SecurityScopedBookmarkError {
                switch bookmarkError {
                case .bookmarkNotFound:
                    await MainActor.run {
                        self.presentAccessGrantPrompt(for: normalizedDestination)
                    }
                default:
                    await MainActor.run {
                        self.presentNavigationErrorAlert(for: normalizedDestination, error: bookmarkError)
                    }
                }
            } catch {
                await MainActor.run {
                    self.presentNavigationErrorAlert(for: normalizedDestination, error: error)
                }
            }
        }
    }

    private func presentPathNotFoundAlert(path: String) {
        presentErrorAlert(title: "Path not found", informativeText: path)
    }

    private func presentAccessGrantPrompt(for destination: URL) {
        let panel = NSOpenPanel()
        panel.title = "Grant Folder Access"
        panel.message = "Select the bookmark folder (or one of its parent folders) to allow navigation."
        panel.prompt = "Grant Access"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.directoryURL = destination

        guard panel.runModal() == .OK, let selectedURL = panel.url?.standardizedFileURL else {
            return
        }

        guard isSameOrDescendant(destination, of: selectedURL) else {
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = "Selected folder does not contain bookmark"
            alert.informativeText = "Choose \(destination.path) or one of its parent folders."
            alert.addButton(withTitle: "OK")
            alert.runModal()
            return
        }

        Task { [weak self] in
            guard let self else {
                return
            }

            do {
                try await self.viewModel.securityScopedBookmarkService.saveBookmark(for: selectedURL)
                await MainActor.run {
                    self.viewModel.activePane.navigate(to: destination)
                }
            } catch {
                await MainActor.run {
                    self.presentNavigationErrorAlert(for: selectedURL, error: error)
                }
            }
        }
    }

    private func presentNavigationErrorAlert(for destination: URL, error: Error) {
        presentErrorAlert(
            title: "Failed to open path",
            informativeText: "\(destination.path)\n\n\(error.localizedDescription)"
        )
    }

    private func presentBookmarkPermissionSaveError(for destination: URL, error: Error) {
        presentErrorAlert(
            title: "Bookmark saved without access permission",
            informativeText:
                "\(destination.path)\n\n" +
                "You can keep this bookmark, but navigation may fail until access is granted.\n\n" +
                error.localizedDescription
        )
    }

    private func presentErrorAlert(title: String, informativeText: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = title
        alert.informativeText = informativeText
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func isSameOrDescendant(_ child: URL, of parent: URL) -> Bool {
        let childPath = child.standardizedFileURL.resolvingSymlinksInPath().path
        let parentPath = parent.standardizedFileURL.resolvingSymlinksInPath().path

        if childPath == parentPath {
            return true
        }

        let normalizedParent = parentPath == "/" ? "/" : parentPath + "/"
        return childPath.hasPrefix(normalizedParent)
    }

    private func presentAddBookmarkAlert() {
        let targetURL: URL
        if let selectedItem = viewModel.activePane.selectedItem {
            targetURL = selectedItem.url.standardizedFileURL
        } else {
            targetURL = viewModel.activePane.paneState.currentDirectory.standardizedFileURL
        }
        let defaultDisplayName = targetURL.lastPathComponent.isEmpty
            ? targetURL.path
            : targetURL.lastPathComponent

        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "Add Bookmark"
        alert.informativeText = targetURL.path
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")

        let accessoryContainer = NSView(frame: NSRect(x: 0, y: 0, width: 340, height: 134))

        let groupPopup = NSPopUpButton(frame: NSRect(x: 0, y: 104, width: 340, height: 26), pullsDown: false)
        groupPopup.addItems(withTitles: bookmarksConfig.groups.map(\.name))
        groupPopup.addItem(withTitle: "New Group")
        let lastIndex = Self.lastSelectedBookmarkGroupIndex
        if lastIndex >= 0, lastIndex < groupPopup.numberOfItems {
            groupPopup.selectItem(at: lastIndex)
        }

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

        alert.window.initialFirstResponder = shortcutField

        guard alert.runModal() == .alertFirstButtonReturn else {
            return
        }

        let selectedGroupIndex = groupPopup.indexOfSelectedItem
        Self.lastSelectedBookmarkGroupIndex = selectedGroupIndex

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
                path: targetURL.path,
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

        bookmarksConfig.groups = groups

        do {
            try configManager.saveBookmarksConfig(bookmarksConfig)
            let bookmarkURL = URL(fileURLWithPath: entry.path, isDirectory: true).standardizedFileURL
            Task { [weak self] in
                guard let self else {
                    return
                }
                do {
                    try await self.viewModel.securityScopedBookmarkService.saveBookmark(for: bookmarkURL)
                } catch {
                    await MainActor.run {
                        self.presentBookmarkPermissionSaveError(for: bookmarkURL, error: error)
                    }
                }
            }
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

    // MARK: - Markdown Preview

    private func presentMarkdownPreview(for fileURL: URL) {
        markdownPreviewPanelController?.dismiss()

        guard let window = view.window else {
            return
        }

        let panel = MarkdownPreviewPanelController()
        panel.onDismiss = { [weak self] in
            self?.markdownPreviewPanelController = nil
            self?.focusActivePane()
        }

        let palette = currentFilerTheme.palette
        panel.showRelativeTo(window: window, fileURL: fileURL, palette: palette)
        markdownPreviewPanelController = panel
    }
}
