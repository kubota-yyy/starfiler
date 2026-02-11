import AppKit

final class MainWindowController: NSWindowController {
    private let mainViewModel: MainViewModel
    private lazy var mainSplitViewController = MainSplitViewController(viewModel: mainViewModel)
    private let statusBarView = StatusBarView()
    private let appUndoManager = UndoManager()

    init(
        fileSystemService: FileSystemProviding = FileSystemService(),
        securityScopedBookmarkService: any SecurityScopedBookmarkProviding = SecurityScopedBookmarkService.shared,
        initialDirectory: URL = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
    ) {
        self.mainViewModel = MainViewModel(
            fileSystemService: fileSystemService,
            securityScopedBookmarkService: securityScopedBookmarkService,
            initialLeftDirectory: initialDirectory,
            initialRightDirectory: initialDirectory
        )

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

    private func configureWindow() {
        guard let window else {
            return
        }

        window.title = "starfiler"
        window.minSize = NSSize(width: 800, height: 600)
        window.center()

        let containerViewController = NSViewController()
        let containerView = NSView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerViewController.view = containerView

        containerViewController.addChild(mainSplitViewController)
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
}
