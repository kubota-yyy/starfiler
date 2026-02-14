import AppKit

final class MainContainerViewController: NSSplitViewController {
    private let mainSplitViewController: MainSplitViewController
    private let terminalPanelViewController: TerminalPanelViewController
    private let terminalSplitItem: NSSplitViewItem
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

    private static let defaultTerminalHeight: CGFloat = 300
    private static let minimumTerminalHeight: CGFloat = 200
    private static let statusBarHeight: CGFloat = 28

    init(
        mainSplitViewController: MainSplitViewController,
        terminalPanelViewController: TerminalPanelViewController,
        terminalPanelVisible: Bool
    ) {
        self.mainSplitViewController = mainSplitViewController
        self.terminalPanelViewController = terminalPanelViewController
        self.terminalSplitItem = NSSplitViewItem(viewController: terminalPanelViewController)
        super.init(nibName: nil, bundle: nil)

        let containerSplitView = NSSplitView()
        containerSplitView.isVertical = false
        containerSplitView.dividerStyle = .thin
        splitView = containerSplitView

        let mainSplitItem = NSSplitViewItem(viewController: mainSplitViewController)
        mainSplitItem.minimumThickness = 300
        mainSplitItem.canCollapse = false
        addSplitViewItem(mainSplitItem)

        terminalSplitItem.minimumThickness = Self.minimumTerminalHeight
        terminalSplitItem.canCollapse = true
        terminalSplitItem.titlebarSeparatorStyle = .none
        addSplitViewItem(terminalSplitItem)

        addSplitViewItem(statusBarSplitItem)
        terminalSplitItem.isCollapsed = !terminalPanelVisible
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func toggleTerminalPanel(animated: Bool = true) {
        let shouldCollapse = !terminalSplitItem.isCollapsed
        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.2
                terminalSplitItem.animator().isCollapsed = shouldCollapse
            }
        } else {
            terminalSplitItem.isCollapsed = shouldCollapse
        }
    }

    func showTerminalPanel(animated: Bool = true) {
        guard terminalSplitItem.isCollapsed else { return }
        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.2
                terminalSplitItem.animator().isCollapsed = false
            }
        } else {
            terminalSplitItem.isCollapsed = false
        }
    }

    func hideTerminalPanel(animated: Bool = true) {
        guard !terminalSplitItem.isCollapsed else { return }
        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.2
                terminalSplitItem.animator().isCollapsed = true
            }
        } else {
            terminalSplitItem.isCollapsed = true
        }
    }

    var isTerminalPanelVisible: Bool {
        !terminalSplitItem.isCollapsed
    }

    var terminalPanelHeight: CGFloat {
        terminalPanelViewController.view.frame.height
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
}
