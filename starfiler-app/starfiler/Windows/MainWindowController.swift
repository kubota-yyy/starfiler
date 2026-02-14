import AppKit
import CryptoKit

final class MainWindowController: NSWindowController, NSWindowDelegate {
    private enum LaunchMetadata {
        static let observedConfigSnapshotsKey = "MainWindowController.observedConfigSnapshots"
    }

    private enum ObservedConfigFile: String, CaseIterable {
        case appConfig
        case bookmarks
        case keybindings
    }

    private struct ConfigFileSnapshot: Codable, Equatable {
        let exists: Bool
        let modificationDate: Date?
        let fileSize: UInt64?
        let contentDigest: String?
    }

    private let mainViewModel: MainViewModel
    private let configManager: ConfigManager
    private let fileManager: FileManager
    private let primaryConfigMonitor: any DirectoryMonitoring
    private let keybindingsConfigMonitor: any DirectoryMonitoring
    private let keybindingsConfigURL: URL?
    private var filerTheme: FilerTheme
    private var transparentBackground: Bool
    private var transparentBackgroundOpacity: CGFloat
    private var actionFeedbackEnabled: Bool
    private var spotlightSearchScope: SpotlightSearchScope
    private var fileIconSize: CGFloat
    private var leftPaneFileIconSize: CGFloat
    private var rightPaneFileIconSize: CGFloat
    private var sidebarFavoritesVisible: Bool
    private var sidebarRecentItemsLimit: Int
    private var sidebarWidth: CGFloat
    private var leftPaneVisible: Bool
    private var rightPaneVisible: Bool
    private var starEffectsEnabled: Bool
    private var terminalPanelVisible: Bool
    private var animationEffectSettings: AnimationEffectSettings
    private lazy var mainSplitViewController = MainSplitViewController(
        viewModel: mainViewModel,
        configManager: configManager,
        actionFeedbackEnabled: actionFeedbackEnabled,
        leftPaneFileIconSize: leftPaneFileIconSize,
        rightPaneFileIconSize: rightPaneFileIconSize,
        initialSidebarWidth: sidebarWidth,
        initialLeftPaneVisible: leftPaneVisible,
        initialRightPaneVisible: rightPaneVisible
    )
    private lazy var terminalPanelViewController = TerminalPanelViewController(
        listViewModel: mainViewModel.terminalSessionListViewModel
    )
    private lazy var mainContainerViewController = MainContainerViewController(
        mainSplitViewController: mainSplitViewController,
        terminalPanelViewController: terminalPanelViewController,
        terminalPanelVisible: terminalPanelVisible
    )
    private let appUndoManager = UndoManager()
    private var footerBaseStatusText: String
    private var footerItemCount: Int
    private var footerMarkedCount: Int
    private var footerContextText: String?
    private var observedConfigSnapshots: [ObservedConfigFile: ConfigFileSnapshot] = [:]

