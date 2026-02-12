import AppKit

final class TerminalPanelViewController: NSViewController {
    private let listViewModel: TerminalSessionListViewModel

    private let sessionListView = TerminalSessionListView()
    private let contentContainerView = NSView()
    private let dividerView = NSView()

    private var sessionViewControllers: [UUID: TerminalContentViewController] = [:]
    private var sessionViewModels: [UUID: TerminalSessionViewModel] = [:]
    private var currentContentVC: TerminalContentViewController?

    var onTerminalSessionCreated: ((TerminalSession) -> Void)?

    init(listViewModel: TerminalSessionListViewModel) {
        self.listViewModel = listViewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        let root = NSView(frame: NSRect(x: 0, y: 0, width: 800, height: 300))
        root.wantsLayer = true

        sessionListView.translatesAutoresizingMaskIntoConstraints = false
        contentContainerView.translatesAutoresizingMaskIntoConstraints = false
        dividerView.translatesAutoresizingMaskIntoConstraints = false

        dividerView.wantsLayer = true
        dividerView.layer?.backgroundColor = NSColor.separatorColor.withAlphaComponent(0.72).cgColor

        root.addSubview(sessionListView)
        root.addSubview(dividerView)
        root.addSubview(contentContainerView)

        NSLayoutConstraint.activate([
            sessionListView.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            sessionListView.topAnchor.constraint(equalTo: root.topAnchor),
            sessionListView.bottomAnchor.constraint(equalTo: root.bottomAnchor),
            sessionListView.widthAnchor.constraint(equalToConstant: 200),

            dividerView.leadingAnchor.constraint(equalTo: sessionListView.trailingAnchor),
            dividerView.topAnchor.constraint(equalTo: root.topAnchor),
            dividerView.bottomAnchor.constraint(equalTo: root.bottomAnchor),
            dividerView.widthAnchor.constraint(equalToConstant: 1),

            contentContainerView.leadingAnchor.constraint(equalTo: dividerView.trailingAnchor),
            contentContainerView.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            contentContainerView.topAnchor.constraint(equalTo: root.topAnchor),
            contentContainerView.bottomAnchor.constraint(equalTo: root.bottomAnchor),
        ])

        view = root
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        bindSessionList()
        bindListViewModel()
        refreshSessionList()
    }

    func createSession(command: TerminalSessionCommand, workingDirectory: URL) {
        listViewModel.createSession(command: command, workingDirectory: workingDirectory)
    }

    func applyTheme(_ palette: FilerThemePalette) {
        view.layer?.backgroundColor = palette.paneBackgroundColor.cgColor
        sessionListView.applyTheme(palette)

        for vc in sessionViewControllers.values {
            vc.applyThemeColors(palette: palette)
        }
    }

    func focusActiveTerminal() {
        currentContentVC?.focusTerminal()
    }

    func terminateAllSessions() {
        for vc in sessionViewControllers.values {
            if vc.isProcessRunning {
                vc.sendInterrupt()
            }
        }
    }

    private func bindSessionList() {
        sessionListView.onSessionSelected = { [weak self] id in
            self?.listViewModel.setActiveSession(id: id)
        }

        sessionListView.onSessionCloseRequested = { [weak self] id in
            self?.closeSession(id: id)
        }

        sessionListView.onAddClaudeSession = { [weak self] in
            self?.onTerminalSessionCreated.map { _ in }
            self?.createSessionFromCurrentContext(command: .claude)
        }

        sessionListView.onAddCodexSession = { [weak self] in
            self?.createSessionFromCurrentContext(command: .codex)
        }
    }

    private func bindListViewModel() {
        listViewModel.onSessionCreated = { [weak self] session in
            self?.handleSessionCreated(session)
        }

        listViewModel.onSessionRemoved = { [weak self] id in
            self?.handleSessionRemoved(id: id)
        }

        listViewModel.onActiveSessionChanged = { [weak self] id in
            self?.switchToSession(id: id)
            self?.refreshSessionList()
        }
    }

    private func createSessionFromCurrentContext(command: TerminalSessionCommand) {
        let dir = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
        listViewModel.createSession(command: command, workingDirectory: dir)
    }

    private func handleSessionCreated(_ session: TerminalSession) {
        let sessionVM = TerminalSessionViewModel(sessionId: session.id)
        sessionViewModels[session.id] = sessionVM

        sessionVM.onStatusChanged = { [weak self] status in
            self?.listViewModel.updateSessionStatus(id: session.id, status: status)
        }

        let contentVC = TerminalContentViewController(sessionId: session.id, sessionViewModel: sessionVM)
        contentVC.onProcessExited = { [weak self] id, exitCode in
            self?.listViewModel.updateSessionExitCode(id: id, exitCode: exitCode)
        }
        sessionViewControllers[session.id] = contentVC

        switchToSession(id: session.id)
        refreshSessionList()

        contentVC.launchProcess(command: session.command, workingDirectory: session.workingDirectory)
        onTerminalSessionCreated?(session)
    }

    private func handleSessionRemoved(id: UUID) {
        if let vc = sessionViewControllers[id] {
            if vc.isProcessRunning {
                vc.sendInterrupt()
            }
            if currentContentVC === vc {
                removeCurrentContent()
            }
            vc.removeFromParent()
        }
        sessionViewControllers.removeValue(forKey: id)
        sessionViewModels.removeValue(forKey: id)
        refreshSessionList()
    }

    private func closeSession(id: UUID) {
        if let vc = sessionViewControllers[id], vc.isProcessRunning {
            vc.sendInterrupt()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.listViewModel.removeSession(id: id)
            }
        } else {
            listViewModel.removeSession(id: id)
        }
    }

    private func switchToSession(id: UUID?) {
        removeCurrentContent()

        guard let id, let vc = sessionViewControllers[id] else {
            return
        }

        addChild(vc)
        vc.view.translatesAutoresizingMaskIntoConstraints = false
        contentContainerView.addSubview(vc.view)
        NSLayoutConstraint.activate([
            vc.view.leadingAnchor.constraint(equalTo: contentContainerView.leadingAnchor),
            vc.view.trailingAnchor.constraint(equalTo: contentContainerView.trailingAnchor),
            vc.view.topAnchor.constraint(equalTo: contentContainerView.topAnchor),
            vc.view.bottomAnchor.constraint(equalTo: contentContainerView.bottomAnchor),
        ])
        currentContentVC = vc
        vc.focusTerminal()
    }

    private func removeCurrentContent() {
        guard let current = currentContentVC else { return }
        current.view.removeFromSuperview()
        current.removeFromParent()
        currentContentVC = nil
    }

    private func refreshSessionList() {
        sessionListView.update(sessions: listViewModel.sessions, activeSessionId: listViewModel.activeSessionId)
    }
}
