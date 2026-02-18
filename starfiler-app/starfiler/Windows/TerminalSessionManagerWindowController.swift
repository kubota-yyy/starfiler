import AppKit

final class TerminalSessionManagerWindowController: NSWindowController {
    private let managerVC: TerminalSessionManagerViewController

    init(managerVC: TerminalSessionManagerViewController) {
        self.managerVC = managerVC

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 450),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Session Manager"
        window.minSize = NSSize(width: 400, height: 300)
        window.contentViewController = managerVC
        window.setFrameAutosaveName("TerminalSessionManager")
        if !window.setFrameUsingName("TerminalSessionManager") {
            window.center()
        }

        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        window?.makeKeyAndOrderFront(sender)
    }
}
