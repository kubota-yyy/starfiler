import AppKit

final class MainWindowController: NSWindowController {
    private let filePaneViewModel = FilePaneViewModel()
    private lazy var filePaneViewController = FilePaneViewController(viewModel: filePaneViewModel)
    private let statusBarView = StatusBarView()

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1100, height: 720),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )

        super.init(window: window)
        configureWindow()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        filePaneViewController.focusTable()
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

        containerViewController.addChild(filePaneViewController)
        let paneView = filePaneViewController.view
        paneView.translatesAutoresizingMaskIntoConstraints = false

        containerView.addSubview(paneView)
        containerView.addSubview(statusBarView)

        NSLayoutConstraint.activate([
            paneView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            paneView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            paneView.topAnchor.constraint(equalTo: containerView.topAnchor),
            paneView.bottomAnchor.constraint(equalTo: statusBarView.topAnchor),

            statusBarView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            statusBarView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            statusBarView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])

        filePaneViewController.onStatusChanged = { [weak self] path, itemCount in
            self?.statusBarView.update(path: path, itemCount: itemCount)
        }
        statusBarView.update(
            path: filePaneViewModel.paneState.currentDirectory.path,
            itemCount: filePaneViewModel.directoryContents.displayedItems.count
        )

        window.contentViewController = containerViewController
    }
}
