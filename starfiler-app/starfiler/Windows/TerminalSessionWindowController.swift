import AppKit

final class TerminalSessionWindowController: NSWindowController {
    let sessionId: UUID
    private let terminalContentVC: TerminalContentViewController

    var onWindowClosed: ((UUID) -> Void)?

    init(sessionId: UUID, terminalContentVC: TerminalContentViewController) {
        self.sessionId = sessionId
        self.terminalContentVC = terminalContentVC

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 500),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Terminal"
        window.minSize = NSSize(width: 400, height: 200)
        window.contentViewController = terminalContentVC
        window.center()

        super.init(window: window)
        window.delegate = self
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateTitle(_ title: String) {
        window?.title = title
    }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        window?.makeKeyAndOrderFront(sender)
        terminalContentVC.focusTerminal()
    }
}

extension TerminalSessionWindowController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        onWindowClosed?(sessionId)
    }
}
