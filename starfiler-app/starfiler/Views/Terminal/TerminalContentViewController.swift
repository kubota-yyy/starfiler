import AppKit
import SwiftTerm

final class TerminalContentViewController: NSViewController {
    private let sessionId: UUID
    private let sessionViewModel: TerminalSessionViewModel
    private var terminalView: LocalProcessTerminalView?
    private var hasLaunched = false

    var onProcessExited: ((UUID, Int32) -> Void)?

    init(sessionId: UUID, sessionViewModel: TerminalSessionViewModel) {
        self.sessionId = sessionId
        self.sessionViewModel = sessionViewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        let tv = LocalProcessTerminalView(frame: NSRect(x: 0, y: 0, width: 600, height: 300))
        tv.translatesAutoresizingMaskIntoConstraints = false
        tv.processDelegate = self
        self.terminalView = tv
        self.view = tv
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        if !hasLaunched {
            hasLaunched = true
        }
    }

    func launchProcess(command: TerminalSessionCommand, workingDirectory: URL, environment: [String: String]? = nil) {
        guard let tv = terminalView else { return }

        var env = environment ?? ProcessInfo.processInfo.environment
        env["TERM"] = "xterm-256color"
        env["LANG"] = env["LANG"] ?? "en_US.UTF-8"

        let shellPath = env["SHELL"] ?? "/bin/zsh"
        let executable = command.executableName
        let args = ["-l", "-c", "exec \(executable)"]

        tv.startProcess(
            executable: shellPath,
            args: args,
            environment: env.map { "\($0.key)=\($0.value)" },
            execName: executable,
            currentDirectory: workingDirectory.path
        )
        tv.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)

        sessionViewModel.processStarted()
    }

    func applyThemeColors(palette: FilerThemePalette) {
        guard let tv = terminalView else { return }

        tv.nativeForegroundColor = palette.primaryTextColor
        tv.nativeBackgroundColor = palette.paneBackgroundColor

        let caretColor = palette.accentColor
        tv.caretColor = caretColor

        tv.selectedTextBackgroundColor = palette.accentColor.withAlphaComponent(0.3)
    }

    func focusTerminal() {
        guard let tv = terminalView else { return }
        view.window?.makeFirstResponder(tv)
    }

    func sendInterrupt() {
        terminalView?.send([3])
    }

    var isProcessRunning: Bool {
        sessionViewModel.status == .running || sessionViewModel.status == .waitingForInput || sessionViewModel.status == .launching
    }
}

extension TerminalContentViewController: LocalProcessTerminalViewDelegate {
    func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {
    }

    func setTerminalTitle(source: LocalProcessTerminalView, title: String) {
        sessionViewModel.outputReceived()
    }

    func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {
        sessionViewModel.outputReceived()
    }

    func processTerminated(source: TerminalView, exitCode: Int32?) {
        let code = exitCode ?? -1
        sessionViewModel.processExited(exitCode: code)
        onProcessExited?(sessionId, code)
    }
}
