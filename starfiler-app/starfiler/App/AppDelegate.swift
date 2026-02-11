import AppKit

@main
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var mainWindowController: MainWindowController?
    private let securityScopedBookmarkService: any SecurityScopedBookmarkProviding = SecurityScopedBookmarkService.shared

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildMainMenu()
        Task { @MainActor [weak self] in
            await self?.launchMainWindow()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    @MainActor
    private func launchMainWindow() async {
        do {
            try await securityScopedBookmarkService.loadBookmarks()

            let hasBookmarks = try await securityScopedBookmarkService.hasBookmarks()
            if !hasBookmarks {
                guard let selectedHomeDirectory = requestHomeDirectoryAccess() else {
                    NSApp.terminate(nil)
                    return
                }
                try await securityScopedBookmarkService.saveBookmark(for: selectedHomeDirectory)
            }

            let controller = MainWindowController(securityScopedBookmarkService: securityScopedBookmarkService)
            mainWindowController = controller
            controller.showWindow(self)

            NSApp.activate(ignoringOtherApps: true)
        } catch {
            presentStartupError(error)
        }
    }

    @MainActor
    private func requestHomeDirectoryAccess() -> URL? {
        let homeURL = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true).standardizedFileURL
        let homeResolvedURL = homeURL.resolvingSymlinksInPath().standardizedFileURL

        while true {
            let panel = NSOpenPanel()
            panel.directoryURL = homeURL
            panel.canChooseDirectories = true
            panel.canChooseFiles = false
            panel.allowsMultipleSelection = false
            panel.canCreateDirectories = false
            panel.prompt = "Grant Access"
            panel.message = "starfiler requires access to your home directory."

            guard panel.runModal() == .OK, let selectedURL = panel.url?.standardizedFileURL else {
                return nil
            }

            if selectedURL.resolvingSymlinksInPath().standardizedFileURL == homeResolvedURL {
                return selectedURL
            }

            let retryAlert = NSAlert()
            retryAlert.alertStyle = .warning
            retryAlert.messageText = "Select your home directory"
            retryAlert.informativeText = "Please choose \(homeURL.path) to continue."
            retryAlert.addButton(withTitle: "Retry")
            retryAlert.addButton(withTitle: "Quit")
            if retryAlert.runModal() == .alertSecondButtonReturn {
                return nil
            }
        }
    }

    @MainActor
    private func presentStartupError(_ error: Error) {
        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = "Failed to initialize sandbox access."
        alert.informativeText = error.localizedDescription
        alert.addButton(withTitle: "Quit")
        alert.runModal()
        NSApp.terminate(nil)
    }

    private func buildMainMenu() {
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)

        let appMenu = NSMenu()
        let appName = ProcessInfo.processInfo.processName

        appMenu.addItem(withTitle: "About \(appName)", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Quit \(appName)", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        appMenuItem.submenu = appMenu

        let fileMenuItem = NSMenuItem()
        mainMenu.addItem(fileMenuItem)

        let fileMenu = NSMenu(title: "File")
        fileMenu.addItem(withTitle: "Close Window", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        fileMenuItem.submenu = fileMenu

        NSApp.mainMenu = mainMenu
    }
}
