import AppKit

final class MainContainerViewController: NSSplitViewController {
    private let mainSplitViewController: MainSplitViewController
    private let terminalPanelViewController: TerminalPanelViewController
    private let terminalSplitItem: NSSplitViewItem

    private static let defaultTerminalHeight: CGFloat = 300
    private static let minimumTerminalHeight: CGFloat = 200

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
}
