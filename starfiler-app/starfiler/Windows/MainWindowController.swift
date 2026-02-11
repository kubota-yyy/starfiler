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
    private var imagePreviewRecursiveMode: Bool
    private lazy var mainSplitViewController = MainSplitViewController(
        viewModel: mainViewModel,
        configManager: configManager,
        actionFeedbackEnabled: actionFeedbackEnabled,
        fileIconSize: fileIconSize
    )
    private let statusBarView = StatusBarView()
    private let appUndoManager = UndoManager()
    private weak var containerView: NSView?

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
        self.imagePreviewRecursiveMode = appConfig.imagePreviewRecursiveMode
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
            initialSpotlightSearchScope: appConfig.spotlightSearchScope,
            initialImagePreviewRecursiveEnabled: appConfig.imagePreviewRecursiveMode,
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
        mainSplitViewController.focusActivePane()
    }

    func windowWillClose(_ notification: Notification) {
        persistAppConfig()
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

    func presentBatchRename() {
        mainSplitViewController.presentBatchRenameWindow()
    }

    func presentSyncWindow() {
        mainSplitViewController.presentSyncWindow()
    }

    func togglePreviewPane() {
        mainSplitViewController.togglePreviewPane()
    }

    func toggleSidebarPane() {
        mainSplitViewController.toggleSidebarPane()
    }

    func reloadBookmarksConfig() {
        mainSplitViewController.reloadBookmarksConfig()
    }

    func reloadKeybindings() {
        mainSplitViewController.reloadKeybindings()
    }

    private func configureWindow() {
        guard let window else {
            return
        }

        window.title = ""
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.styleMask.insert(.fullSizeContentView)
        window.isMovableByWindowBackground = true
        window.minSize = NSSize(width: 800, height: 600)
        window.setFrameAutosaveName("MainWindow")
        window.delegate = self

        if !window.setFrameUsingName("MainWindow") {
            window.center()
        }

        let containerViewController = NSViewController()
        let containerView = NSView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.wantsLayer = true
        containerViewController.view = containerView
        self.containerView = containerView

        containerViewController.addChild(mainSplitViewController)
        let splitView = mainSplitViewController.view
        splitView.translatesAutoresizingMaskIntoConstraints = false

        containerView.addSubview(splitView)
        containerView.addSubview(statusBarView)

        NSLayoutConstraint.activate([
            splitView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            splitView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            splitView.topAnchor.constraint(equalTo: containerView.safeAreaLayoutGuide.topAnchor),
            splitView.bottomAnchor.constraint(equalTo: statusBarView.topAnchor),

            statusBarView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            statusBarView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            statusBarView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])

        mainSplitViewController.onStatusChanged = { [weak self] path, itemCount, markedCount in
            self?.statusBarView.update(path: path, itemCount: itemCount, markedCount: markedCount)
        }
        mainSplitViewController.onSpotlightSearchScopeChanged = { [weak self] scope in
            self?.updateSpotlightSearchScope(scope)
        }
        mainSplitViewController.onImagePreviewRecursiveModeChanged = { [weak self] enabled in
            self?.imagePreviewRecursiveMode = enabled
            self?.persistAppConfig()
        }
        statusBarView.update(
            path: mainViewModel.activePane.paneState.currentDirectory.path,
            itemCount: mainViewModel.activePane.directoryContents.displayedItems.count,
            markedCount: mainViewModel.activePane.markedCount
        )

        applyCurrentAppearance()
        window.contentViewController = containerViewController
    }

    private var backgroundOpacity: CGFloat {
        transparentBackground ? transparentBackgroundOpacity : 1.0
    }

    private func applyCurrentAppearance() {
        let palette = filerTheme.palette
        let opacity = backgroundOpacity

        mainSplitViewController.setFilerTheme(filerTheme, backgroundOpacity: opacity)
        statusBarView.applyTheme(filerTheme, backgroundOpacity: opacity)

        containerView?.layer?.backgroundColor = palette.windowBackgroundColor.applyingBackgroundOpacity(opacity).cgColor

        if let window {
            window.isOpaque = !transparentBackground
            if transparentBackground {
                window.backgroundColor = .clear
            } else {
                window.backgroundColor = palette.windowBackgroundColor
            }
            window.hasShadow = true
        }
    }

    private func persistAppConfig() {
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
            imagePreviewRecursiveMode: imagePreviewRecursiveMode
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
}
