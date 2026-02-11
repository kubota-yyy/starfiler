import AppKit

final class MainSplitViewController: NSSplitViewController {
    private struct PaneStatus {
        var path: String
        var itemCount: Int
    }

    private let viewModel: MainViewModel
    private let leftPaneViewController: FilePaneViewController
    private let rightPaneViewController: FilePaneViewController
    private var supplementarySplitItem: NSSplitViewItem?

    private var leftPaneStatus: PaneStatus
    private var rightPaneStatus: PaneStatus

    var onStatusChanged: ((String, Int) -> Void)?

    init(viewModel: MainViewModel) {
        self.viewModel = viewModel
        self.leftPaneViewController = FilePaneViewController(viewModel: viewModel.leftPane)
        self.rightPaneViewController = FilePaneViewController(viewModel: viewModel.rightPane)

        self.leftPaneStatus = PaneStatus(
            path: viewModel.leftPane.paneState.currentDirectory.path,
            itemCount: viewModel.leftPane.directoryContents.displayedItems.count
        )
        self.rightPaneStatus = PaneStatus(
            path: viewModel.rightPane.paneState.currentDirectory.path,
            itemCount: viewModel.rightPane.directoryContents.displayedItems.count
        )

        super.init(nibName: nil, bundle: nil)

        configureSplitView()
        bindPaneControllers()
        refreshActivePaneUI(focusActivePane: false)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func focusActivePane() {
        paneViewController(for: viewModel.activePaneSide).focusTable()
    }

    func setSupplementaryPaneViewController(_ viewController: NSViewController?) {
        if let existingItem = supplementarySplitItem {
            removeSplitViewItem(existingItem)
            supplementarySplitItem = nil
        }

        guard let viewController else {
            return
        }

        let splitItem = NSSplitViewItem(viewController: viewController)
        splitItem.minimumThickness = 240
        splitItem.canCollapse = true
        addSplitViewItem(splitItem)
        supplementarySplitItem = splitItem
    }

    private func configureSplitView() {
        splitView.isVertical = true
        splitView.dividerStyle = .thin
        splitView.autosaveName = "MainSplitView"

        let leftItem = NSSplitViewItem(viewController: leftPaneViewController)
        leftItem.minimumThickness = 280
        addSplitViewItem(leftItem)

        let rightItem = NSSplitViewItem(viewController: rightPaneViewController)
        rightItem.minimumThickness = 280
        addSplitViewItem(rightItem)

        // Additional panes can be attached with setSupplementaryPaneViewController(_:).
    }

    private func bindPaneControllers() {
        leftPaneViewController.onTabPressed = { [weak self] in
            self?.handleTabSwitch() ?? false
        }
        rightPaneViewController.onTabPressed = { [weak self] in
            self?.handleTabSwitch() ?? false
        }

        leftPaneViewController.onDidRequestActivate = { [weak self] in
            self?.setActivePane(.left)
        }
        rightPaneViewController.onDidRequestActivate = { [weak self] in
            self?.setActivePane(.right)
        }

        leftPaneViewController.onStatusChanged = { [weak self] path, itemCount in
            self?.updatePaneStatus(side: .left, path: path, itemCount: itemCount)
        }
        rightPaneViewController.onStatusChanged = { [weak self] path, itemCount in
            self?.updatePaneStatus(side: .right, path: path, itemCount: itemCount)
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

    private func refreshActivePaneUI(focusActivePane shouldFocus: Bool) {
        leftPaneViewController.setActive(viewModel.activePaneSide == .left)
        rightPaneViewController.setActive(viewModel.activePaneSide == .right)

        if shouldFocus {
            focusActivePane()
        }

        publishActivePaneStatus()
    }

    private func updatePaneStatus(side: PaneSide, path: String, itemCount: Int) {
        let status = PaneStatus(path: path, itemCount: itemCount)

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

        onStatusChanged?(status.path, status.itemCount)
    }

    private func paneViewController(for side: PaneSide) -> FilePaneViewController {
        switch side {
        case .left:
            return leftPaneViewController
        case .right:
            return rightPaneViewController
        }
    }
}
