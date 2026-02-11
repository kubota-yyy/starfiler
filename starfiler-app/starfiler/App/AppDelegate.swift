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

        // App menu
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu()
        let appName = ProcessInfo.processInfo.processName
        appMenu.addItem(withTitle: "About \(appName)", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Hide \(appName)", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        let hideOthersItem = appMenu.addItem(withTitle: "Hide Others", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        hideOthersItem.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(withTitle: "Show All", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Quit \(appName)", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appMenuItem.submenu = appMenu

        // File menu
        let fileMenuItem = NSMenuItem()
        mainMenu.addItem(fileMenuItem)
        let fileMenu = NSMenu(title: "File")
        fileMenu.addItem(withTitle: "New Folder", action: #selector(menuCreateDirectory(_:)), keyEquivalent: "n")
        fileMenu.addItem(NSMenuItem.separator())
        fileMenu.addItem(withTitle: "Open", action: #selector(menuOpenFile(_:)), keyEquivalent: "\r")
        fileMenu.addItem(withTitle: "Reveal in Finder", action: #selector(menuRevealInFinder(_:)), keyEquivalent: "")
        fileMenu.addItem(NSMenuItem.separator())
        fileMenu.addItem(withTitle: "Close Window", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        fileMenuItem.submenu = fileMenu

        // Edit menu
        let editMenuItem = NSMenuItem()
        mainMenu.addItem(editMenuItem)
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Undo", action: #selector(menuUndo(_:)), keyEquivalent: "z")
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(withTitle: "Copy", action: #selector(menuCopy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(menuPaste(_:)), keyEquivalent: "v")
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(withTitle: "Move to Trash", action: #selector(menuDelete(_:)), keyEquivalent: "\u{08}")
        editMenu.addItem(withTitle: "Rename...", action: #selector(menuRename(_:)), keyEquivalent: "")
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(withTitle: "Select All", action: #selector(menuSelectAll(_:)), keyEquivalent: "a")
        editMenuItem.submenu = editMenu

        // View menu
        let viewMenuItem = NSMenuItem()
        mainMenu.addItem(viewMenuItem)
        let viewMenu = NSMenu(title: "View")
        viewMenu.addItem(withTitle: "Toggle Preview", action: #selector(menuTogglePreview(_:)), keyEquivalent: "p")
        viewMenu.addItem(withTitle: "Toggle Hidden Files", action: #selector(menuToggleHiddenFiles(_:)), keyEquivalent: ".")
        viewMenu.addItem(NSMenuItem.separator())
        viewMenu.addItem(withTitle: "Refresh", action: #selector(menuRefresh(_:)), keyEquivalent: "r")
        viewMenuItem.submenu = viewMenu

        // Go menu
        let goMenuItem = NSMenuItem()
        mainMenu.addItem(goMenuItem)
        let goMenu = NSMenu(title: "Go")
        goMenu.addItem(withTitle: "Back", action: #selector(menuGoBack(_:)), keyEquivalent: "[")
        goMenu.addItem(withTitle: "Forward", action: #selector(menuGoForward(_:)), keyEquivalent: "]")
        goMenu.addItem(withTitle: "Enclosing Folder", action: #selector(menuGoToParent(_:)), keyEquivalent: "\u{1B}")
        goMenu.addItem(NSMenuItem.separator())
        let homeItem = goMenu.addItem(withTitle: "Home", action: #selector(menuGoHome(_:)), keyEquivalent: "h")
        homeItem.keyEquivalentModifierMask = [.command, .shift]
        goMenuItem.submenu = goMenu

        // Window menu
        let windowMenuItem = NSMenuItem()
        mainMenu.addItem(windowMenuItem)
        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowMenu.addItem(withTitle: "Zoom", action: #selector(NSWindow.performZoom(_:)), keyEquivalent: "")
        windowMenu.addItem(withTitle: "Switch Pane", action: #selector(menuSwitchPane(_:)), keyEquivalent: "\t")
        windowMenuItem.submenu = windowMenu
        NSApp.windowsMenu = windowMenu

        NSApp.mainMenu = mainMenu
    }

    // MARK: - Menu Actions

    @objc private func menuCreateDirectory(_ sender: Any?) {
        mainWindowController?.performAction { $0.createDirectory() }
    }

    @objc private func menuOpenFile(_ sender: Any?) {
        mainWindowController?.performAction { $0.activePane.enterSelected() }
    }

    @objc private func menuRevealInFinder(_ sender: Any?) {
        mainWindowController?.performAction { vm in
            if let url = vm.activePane.selectedItem?.url {
                NSWorkspace.shared.activateFileViewerSelecting([url])
            }
        }
    }

    @objc private func menuUndo(_ sender: Any?) {
        mainWindowController?.performAction { $0.undo() }
    }

    @objc private func menuCopy(_ sender: Any?) {
        mainWindowController?.performAction { $0.copyMarked() }
    }

    @objc private func menuPaste(_ sender: Any?) {
        mainWindowController?.performAction { $0.paste() }
    }

    @objc private func menuDelete(_ sender: Any?) {
        mainWindowController?.performAction { $0.deleteMarked() }
    }

    @objc private func menuRename(_ sender: Any?) {
        mainWindowController?.performAction { $0.rename() }
    }

    @objc private func menuSelectAll(_ sender: Any?) {
        mainWindowController?.performAction { $0.activePane.markAll() }
    }

    @objc private func menuTogglePreview(_ sender: Any?) {
        mainWindowController?.performAction { $0.togglePreviewPane() }
    }

    @objc private func menuToggleHiddenFiles(_ sender: Any?) {
        mainWindowController?.performAction { $0.activePane.toggleHiddenFiles() }
    }

    @objc private func menuRefresh(_ sender: Any?) {
        mainWindowController?.performAction { $0.activePane.refresh() }
    }

    @objc private func menuGoBack(_ sender: Any?) {
        mainWindowController?.performAction { $0.activePane.goBack() }
    }

    @objc private func menuGoForward(_ sender: Any?) {
        mainWindowController?.performAction { $0.activePane.goForward() }
    }

    @objc private func menuGoToParent(_ sender: Any?) {
        mainWindowController?.performAction { $0.activePane.goToParent() }
    }

    @objc private func menuGoHome(_ sender: Any?) {
        mainWindowController?.performAction {
            $0.activePane.navigate(to: URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true))
        }
    }

    @objc private func menuSwitchPane(_ sender: Any?) {
        mainWindowController?.performAction { $0.switchActivePane() }
    }
}
