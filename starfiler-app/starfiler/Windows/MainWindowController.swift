import AppKit

final class MainWindowController: NSWindowController, NSWindowDelegate {
    private let mainViewModel: MainViewModel
    private let configManager: ConfigManager
    private var filerTheme: FilerTheme
    private var transparentBackground: Bool
    private var transparentBackgroundOpacity: CGFloat
    private var actionFeedbackEnabled: Bool
    private var spotlightSearchScope: SpotlightSearchScope
    private var fileIconSize: CGFloat
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
        fileIconSize: fileIconSize,
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

    init(
        fileSystemService: FileSystemProviding = FileSystemService(),
        securityScopedBookmarkService: any SecurityScopedBookmarkProviding = SecurityScopedBookmarkService.shared,
        initialDirectory: URL = UserPaths.homeDirectoryURL
    ) {
        let configManager = ConfigManager()
        self.configManager = configManager

        Self.initializeDefaultBookmarksIfNeeded(configManager: configManager)

        let appConfig = configManager.loadAppConfig()
        self.filerTheme = appConfig.filerTheme
        self.transparentBackground = appConfig.transparentBackground
        self.transparentBackgroundOpacity = min(max(CGFloat(appConfig.transparentBackgroundOpacity), 0.15), 1.0)
        self.actionFeedbackEnabled = appConfig.actionFeedbackEnabled
        self.spotlightSearchScope = appConfig.spotlightSearchScope
        self.fileIconSize = CGFloat(appConfig.fileIconSize)
        self.sidebarFavoritesVisible = appConfig.sidebarFavoritesVisible
        self.sidebarRecentItemsLimit = appConfig.sidebarRecentItemsLimit
        self.sidebarWidth = Self.clampedSidebarWidth(CGFloat(appConfig.sidebarWidth))
        self.leftPaneVisible = appConfig.leftPaneVisible
        self.rightPaneVisible = appConfig.rightPaneVisible
        self.starEffectsEnabled = appConfig.starEffectsEnabled
        self.animationEffectSettings = appConfig.animationEffectSettings
        self.terminalPanelVisible = appConfig.terminalPanelVisible
        let fallbackDirectory = initialDirectory.standardizedFileURL
        let leftDirectory = Self.resolveDirectory(path: appConfig.lastLeftPanePath, fallback: fallbackDirectory)
        let rightDirectory = Self.resolveDirectory(path: appConfig.lastRightPanePath, fallback: leftDirectory)

        let visitHistoryService = VisitHistoryService(configManager: configManager)

        self.mainViewModel = MainViewModel(
            fileSystemService: fileSystemService,
            securityScopedBookmarkService: securityScopedBookmarkService,
            visitHistoryService: visitHistoryService,
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
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1100, height: 720),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )

        super.init(window: window)
        mainViewModel.undoManager = appUndoManager
        configureWindow()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
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
        mainSplitViewController.setFileIconSize(clamped)
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
        persistAppConfig()
    }

    func updateAnimationEffectSettings(_ settings: AnimationEffectSettings) {
        guard animationEffectSettings != settings else {
            return
        }

        animationEffectSettings = settings
        mainSplitViewController.setAnimationEffectSettings(settings)
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
        mainSplitViewController.onPaneVisibilityChanged = { [weak self] leftVisible, rightVisible in
            self?.leftPaneVisible = leftVisible
            self?.rightPaneVisible = rightVisible
            self?.persistAppConfig()
        }
        mainSplitViewController.onSidebarWidthChanged = { [weak self] width in
            self?.handleSidebarWidthChanged(width)
        }
        mainSplitViewController.onFileIconSizeChanged = { [weak self] size in
            self?.updateFileIconSize(size)
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
        window.contentViewController = mainContainerViewController
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
}
