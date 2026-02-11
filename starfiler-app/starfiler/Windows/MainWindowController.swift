import AppKit

final class MainWindowController: NSWindowController, NSWindowDelegate {
    private let mainViewModel: MainViewModel
    private let configManager: ConfigManager
    private var filerTheme: FilerTheme
    private lazy var mainSplitViewController = MainSplitViewController(viewModel: mainViewModel, configManager: configManager)
    private let statusBarView = StatusBarView()
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

    func updateFilerTheme(_ theme: FilerTheme) {
        guard filerTheme != theme else {
            return
        }

        filerTheme = theme
        mainSplitViewController.setFilerTheme(theme)
        persistAppConfig()
    }

    func presentBatchRename() {
        mainSplitViewController.presentBatchRenameWindow()
    }

    func presentSyncWindow() {
        mainSplitViewController.presentSyncWindow()
    }

    private func configureWindow() {
        guard let window else {
            return
        }

        window.title = "starfiler"
        window.minSize = NSSize(width: 800, height: 600)
        window.setFrameAutosaveName("MainWindow")
        window.delegate = self

        if !window.setFrameUsingName("MainWindow") {
            window.center()
        }

        let containerViewController = NSViewController()
        let containerView = NSView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerViewController.view = containerView

        containerViewController.addChild(mainSplitViewController)
        mainSplitViewController.setFilerTheme(filerTheme)
        let splitView = mainSplitViewController.view
        splitView.translatesAutoresizingMaskIntoConstraints = false

        containerView.addSubview(splitView)
        containerView.addSubview(statusBarView)

        NSLayoutConstraint.activate([
            splitView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            splitView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            splitView.topAnchor.constraint(equalTo: containerView.topAnchor),
            splitView.bottomAnchor.constraint(equalTo: statusBarView.topAnchor),

            statusBarView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            statusBarView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            statusBarView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])

        mainSplitViewController.onStatusChanged = { [weak self] path, itemCount, markedCount in
            self?.statusBarView.update(path: path, itemCount: itemCount, markedCount: markedCount)
        }
        statusBarView.update(
            path: mainViewModel.activePane.paneState.currentDirectory.path,
            itemCount: mainViewModel.activePane.directoryContents.displayedItems.count,
            markedCount: mainViewModel.activePane.markedCount
        )

        window.contentViewController = containerViewController
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
            filerTheme: filerTheme
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
        }
    }
}