    init(
        fileSystemService: FileSystemProviding = FileSystemService(),
        securityScopedBookmarkService: any SecurityScopedBookmarkProviding = SecurityScopedBookmarkService.shared,
        initialDirectory: URL = UserPaths.homeDirectoryURL,
        fileManager: FileManager = .default,
        primaryConfigMonitor: any DirectoryMonitoring = DirectoryMonitor(),
        keybindingsConfigMonitor: any DirectoryMonitoring = DirectoryMonitor()
    ) {
        self.fileManager = fileManager
        self.primaryConfigMonitor = primaryConfigMonitor
        self.keybindingsConfigMonitor = keybindingsConfigMonitor
        self.keybindingsConfigURL = KeybindingManager.defaultUserConfigURL(fileManager: fileManager)
        let previousConfigSnapshots = Self.loadPersistedObservedConfigSnapshots()

        let configManager = ConfigManager()
        self.configManager = configManager

        Self.initializeDefaultBookmarksIfNeeded(configManager: configManager)

        let appConfig = configManager.loadAppConfig()
        let bookmarksConfig = configManager.loadBookmarksConfig()
        self.filerTheme = appConfig.filerTheme
        self.transparentBackground = appConfig.transparentBackground
        self.transparentBackgroundOpacity = min(max(CGFloat(appConfig.transparentBackgroundOpacity), 0.15), 1.0)
        self.actionFeedbackEnabled = appConfig.actionFeedbackEnabled
        self.spotlightSearchScope = appConfig.spotlightSearchScope
        self.fileIconSize = CGFloat(appConfig.fileIconSize)
        self.leftPaneFileIconSize = CGFloat(appConfig.leftPaneFileIconSize)
        self.rightPaneFileIconSize = CGFloat(appConfig.rightPaneFileIconSize)
        self.sidebarFavoritesVisible = appConfig.sidebarFavoritesVisible
        self.sidebarRecentItemsLimit = appConfig.sidebarRecentItemsLimit
        self.sidebarWidth = Self.initialSidebarWidth(appConfig: appConfig, bookmarksConfig: bookmarksConfig)
        self.leftPaneVisible = appConfig.leftPaneVisible
        self.rightPaneVisible = appConfig.rightPaneVisible
        self.starEffectsEnabled = appConfig.starEffectsEnabled
        self.animationEffectSettings = appConfig.animationEffectSettings
        self.terminalPanelVisible = appConfig.terminalPanelVisible
        let fallbackDirectory = initialDirectory.standardizedFileURL
        let leftDirectory = Self.resolveDirectory(path: appConfig.lastLeftPanePath, fallback: fallbackDirectory)
        let rightDirectory = Self.resolveDirectory(path: appConfig.lastRightPanePath, fallback: leftDirectory)

        let visitHistoryService = VisitHistoryService(configManager: configManager)
        let pinnedItemsService = PinnedItemsService(configManager: configManager)

        self.mainViewModel = MainViewModel(
            fileSystemService: fileSystemService,
            securityScopedBookmarkService: securityScopedBookmarkService,
            visitHistoryService: visitHistoryService,
            pinnedItemsService: pinnedItemsService,
            initialShowHiddenFiles: appConfig.showHiddenFiles,
            initialSortColumn: appConfig.defaultSortColumn,
            initialSortAscending: appConfig.defaultSortAscending,
            initialPreviewVisible: appConfig.previewPaneVisible,
            initialSidebarVisible: appConfig.sidebarVisible,
            initialTerminalPanelVisible: appConfig.terminalPanelVisible,
            initialSpotlightSearchScope: appConfig.spotlightSearchScope,
            initialLeftPaneDisplayMode: appConfig.leftPaneDisplayMode,
            initialRightPaneDisplayMode: appConfig.rightPaneDisplayMode,
            initialLeftPaneMediaRecursiveEnabled: appConfig.leftPaneMediaRecursiveEnabled,
            initialRightPaneMediaRecursiveEnabled: appConfig.rightPaneMediaRecursiveEnabled,
            initialLeftDirectory: leftDirectory,
            initialRightDirectory: rightDirectory
        )

        if appConfig.lastActivePane == "right" {
            self.mainViewModel.setActivePane(.right)
        }
        let activePane = self.mainViewModel.activePane
        self.footerBaseStatusText = activePane.paneState.currentDirectory.path
        self.footerItemCount = activePane.directoryContents.displayedItems.count
        self.footerMarkedCount = activePane.markedCount
        self.footerContextText = nil
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1100, height: 720),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )

        super.init(window: window)
        mainViewModel.undoManager = appUndoManager
        configureWindow()
        applyConfigChangesSinceLastLaunch(previousSnapshots: previousConfigSnapshots)
        Self.savePersistedObservedConfigSnapshots(currentObservedConfigSnapshots())
        startConfigMonitoring()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        primaryConfigMonitor.stopMonitoring()
        keybindingsConfigMonitor.stopMonitoring()
    }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        if let window {
            attachWindowControlButtons(to: window)
        }
        mainSplitViewController.focusActivePane()

        if starEffectsEnabled, animationEffectSettings.windowIntroAnimation, let contentView = window?.contentView {
            contentView.wantsLayer = true
            contentView.alphaValue = 0

            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.25
                ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
                contentView.animator().alphaValue = 1
            }, completionHandler: { [weak self] in
                guard let self, self.starEffectsEnabled, let layer = contentView.layer else { return }
                let palette = self.filerTheme.palette
                let center = CGPoint(x: layer.bounds.midX, y: layer.bounds.maxY - 20)
                StarSparkleAnimator.singleStar(in: layer, at: center, color: palette.starGlowColor, size: 14)
            })

            if let layer = contentView.layer {
                let scale = CABasicAnimation(keyPath: "transform.scale")
                scale.fromValue = 0.97
                scale.toValue = 1.0
                scale.duration = 0.25
                scale.timingFunction = CAMediaTimingFunction(name: .easeOut)
                layer.add(scale, forKey: "introScale")
            }
        }
    }

    func windowWillClose(_ notification: Notification) {
        persistAppConfig()
    }

    func windowDidBecomeMain(_ notification: Notification) {
        guard let window else {
            return
        }
        attachWindowControlButtons(to: window)
    }

    func windowDidEnterFullScreen(_ notification: Notification) {
        guard let window else {
            return
        }
        attachWindowControlButtons(to: window)
    }

    func windowDidExitFullScreen(_ notification: Notification) {
        guard let window else {
            return
        }
        attachWindowControlButtons(to: window)
    }

    func performAction(_ block: (MainViewModel) -> Void) {
        block(mainViewModel)
    }

    var currentFilerTheme: FilerTheme {
        filerTheme
    }

    var isTransparentBackgroundEnabled: Bool {
        transparentBackground
    }

    var currentTransparentBackgroundOpacity: CGFloat {
        transparentBackgroundOpacity
    }

    var isActionFeedbackEnabled: Bool {
        actionFeedbackEnabled
    }

    var currentSpotlightSearchScope: SpotlightSearchScope {
        spotlightSearchScope
    }

    var currentFileIconSize: CGFloat {
        fileIconSize
    }

    var currentSidebarRecentItemsLimit: Int {
        sidebarRecentItemsLimit
    }

    var isSidebarFavoritesVisible: Bool {
        sidebarFavoritesVisible
    }

    var isStarEffectsEnabled: Bool {
        starEffectsEnabled
    }

    var currentAnimationEffectSettings: AnimationEffectSettings {
        animationEffectSettings
    }

    func playShootingStarTestEffect(in targetWindow: NSWindow? = nil) {
        let destinationWindow = targetWindow ?? window
        guard let contentView = destinationWindow?.contentView else {
            return
        }
        contentView.wantsLayer = true
        guard let layer = contentView.layer else {
            return
        }

        let palette = filerTheme.palette
        StarSparkleAnimator.shootingStar(
            in: layer,
            accentColor: palette.starAccentColor,
            glowColor: palette.starGlowColor
        )
    }

    func updateFilerTheme(_ theme: FilerTheme) {
        guard filerTheme != theme else {
            return
        }

        filerTheme = theme
        applyCurrentAppearance()
        persistAppConfig()
    }

    func updateTransparentBackground(_ enabled: Bool) {
        guard transparentBackground != enabled else {
            return
        }

        transparentBackground = enabled
        applyCurrentAppearance()
        persistAppConfig()
    }

    func updateTransparentBackgroundOpacity(_ opacity: CGFloat) {
        let clampedOpacity = min(max(opacity, 0.15), 1.0)
        guard abs(transparentBackgroundOpacity - clampedOpacity) > 0.001 else {
            return
        }

        transparentBackgroundOpacity = clampedOpacity
        applyCurrentAppearance()
        persistAppConfig()
    }

    func updateActionFeedbackEnabled(_ enabled: Bool) {
        guard actionFeedbackEnabled != enabled else {
            return
        }

        actionFeedbackEnabled = enabled
        mainSplitViewController.setActionFeedbackEnabled(enabled)
        persistAppConfig()
    }

    func updateSpotlightSearchScope(_ scope: SpotlightSearchScope) {
        guard spotlightSearchScope != scope else {
            return
        }

        spotlightSearchScope = scope
        mainViewModel.setSpotlightSearchScope(scope)
        mainSplitViewController.setSpotlightSearchScope(scope)
        persistAppConfig()
    }

    func updateFileIconSize(_ size: CGFloat) {
        let clamped = min(max(size, 12), 40)
        guard abs(fileIconSize - clamped) > .ulpOfOne else {
            return
        }

        fileIconSize = clamped
        leftPaneFileIconSize = clamped
        rightPaneFileIconSize = clamped
        mainSplitViewController.setFileIconSize(clamped)
        persistAppConfig()
    }

    private func updatePaneFileIconSize(_ size: CGFloat, for side: PaneSide) {
        let clamped = min(max(size, 12), 40)
        switch side {
        case .left:
            guard abs(leftPaneFileIconSize - clamped) > .ulpOfOne else {
                return
            }
            leftPaneFileIconSize = clamped
        case .right:
            guard abs(rightPaneFileIconSize - clamped) > .ulpOfOne else {
                return
            }
            rightPaneFileIconSize = clamped
        }
        persistAppConfig()
    }

    func updateSidebarRecentItemsLimit(_ limit: Int) {
        let clampedLimit = min(
            max(limit, AppConfig.sidebarRecentItemsLimitRange.lowerBound),
            AppConfig.sidebarRecentItemsLimitRange.upperBound
        )
        guard sidebarRecentItemsLimit != clampedLimit else {
            return
        }

        sidebarRecentItemsLimit = clampedLimit
        persistAppConfig()
        mainSplitViewController.reloadSidebarSections()
    }

    func updateSidebarFavoritesVisible(_ visible: Bool) {
        guard sidebarFavoritesVisible != visible else {
            return
        }

        sidebarFavoritesVisible = visible
        persistAppConfig()
        mainSplitViewController.reloadSidebarSections()
    }

    func updateStarEffectsEnabled(_ enabled: Bool) {
        guard starEffectsEnabled != enabled else {
            return
        }

        starEffectsEnabled = enabled
        mainSplitViewController.setStarEffectsEnabled(enabled)
        mainContainerViewController.setStatusBarStarEffectsEnabled(enabled)
        persistAppConfig()
    }

    func updateAnimationEffectSettings(_ settings: AnimationEffectSettings) {
        guard animationEffectSettings != settings else {
            return
        }

        animationEffectSettings = settings
        mainSplitViewController.setAnimationEffectSettings(settings)
        mainContainerViewController.setStatusBarAnimationEffectSettings(settings)
        persistAppConfig()
    }

    func presentBatchRename() {
        mainSplitViewController.presentBatchRenameWindow()
    }

    func togglePreviewPane() {
        mainSplitViewController.togglePreviewPane()
    }

    func toggleSidebarPane() {
        mainSplitViewController.toggleSidebarPane()
    }

    func toggleLeftPane() {
        mainSplitViewController.toggleLeftPane()
    }

    func toggleRightPane() {
        mainSplitViewController.toggleRightPane()
    }

    func toggleSinglePane() {
        mainSplitViewController.toggleSinglePane()
    }

    func equalizePaneWidths() {
        mainSplitViewController.equalizePaneWidths()
    }

    func toggleTerminalPanel() {
        mainContainerViewController.toggleTerminalPanel()
        terminalPanelVisible = mainContainerViewController.isTerminalPanelVisible
        persistAppConfig()
    }

    func openSelectedItemInActivePane() {
        mainSplitViewController.openSelectedItemInActivePane()
    }

    func launchTerminalSession(command: TerminalSessionCommand) {
        let workingDirectory = mainViewModel.activePane.paneState.currentDirectory
        terminalPanelViewController.createSession(command: command, workingDirectory: workingDirectory)
    }

    func focusTerminalPanel() {
        terminalPanelViewController.focusActiveTerminal()
    }

    func reloadBookmarksConfig() {
        mainSplitViewController.reloadBookmarksConfig()
    }

    func reloadKeybindings() {
        mainSplitViewController.reloadKeybindings()
    }

    func presentGoToPathPrompt() {
        mainSplitViewController.presentGoToPathPrompt()
    }

    func requestDeleteFromActivePane() {
        mainSplitViewController.requestDeleteFromActivePane()
    }

    private func handleTerminalAction(_ action: KeyAction) {
        switch action {
        case .launchClaude:
            launchTerminalSession(command: .claude)
        case .launchCodex:
            launchTerminalSession(command: .codex)
        case .toggleTerminalPanel:
            toggleTerminalPanel()
        default:
            break
        }
    }

    private func configureWindow() {
        guard let window else {
            return
        }

        window.title = ""
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.styleMask.insert(.fullSizeContentView)
        window.toolbar = nil
        window.isMovableByWindowBackground = true
        window.minSize = NSSize(width: 800, height: 600)
        window.setFrameAutosaveName("MainWindow")
        window.delegate = self

        if !window.setFrameUsingName("MainWindow") {
            window.center()
        }

        mainSplitViewController.onSpotlightSearchScopeChanged = { [weak self] scope in
            self?.updateSpotlightSearchScope(scope)
        }
        mainSplitViewController.onStatusChanged = { [weak self] statusText, itemCount, markedCount in
            self?.updateFooterBaseStatus(statusText, itemCount: itemCount, markedCount: markedCount)
        }
        mainSplitViewController.onStatusContextTextChanged = { [weak self] text in
            self?.updateFooterContextText(text)
        }
        mainSplitViewController.onPaneVisibilityChanged = { [weak self] leftVisible, rightVisible in
            self?.leftPaneVisible = leftVisible
            self?.rightPaneVisible = rightVisible
            self?.persistAppConfig()
        }
        mainSplitViewController.onSidebarWidthChanged = { [weak self] width in
            self?.handleSidebarWidthChanged(width)
        }
        mainSplitViewController.onFileIconSizeChanged = { [weak self] side, size in
            self?.updatePaneFileIconSize(size, for: side)
        }
        mainSplitViewController.onTerminalAction = { [weak self] action in
            self?.handleTerminalAction(action)
        }

        mainViewModel.terminalSessionListViewModel.onPanelVisibilityChanged = { [weak self] visible in
            guard let self else { return }
            if visible {
                self.mainContainerViewController.showTerminalPanel()
            } else {
                self.mainContainerViewController.hideTerminalPanel()
            }
            self.terminalPanelVisible = visible
            self.persistAppConfig()
        }

        applyCurrentAppearance()
        mainSplitViewController.setStarEffectsEnabled(starEffectsEnabled)
        mainSplitViewController.setAnimationEffectSettings(animationEffectSettings)
        mainContainerViewController.setStatusBarStarEffectsEnabled(starEffectsEnabled)
        mainContainerViewController.setStatusBarAnimationEffectSettings(animationEffectSettings)
        window.contentViewController = mainContainerViewController
        renderFooterStatus()
        attachWindowControlButtons(to: window)
    }

    private func attachWindowControlButtons(to window: NSWindow) {
        let buttonTypes: [NSWindow.ButtonType] = [.closeButton, .miniaturizeButton, .zoomButton]
        let buttons = buttonTypes.compactMap { window.standardWindowButton($0) }
        guard buttons.count == buttonTypes.count else {
            return
        }

        mainSplitViewController.embedWindowControlButtons(buttons)
    }

    private var backgroundOpacity: CGFloat {
        transparentBackground ? transparentBackgroundOpacity : 1.0
    }

    private func applyCurrentAppearance() {
        let opacity = backgroundOpacity

        mainSplitViewController.setFilerTheme(filerTheme, backgroundOpacity: opacity)
        mainContainerViewController.applyStatusBarTheme(filerTheme, backgroundOpacity: opacity)

        if let window {
            window.isOpaque = !transparentBackground
            if transparentBackground {
                window.backgroundColor = .clear
            } else {
                window.backgroundColor = filerTheme.palette.windowBackgroundColor
            }
            window.hasShadow = true
        }
    }

    private func updateFooterBaseStatus(_ text: String, itemCount: Int, markedCount: Int) {
        footerBaseStatusText = text
        footerItemCount = itemCount
        footerMarkedCount = markedCount
        renderFooterStatus()
    }

    private func updateFooterContextText(_ text: String?) {
        footerContextText = text
        renderFooterStatus()
    }

    private func renderFooterStatus() {
        let primaryText: String
        if let footerContextText, !footerContextText.isEmpty {
            primaryText = footerContextText
        } else {
            primaryText = footerBaseStatusText
        }

        mainContainerViewController.updateStatusBar(
            primaryText: primaryText,
            itemCount: footerItemCount,
            markedCount: footerMarkedCount
        )
    }

    private func startConfigMonitoring() {
        observedConfigSnapshots = currentObservedConfigSnapshots()

        primaryConfigMonitor.startMonitoring(url: configManager.configDirectory) { [weak self] in
            self?.handleObservedConfigDirectoryChange()
        }

        guard let keybindingsConfigURL else {
            return
        }

        let keybindingsDirectory = keybindingsConfigURL.deletingLastPathComponent().standardizedFileURL
        let primaryDirectory = configManager.configDirectory.standardizedFileURL
        guard keybindingsDirectory.path != primaryDirectory.path else {
            return
        }

        keybindingsConfigMonitor.startMonitoring(url: keybindingsDirectory) { [weak self] in
            self?.handleObservedConfigDirectoryChange()
        }
    }

    private func handleObservedConfigDirectoryChange() {
        let changedFiles = refreshObservedConfigSnapshots()
        guard !changedFiles.isEmpty else {
            return
        }

        if changedFiles.contains(.appConfig) {
            applyAppConfigFromDiskWithoutPersisting()
        }
        if changedFiles.contains(.bookmarks) {
            mainSplitViewController.reloadBookmarksConfig()
        }
        if changedFiles.contains(.keybindings) {
            mainSplitViewController.reloadKeybindings()
        }
    }

    private func applyAppConfigFromDiskWithoutPersisting() {
        let appConfig = configManager.loadAppConfig()

        let clampedOpacity = min(max(CGFloat(appConfig.transparentBackgroundOpacity), 0.15), 1.0)
        if filerTheme != appConfig.filerTheme
            || transparentBackground != appConfig.transparentBackground
            || abs(transparentBackgroundOpacity - clampedOpacity) > 0.001
        {
            filerTheme = appConfig.filerTheme
            transparentBackground = appConfig.transparentBackground
            transparentBackgroundOpacity = clampedOpacity
            applyCurrentAppearance()
        }

        if actionFeedbackEnabled != appConfig.actionFeedbackEnabled {
            actionFeedbackEnabled = appConfig.actionFeedbackEnabled
            mainSplitViewController.setActionFeedbackEnabled(actionFeedbackEnabled)
        }

        if spotlightSearchScope != appConfig.spotlightSearchScope {
            spotlightSearchScope = appConfig.spotlightSearchScope
            mainSplitViewController.setSpotlightSearchScope(spotlightSearchScope)
        }

        if mainViewModel.leftPane.directoryContents.showHiddenFiles != appConfig.showHiddenFiles {
            mainViewModel.leftPane.setShowHiddenFiles(appConfig.showHiddenFiles)
        }
        if mainViewModel.rightPane.directoryContents.showHiddenFiles != appConfig.showHiddenFiles {
            mainViewModel.rightPane.setShowHiddenFiles(appConfig.showHiddenFiles)
        }

        let sortDescriptor = Self.sortDescriptor(
            from: appConfig.defaultSortColumn,
            ascending: appConfig.defaultSortAscending
        )
        if mainViewModel.leftPane.directoryContents.sortDescriptor != sortDescriptor {
            mainViewModel.leftPane.setSortDescriptor(sortDescriptor)
        }
        if mainViewModel.rightPane.directoryContents.sortDescriptor != sortDescriptor {
            mainViewModel.rightPane.setSortDescriptor(sortDescriptor)
        }

        if mainViewModel.leftPane.displayMode != appConfig.leftPaneDisplayMode {
            mainViewModel.leftPane.setDisplayMode(appConfig.leftPaneDisplayMode)
        }
        if mainViewModel.rightPane.displayMode != appConfig.rightPaneDisplayMode {
            mainViewModel.rightPane.setDisplayMode(appConfig.rightPaneDisplayMode)
        }
        if mainViewModel.leftPane.mediaRecursiveEnabled != appConfig.leftPaneMediaRecursiveEnabled {
            mainViewModel.leftPane.setMediaRecursiveEnabled(appConfig.leftPaneMediaRecursiveEnabled)
        }
        if mainViewModel.rightPane.mediaRecursiveEnabled != appConfig.rightPaneMediaRecursiveEnabled {
            mainViewModel.rightPane.setMediaRecursiveEnabled(appConfig.rightPaneMediaRecursiveEnabled)
        }

        let clampedGlobalIconSize = min(max(CGFloat(appConfig.fileIconSize), 12), 40)
        if abs(fileIconSize - clampedGlobalIconSize) > .ulpOfOne {
            fileIconSize = clampedGlobalIconSize
        }

        let clampedLeftIconSize = min(max(CGFloat(appConfig.leftPaneFileIconSize), 12), 40)
        if abs(leftPaneFileIconSize - clampedLeftIconSize) > .ulpOfOne {
            leftPaneFileIconSize = clampedLeftIconSize
            mainSplitViewController.setFileIconSize(clampedLeftIconSize, for: .left)
        }

        let clampedRightIconSize = min(max(CGFloat(appConfig.rightPaneFileIconSize), 12), 40)
        if abs(rightPaneFileIconSize - clampedRightIconSize) > .ulpOfOne {
            rightPaneFileIconSize = clampedRightIconSize
            mainSplitViewController.setFileIconSize(clampedRightIconSize, for: .right)
        }

        let clampedSidebarRecentItemsLimit = min(
            max(appConfig.sidebarRecentItemsLimit, AppConfig.sidebarRecentItemsLimitRange.lowerBound),
            AppConfig.sidebarRecentItemsLimitRange.upperBound
        )
        var requiresSidebarReload = false
        if sidebarFavoritesVisible != appConfig.sidebarFavoritesVisible {
            sidebarFavoritesVisible = appConfig.sidebarFavoritesVisible
            requiresSidebarReload = true
        }
        if sidebarRecentItemsLimit != clampedSidebarRecentItemsLimit {
            sidebarRecentItemsLimit = clampedSidebarRecentItemsLimit
            requiresSidebarReload = true
        }
        if requiresSidebarReload {
            mainSplitViewController.reloadSidebarSections()
        }

        if starEffectsEnabled != appConfig.starEffectsEnabled {
            starEffectsEnabled = appConfig.starEffectsEnabled
            mainSplitViewController.setStarEffectsEnabled(starEffectsEnabled)
            mainContainerViewController.setStatusBarStarEffectsEnabled(starEffectsEnabled)
        }

        if animationEffectSettings != appConfig.animationEffectSettings {
            animationEffectSettings = appConfig.animationEffectSettings
            mainSplitViewController.setAnimationEffectSettings(animationEffectSettings)
            mainContainerViewController.setStatusBarAnimationEffectSettings(animationEffectSettings)
        }
    }

    private func applyConfigChangesSinceLastLaunch(previousSnapshots: [ObservedConfigFile: ConfigFileSnapshot]) {
        guard !previousSnapshots.isEmpty else {
            return
        }

        let changedFiles = changedObservedConfigFiles(
            previousSnapshots: previousSnapshots,
            latestSnapshots: currentObservedConfigSnapshots()
        )
        guard !changedFiles.isEmpty else {
            return
        }

        if changedFiles.contains(.appConfig) {
            applyAppConfigFromDiskWithoutPersisting()
        }
        if changedFiles.contains(.bookmarks) {
            mainSplitViewController.reloadBookmarksConfig()
        }
        if changedFiles.contains(.keybindings) {
            mainSplitViewController.reloadKeybindings()
        }
    }

    private func changedObservedConfigFiles(
        previousSnapshots: [ObservedConfigFile: ConfigFileSnapshot],
        latestSnapshots: [ObservedConfigFile: ConfigFileSnapshot]
    ) -> Set<ObservedConfigFile> {
        let allFiles = Set(previousSnapshots.keys).union(latestSnapshots.keys)
        return Set(allFiles.filter { previousSnapshots[$0] != latestSnapshots[$0] })
    }

    private func refreshObservedConfigSnapshots() -> Set<ObservedConfigFile> {
        let latestSnapshots = currentObservedConfigSnapshots()
        let changedFiles = changedObservedConfigFiles(
            previousSnapshots: observedConfigSnapshots,
            latestSnapshots: latestSnapshots
        )

        observedConfigSnapshots = latestSnapshots
        return changedFiles
    }

    private func currentObservedConfigSnapshots() -> [ObservedConfigFile: ConfigFileSnapshot] {
        let observedURLs = observedConfigURLs
        return Dictionary(uniqueKeysWithValues: observedURLs.map { file, url in
            (file, configFileSnapshot(for: url))
        })
    }

    private var observedConfigURLs: [ObservedConfigFile: URL] {
        var urls: [ObservedConfigFile: URL] = [
            .appConfig: configManager.appConfigURL,
            .bookmarks: configManager.bookmarksConfigURL,
        ]

        if let keybindingsConfigURL {
            urls[.keybindings] = keybindingsConfigURL
        }

        return urls
    }

    private func configFileSnapshot(for url: URL) -> ConfigFileSnapshot {
        let path = url.standardizedFileURL.path
        guard fileManager.fileExists(atPath: path),
              let attributes = try? fileManager.attributesOfItem(atPath: path)
        else {
            return ConfigFileSnapshot(exists: false, modificationDate: nil, fileSize: nil, contentDigest: nil)
        }

        let modificationDate = attributes[.modificationDate] as? Date
        let fileSize = (attributes[.size] as? NSNumber)?.uint64Value
        let contentDigest = Self.sha256Hex(of: url)
        return ConfigFileSnapshot(
            exists: true,
            modificationDate: modificationDate,
            fileSize: fileSize,
            contentDigest: contentDigest
        )
    }

    private func persistAppConfig() {
        if mainSplitViewController.isViewLoaded {
            sidebarWidth = Self.clampedSidebarWidth(mainSplitViewController.currentSidebarWidth())
        }

        let activeSortDescriptor = mainViewModel.activePane.directoryContents.sortDescriptor
        let appConfig = AppConfig(
            showHiddenFiles: mainViewModel.activePane.directoryContents.showHiddenFiles,
            defaultSortColumn: Self.sortColumn(from: activeSortDescriptor.column),
            defaultSortAscending: activeSortDescriptor.ascending,
            previewPaneVisible: mainViewModel.previewVisible,
            sidebarVisible: mainViewModel.sidebarVisible,
            lastLeftPanePath: mainViewModel.leftPane.paneState.currentDirectory.path,
            lastRightPanePath: mainViewModel.rightPane.paneState.currentDirectory.path,
            lastActivePane: mainViewModel.activePaneSide == .left ? "left" : "right",
            filerTheme: filerTheme,
            transparentBackground: transparentBackground,
            transparentBackgroundOpacity: Double(transparentBackgroundOpacity),
            actionFeedbackEnabled: actionFeedbackEnabled,
            spotlightSearchScope: spotlightSearchScope,
            fileIconSize: Double(fileIconSize),
            leftPaneFileIconSize: Double(leftPaneFileIconSize),
            rightPaneFileIconSize: Double(rightPaneFileIconSize),
            sidebarFavoritesVisible: sidebarFavoritesVisible,
            sidebarRecentItemsLimit: sidebarRecentItemsLimit,
            sidebarWidth: Double(sidebarWidth),
            leftPaneDisplayMode: mainViewModel.leftPane.displayMode,
            rightPaneDisplayMode: mainViewModel.rightPane.displayMode,
            leftPaneMediaRecursiveEnabled: mainViewModel.leftPane.mediaRecursiveEnabled,
            rightPaneMediaRecursiveEnabled: mainViewModel.rightPane.mediaRecursiveEnabled,
            leftPaneVisible: leftPaneVisible,
            rightPaneVisible: rightPaneVisible,
            starEffectsEnabled: starEffectsEnabled,
            animationEffectSettings: animationEffectSettings,
            terminalPanelVisible: terminalPanelVisible,
            terminalPanelHeight: Double(mainContainerViewController.terminalPanelHeight)
        )

        try? configManager.saveAppConfig(appConfig)
    }

    private static func resolveDirectory(path: String, fallback: URL) -> URL {
        let resolvedURL = URL(fileURLWithPath: path, isDirectory: true).standardizedFileURL

        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: resolvedURL.path, isDirectory: &isDirectory), isDirectory.boolValue {
            return resolvedURL
        }

        return fallback
    }

    private static func initializeDefaultBookmarksIfNeeded(configManager: ConfigManager) {
        let existingConfig = configManager.loadBookmarksConfig()
        guard existingConfig.groups.isEmpty else {
            return
        }

        let defaultConfig = BookmarksConfig.withDefaults()
        try? configManager.saveBookmarksConfig(defaultConfig)
    }

    private static func sortColumn(from column: DirectoryContents.SortDescriptor.Column) -> AppConfig.SortColumn {
        switch column {
        case .name:
            return .name
        case .size:
            return .size
        case .date:
            return .date
        case .selection:
            return .selection
        }
    }

    private static func sortDescriptor(
        from column: AppConfig.SortColumn,
        ascending: Bool
    ) -> DirectoryContents.SortDescriptor {
        switch column {
        case .name:
            return .name(ascending: ascending)
        case .size:
            return .size(ascending: ascending)
        case .date:
            return .date(ascending: ascending)
        case .selection:
            return .selection(ascending: ascending)
        }
    }

    private static func loadPersistedObservedConfigSnapshots() -> [ObservedConfigFile: ConfigFileSnapshot] {
        guard let data = UserDefaults.standard.data(forKey: LaunchMetadata.observedConfigSnapshotsKey),
              let decoded = try? JSONDecoder().decode([String: ConfigFileSnapshot].self, from: data)
        else {
            return [:]
        }

        return decoded.reduce(into: [:]) { result, pair in
            guard let file = ObservedConfigFile(rawValue: pair.key) else {
                return
            }
            result[file] = pair.value
        }
    }

    private static func savePersistedObservedConfigSnapshots(_ snapshots: [ObservedConfigFile: ConfigFileSnapshot]) {
        let payload = snapshots.reduce(into: [String: ConfigFileSnapshot]()) { result, pair in
            result[pair.key.rawValue] = pair.value
        }
        guard let data = try? JSONEncoder().encode(payload) else {
            return
        }
        UserDefaults.standard.set(data, forKey: LaunchMetadata.observedConfigSnapshotsKey)
    }

    private static func sha256Hex(of url: URL) -> String? {
        guard let data = try? Data(contentsOf: url) else {
            return nil
        }
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private func handleSidebarWidthChanged(_ width: CGFloat) {
        let clamped = Self.clampedSidebarWidth(width)
        guard abs(sidebarWidth - clamped) >= 1 else {
            return
        }

        sidebarWidth = clamped
        persistAppConfig()
    }

    private static func clampedSidebarWidth(_ value: CGFloat) -> CGFloat {
        min(max(value, CGFloat(AppConfig.sidebarWidthRange.lowerBound)), CGFloat(AppConfig.sidebarWidthRange.upperBound))
    }

    private static func initialSidebarWidth(appConfig: AppConfig, bookmarksConfig: BookmarksConfig) -> CGFloat {
        let configuredWidth = Self.clampedSidebarWidth(CGFloat(appConfig.sidebarWidth))
        let defaultWidth = CGFloat(AppConfig.defaultSidebarWidth)
        guard abs(configuredWidth - defaultWidth) < 1 else {
            return configuredWidth
        }

        let autoWidth = recommendedSidebarWidth(
            bookmarksConfig: bookmarksConfig,
            sidebarFavoritesVisible: appConfig.sidebarFavoritesVisible
        )
        return max(configuredWidth, autoWidth)
    }

    private static func recommendedSidebarWidth(bookmarksConfig: BookmarksConfig, sidebarFavoritesVisible: Bool) -> CGFloat {
        guard sidebarFavoritesVisible else {
            return Self.clampedSidebarWidth(CGFloat(AppConfig.defaultSidebarWidth))
        }

        let defaultGroup = bookmarksConfig.groups.first(where: \.isDefault)
        let title = defaultGroup?.name ?? "Favorites"
        let entries = defaultGroup?.entries.isEmpty == false ? defaultGroup?.entries ?? [] : fallbackFavoriteEntries()
        guard !entries.isEmpty else {
            return Self.clampedSidebarWidth(CGFloat(AppConfig.defaultSidebarWidth))
        }

        let titleFont = NSFont.systemFont(ofSize: 11, weight: .bold)
        let entryFont = NSFont.systemFont(ofSize: 13)
        let shortcutFont = NSFont.monospacedSystemFont(ofSize: 10, weight: .regular)
        let headerPadding: CGFloat = 22
        let entryBasePadding: CGFloat = 42
        let shortcutSpacing: CGFloat = 4
        let safetyPadding: CGFloat = 18

        var requiredWidth = textWidth(title, font: titleFont) + headerPadding
        for entry in entries {
            let displayName = favoriteDisplayName(for: entry)
            let shortcutHint = BookmarkShortcut.hint(
                groupShortcut: nil,
                entryShortcut: entry.shortcutKey,
                isDefaultGroup: true
            )
            let shortcutWidth: CGFloat
            if let shortcutHint, !shortcutHint.isEmpty {
                shortcutWidth = shortcutSpacing + textWidth(shortcutHint, font: shortcutFont)
            } else {
                shortcutWidth = 0
            }

            let rowWidth = entryBasePadding + textWidth(displayName, font: entryFont) + shortcutWidth
            requiredWidth = max(requiredWidth, rowWidth)
        }

        return Self.clampedSidebarWidth(ceil(requiredWidth + safetyPadding))
    }

    private static func fallbackFavoriteEntries() -> [BookmarkEntry] {
        BookmarksConfig.withDefaults().groups.first(where: \.isDefault)?.entries ?? []
    }

    private static func favoriteDisplayName(for entry: BookmarkEntry) -> String {
        let trimmed = entry.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            return trimmed
        }

        let resolvedPath = UserPaths.resolveBookmarkPath(entry.path)
        let lastPathComponent = URL(fileURLWithPath: resolvedPath).lastPathComponent
        return lastPathComponent.isEmpty ? resolvedPath : lastPathComponent
    }

    private static func textWidth(_ text: String, font: NSFont) -> CGFloat {
        guard !text.isEmpty else {
            return 0
        }

        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        return ceil((text as NSString).size(withAttributes: attributes).width)
    }
}
