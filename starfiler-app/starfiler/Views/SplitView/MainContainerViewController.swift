import AppKit

final class MainContainerViewController: NSSplitViewController, NSPopoverDelegate {
    private let mainSplitViewController: MainSplitViewController
    private let statusBarView = StatusBarView()
    private lazy var statusBarViewController: NSViewController = {
        let controller = NSViewController()
        let containerView = NSView()
        controller.view = containerView
        containerView.addSubview(statusBarView)

        NSLayoutConstraint.activate([
            statusBarView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            statusBarView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            statusBarView.topAnchor.constraint(equalTo: containerView.topAnchor),
            statusBarView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
        return controller
    }()
    private lazy var statusBarSplitItem: NSSplitViewItem = {
        let item = NSSplitViewItem(viewController: statusBarViewController)
        item.minimumThickness = Self.statusBarHeight
        item.maximumThickness = Self.statusBarHeight
        item.canCollapse = false
        item.titlebarSeparatorStyle = .none
        return item
    }()

    private var taskCenterPopover: NSPopover?
    private weak var taskCenterViewModel: TaskCenterViewModel?

    private static let statusBarHeight: CGFloat = 28

    init(
        mainSplitViewController: MainSplitViewController
    ) {
        self.mainSplitViewController = mainSplitViewController
        super.init(nibName: nil, bundle: nil)

        let containerSplitView = NSSplitView()
        containerSplitView.isVertical = false
        containerSplitView.dividerStyle = .thin
        splitView = containerSplitView

        let mainSplitItem = NSSplitViewItem(viewController: mainSplitViewController)
        mainSplitItem.minimumThickness = 300
        mainSplitItem.canCollapse = false
        addSplitViewItem(mainSplitItem)

        addSplitViewItem(statusBarSplitItem)

        statusBarView.onTaskCenterButtonClicked = { [weak self] in
            self?.toggleTaskCenterPopover()
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateStatusBar(primaryText: String, itemCount: Int, markedCount: Int) {
        statusBarView.update(primaryText: primaryText, itemCount: itemCount, markedCount: markedCount)
    }

    func applyStatusBarTheme(_ theme: FilerTheme, backgroundOpacity: CGFloat = 1.0) {
        statusBarView.applyTheme(theme, backgroundOpacity: backgroundOpacity)
    }

    func setStatusBarStarEffectsEnabled(_ enabled: Bool) {
        statusBarView.setStarEffectsEnabled(enabled)
    }

    func setStatusBarAnimationEffectSettings(_ settings: AnimationEffectSettings) {
        statusBarView.setAnimationEffectSettings(settings)
    }

    func bindTaskCenter(_ viewModel: TaskCenterViewModel) {
        self.taskCenterViewModel = viewModel
        viewModel.onActiveCountChanged = { [weak self, weak viewModel] activeCount in
            let hasFailed = viewModel?.hasFailedEntries ?? false
            self?.statusBarView.updateTaskCenterIndicator(activeCount: activeCount, hasFailedEntries: hasFailed)
        }
        viewModel.onHasFailedEntriesChanged = { [weak self, weak viewModel] hasFailed in
            let activeCount = viewModel?.activeCount ?? 0
            self?.statusBarView.updateTaskCenterIndicator(activeCount: activeCount, hasFailedEntries: hasFailed)
        }
        viewModel.onCopyErrorDetailRequested = { text in
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
        }
    }

    // MARK: - Task Center Popover

    private func toggleTaskCenterPopover() {
        if let popover = taskCenterPopover, popover.isShown {
            popover.performClose(nil)
            return
        }

        guard let viewModel = taskCenterViewModel else {
            return
        }

        let contentController = TaskCenterPopoverViewController(viewModel: viewModel)

        let popover = NSPopover()
        popover.behavior = .semitransient
        popover.animates = true
        popover.delegate = self
        popover.contentViewController = contentController

        let anchorView = statusBarView.taskCenterButtonView
        popover.show(relativeTo: anchorView.bounds, of: anchorView, preferredEdge: .maxY)
        taskCenterPopover = popover
    }

    func popoverDidClose(_ notification: Notification) {
        taskCenterPopover?.delegate = nil
        taskCenterPopover = nil
    }
}
