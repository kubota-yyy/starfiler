import AppKit

@main
enum StarfilerMain {
    private static let delegate = AppDelegate()

    static func main() {
        let app = NSApplication.shared
        app.delegate = delegate
        _ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var mainWindowController: MainWindowController?
    private var settingsWindowController: SettingsWindowController?
    private var launchTask: Task<Void, Never>?
    private var pendingOpenDirectories: [URL] = []
    private let securityScopedBookmarkService: any SecurityScopedBookmarkProviding = SecurityScopedBookmarkService.shared

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildMainMenu()
        launchTask = Task { @MainActor in
            await launchMainWindow()
            launchTask = nil
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        enqueueOpenDirectories(from: urls)
    }

    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        let urls = filenames.map { URL(fileURLWithPath: $0) }
        enqueueOpenDirectories(from: urls)
        sender.reply(toOpenOrPrint: .success)
    }

    @MainActor
    private func launchMainWindow() async {
        do {
            try await securityScopedBookmarkService.loadBookmarks()

            let hasBookmarks = try await securityScopedBookmarkService.hasBookmarks()
            if !hasBookmarks {
                guard let selectedStartupDisk = requestStartupDiskAccess() else {
                    NSApp.terminate(nil)
                    return
                }
                try await securityScopedBookmarkService.saveBookmark(for: selectedStartupDisk)
            }

            let controller = MainWindowController(securityScopedBookmarkService: securityScopedBookmarkService)
            mainWindowController = controller
            controller.showWindow(self)
            processPendingOpenDirectories()

            NSApp.activate(ignoringOtherApps: true)
        } catch {
            presentStartupError(error)
        }
    }

    @MainActor
    private func requestStartupDiskAccess() -> URL? {
        let startupDiskURL = URL(fileURLWithPath: "/", isDirectory: true).standardizedFileURL
        let panel = NSOpenPanel()
        panel.directoryURL = startupDiskURL
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.prompt = "Grant Access"
        panel.message = "starfiler requires directory access. Select the startup disk (Macintosh HD) to reduce future permission prompts."

        guard panel.runModal() == .OK, let selectedURL = panel.url?.standardizedFileURL else {
            return nil
        }

        return selectedURL
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

    private func enqueueOpenDirectories(from urls: [URL]) {
        let directories = urls.compactMap(resolveDirectoryToOpen(from:))
        guard !directories.isEmpty else {
            return
        }

        pendingOpenDirectories.append(contentsOf: directories)
        Task { @MainActor in
            processPendingOpenDirectories()
        }
    }

    private func resolveDirectoryToOpen(from url: URL) -> URL? {
        let fileURL = url.standardizedFileURL

        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: fileURL.path, isDirectory: &isDirectory) else {
            return nil
        }

        if isDirectory.boolValue {
            return fileURL
        }

        return fileURL.deletingLastPathComponent().standardizedFileURL
    }

    @MainActor
    private func processPendingOpenDirectories() {
        guard let mainWindowController, !pendingOpenDirectories.isEmpty else {
            return
        }

        let targetDirectory = pendingOpenDirectories.removeLast()
        pendingOpenDirectories.removeAll(keepingCapacity: true)

        mainWindowController.performAction {
            $0.activePane.navigate(to: targetDirectory)
        }
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
        appMenu.addItem(withTitle: "Settings...", action: #selector(menuShowSettings(_:)), keyEquivalent: ",")
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
        let showInFinderItem = fileMenu.addItem(withTitle: "Show in Finder", action: #selector(menuRevealInFinder(_:)), keyEquivalent: "f")
        showInFinderItem.keyEquivalentModifierMask = [.command, .shift]
        fileMenu.addItem(NSMenuItem.separator())
        fileMenu.addItem(withTitle: "Close Window", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        fileMenuItem.submenu = fileMenu

        // Edit menu
        let editMenuItem = NSMenuItem()
        mainMenu.addItem(editMenuItem)
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(withTitle: "Cut", action: Selector(("cut:")), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: Selector(("copy:")), keyEquivalent: "c")
        let copyItemPathItem = editMenu.addItem(withTitle: "Copy File/Folder Path", action: #selector(menuCopySelectedItemPath(_:)), keyEquivalent: "c")
        copyItemPathItem.keyEquivalentModifierMask = [.command, .option]
        editMenu.addItem(withTitle: "Paste", action: Selector(("paste:")), keyEquivalent: "v")
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(withTitle: "Move to Trash", action: #selector(menuDelete(_:)), keyEquivalent: "\u{08}")
        editMenu.addItem(withTitle: "Rename...", action: #selector(menuRename(_:)), keyEquivalent: "")
        editMenu.addItem(withTitle: "Batch Rename...", action: #selector(menuBatchRename(_:)), keyEquivalent: "")
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(withTitle: "Sync Panes...", action: #selector(menuSyncPanes(_:)), keyEquivalent: "")
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(withTitle: "Select All", action: #selector(menuSelectAll(_:)), keyEquivalent: "a")
        editMenuItem.submenu = editMenu

        // View menu
        let viewMenuItem = NSMenuItem()
        mainMenu.addItem(viewMenuItem)
        let viewMenu = NSMenu(title: "View")
        let toggleSidebarItem = viewMenu.addItem(withTitle: "Toggle Sidebar", action: #selector(menuToggleSidebar(_:)), keyEquivalent: "s")
        toggleSidebarItem.keyEquivalentModifierMask = [.command]

        let togglePreviewItem = viewMenu.addItem(withTitle: "Toggle Preview", action: #selector(menuTogglePreview(_:)), keyEquivalent: "p")
        togglePreviewItem.keyEquivalentModifierMask = [.control]
        let toggleLeftPaneItem = viewMenu.addItem(withTitle: "Toggle Left Pane", action: #selector(menuToggleLeftPane(_:)), keyEquivalent: "1")
        toggleLeftPaneItem.keyEquivalentModifierMask = [.control]
        let toggleRightPaneItem = viewMenu.addItem(withTitle: "Toggle Right Pane", action: #selector(menuToggleRightPane(_:)), keyEquivalent: "2")
        toggleRightPaneItem.keyEquivalentModifierMask = [.control]
        let toggleSinglePaneItem = viewMenu.addItem(withTitle: "Toggle Single Pane", action: #selector(menuToggleSinglePane(_:)), keyEquivalent: "3")
        toggleSinglePaneItem.keyEquivalentModifierMask = [.control]
        let equalizePaneWidthsItem = viewMenu.addItem(withTitle: "Equalize Pane Widths", action: #selector(menuEqualizePaneWidths(_:)), keyEquivalent: "4")
        equalizePaneWidthsItem.keyEquivalentModifierMask = [.control]
        let toggleMediaModeItem = viewMenu.addItem(withTitle: "Toggle Media Mode", action: #selector(menuToggleMediaMode(_:)), keyEquivalent: "m")
        toggleMediaModeItem.keyEquivalentModifierMask = [.control]
        let toggleMediaRecursiveItem = viewMenu.addItem(withTitle: "Toggle Media Recursive", action: #selector(menuToggleMediaRecursive(_:)), keyEquivalent: "m")
        toggleMediaRecursiveItem.keyEquivalentModifierMask = [.control, .shift]
        viewMenu.addItem(withTitle: "Toggle Hidden Files", action: #selector(menuToggleHiddenFiles(_:)), keyEquivalent: ".")
        viewMenu.addItem(NSMenuItem.separator())
        viewMenu.addItem(withTitle: "Sort by Name", action: #selector(menuSortByName(_:)), keyEquivalent: "")
        viewMenu.addItem(withTitle: "Sort by Size", action: #selector(menuSortBySize(_:)), keyEquivalent: "")
        viewMenu.addItem(withTitle: "Sort by Date Modified", action: #selector(menuSortByDate(_:)), keyEquivalent: "")
        viewMenu.addItem(withTitle: "Sort by Selection Order", action: #selector(menuSortBySelectionOrder(_:)), keyEquivalent: "")
        viewMenu.addItem(withTitle: "Reverse Sort Order", action: #selector(menuReverseSortOrder(_:)), keyEquivalent: "")
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
        let goToFolderItem = goMenu.addItem(withTitle: "Go to File or Folder...", action: #selector(menuGoToPath(_:)), keyEquivalent: "g")
        goToFolderItem.keyEquivalentModifierMask = [.command, .shift]
        goMenu.addItem(NSMenuItem.separator())
        let hdItem = goMenu.addItem(withTitle: "HD", action: #selector(menuGoHD(_:)), keyEquivalent: "c")
        hdItem.keyEquivalentModifierMask = [.command, .shift]
        let homeItem = goMenu.addItem(withTitle: "Home", action: #selector(menuGoHome(_:)), keyEquivalent: "h")
        homeItem.keyEquivalentModifierMask = [.command, .shift]
        let desktopItem = goMenu.addItem(withTitle: "Desktop", action: #selector(menuGoDesktop(_:)), keyEquivalent: "d")
        desktopItem.keyEquivalentModifierMask = [.command, .shift]
        let documentsItem = goMenu.addItem(withTitle: "Documents", action: #selector(menuGoDocuments(_:)), keyEquivalent: "o")
        documentsItem.keyEquivalentModifierMask = [.command, .shift]
        let downloadsItem = goMenu.addItem(withTitle: "Downloads", action: #selector(menuGoDownloads(_:)), keyEquivalent: "l")
        downloadsItem.keyEquivalentModifierMask = [.command, .shift]
        let applicationsItem = goMenu.addItem(withTitle: "Applications", action: #selector(menuGoApplications(_:)), keyEquivalent: "a")
        applicationsItem.keyEquivalentModifierMask = [.command, .shift]
        goMenuItem.submenu = goMenu

        // Terminal menu
        let terminalMenuItem = NSMenuItem()
        mainMenu.addItem(terminalMenuItem)
        let terminalMenu = NSMenu(title: "Terminal")
        let launchClaudeItem = terminalMenu.addItem(withTitle: "Launch Claude Code", action: #selector(menuLaunchClaude(_:)), keyEquivalent: "")
        let launchCodexItem = terminalMenu.addItem(withTitle: "Launch Codex CLI", action: #selector(menuLaunchCodex(_:)), keyEquivalent: "")
        terminalMenu.addItem(NSMenuItem.separator())
        let toggleTerminalItem = terminalMenu.addItem(withTitle: "Toggle Terminal Panel", action: #selector(menuToggleTerminalPanel(_:)), keyEquivalent: "`")
        toggleTerminalItem.keyEquivalentModifierMask = [.control]
        terminalMenuItem.submenu = terminalMenu

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
            guard let url = vm.activePane.selectedItem?.url.standardizedFileURL else {
                NSSound.beep()
                return
            }
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }
    }

    @objc func undo(_ sender: Any?) {
        mainWindowController?.performAction { $0.undo() }
    }

    @objc func copy(_ sender: Any?) {
        mainWindowController?.performAction { $0.copyMarked() }
    }

    @objc private func menuCopySelectedItemPath(_ sender: Any?) {
        mainWindowController?.performAction { vm in
            guard let selectedURL = vm.activePane.selectedItem?.url.standardizedFileURL else {
                NSSound.beep()
                return
            }

            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(selectedURL.path, forType: .string)
        }
    }

    @objc func paste(_ sender: Any?) {
        mainWindowController?.performAction { $0.paste() }
    }

    @objc private func menuDelete(_ sender: Any?) {
        mainWindowController?.requestDeleteFromActivePane()
    }

    @objc private func menuRename(_ sender: Any?) {
        mainWindowController?.performAction { $0.rename() }
    }

    @objc private func menuBatchRename(_ sender: Any?) {
        mainWindowController?.presentBatchRename()
    }

    @objc private func menuSyncPanes(_ sender: Any?) {
        mainWindowController?.presentSyncWindow()
    }

    @objc private func menuSelectAll(_ sender: Any?) {
        mainWindowController?.performAction { $0.activePane.markAll() }
    }

    @objc private func menuTogglePreview(_ sender: Any?) {
        mainWindowController?.togglePreviewPane()
    }

    @objc private func menuToggleLeftPane(_ sender: Any?) {
        mainWindowController?.toggleLeftPane()
    }

    @objc private func menuToggleRightPane(_ sender: Any?) {
        mainWindowController?.toggleRightPane()
    }

    @objc private func menuToggleSinglePane(_ sender: Any?) {
        mainWindowController?.toggleSinglePane()
    }

    @objc private func menuEqualizePaneWidths(_ sender: Any?) {
        mainWindowController?.equalizePaneWidths()
    }

    @objc private func menuToggleMediaMode(_ sender: Any?) {
        mainWindowController?.performAction { $0.activePane.toggleDisplayMode() }
    }

    @objc private func menuToggleMediaRecursive(_ sender: Any?) {
        mainWindowController?.performAction { $0.activePane.toggleMediaRecursive() }
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

    @objc private func menuGoToPath(_ sender: Any?) {
        mainWindowController?.presentGoToPathPrompt()
    }

    @objc private func menuGoHD(_ sender: Any?) {
        mainWindowController?.performAction {
            $0.activePane.navigate(to: URL(fileURLWithPath: "/", isDirectory: true))
        }
    }

    @objc private func menuGoHome(_ sender: Any?) {
        mainWindowController?.performAction {
            $0.activePane.navigate(to: UserPaths.homeDirectoryURL)
        }
    }

    @objc private func menuGoDesktop(_ sender: Any?) {
        mainWindowController?.performAction {
            $0.activePane.navigate(to: URL(fileURLWithPath: UserPaths.homeDirectoryPath + "/Desktop", isDirectory: true))
        }
    }

    @objc private func menuGoDocuments(_ sender: Any?) {
        mainWindowController?.performAction {
            $0.activePane.navigate(to: URL(fileURLWithPath: UserPaths.homeDirectoryPath + "/Documents", isDirectory: true))
        }
    }

    @objc private func menuGoDownloads(_ sender: Any?) {
        mainWindowController?.performAction {
            $0.activePane.navigate(to: URL(fileURLWithPath: UserPaths.homeDirectoryPath + "/Downloads", isDirectory: true))
        }
    }

    @objc private func menuGoApplications(_ sender: Any?) {
        mainWindowController?.performAction {
            $0.activePane.navigate(to: URL(fileURLWithPath: "/Applications", isDirectory: true))
        }
    }

    @objc private func menuSortByName(_ sender: Any?) {
        mainWindowController?.performAction { $0.activePane.sortByName() }
    }

    @objc private func menuSortBySize(_ sender: Any?) {
        mainWindowController?.performAction { $0.activePane.sortBySize() }
    }

    @objc private func menuSortByDate(_ sender: Any?) {
        mainWindowController?.performAction { $0.activePane.sortByDate() }
    }

    @objc private func menuSortBySelectionOrder(_ sender: Any?) {
        mainWindowController?.performAction { $0.activePane.sortBySelectionOrder() }
    }

    @objc private func menuReverseSortOrder(_ sender: Any?) {
        mainWindowController?.performAction { $0.activePane.reverseSortOrder() }
    }

    @objc private func menuToggleSidebar(_ sender: Any?) {
        mainWindowController?.toggleSidebarPane()
    }

    @objc private func menuSwitchPane(_ sender: Any?) {
        mainWindowController?.performAction { $0.switchActivePane() }
    }

    @objc private func menuLaunchClaude(_ sender: Any?) {
        mainWindowController?.launchTerminalSession(command: .claude)
    }

    @objc private func menuLaunchCodex(_ sender: Any?) {
        mainWindowController?.launchTerminalSession(command: .codex)
    }

    @objc private func menuToggleTerminalPanel(_ sender: Any?) {
        mainWindowController?.toggleTerminalPanel()
    }

    @objc private func menuShowSettings(_ sender: Any?) {
        presentSettingsWindow()
    }

    private func presentSettingsWindow() {
        if let existing = settingsWindowController {
            existing.showWindow(self)
            return
        }

        let currentTheme = mainWindowController?.currentFilerTheme ?? .system
        let currentTransparentBackground = mainWindowController?.isTransparentBackgroundEnabled ?? false
        let currentTransparentBackgroundOpacity = mainWindowController?.currentTransparentBackgroundOpacity ?? 0.7
        let currentActionFeedbackEnabled = mainWindowController?.isActionFeedbackEnabled ?? true
        let currentSpotlightSearchScope = mainWindowController?.currentSpotlightSearchScope ?? .currentDirectory
        let currentFileIconSize = mainWindowController?.currentFileIconSize ?? 16
        let currentSidebarFavoritesVisible = mainWindowController?.isSidebarFavoritesVisible ?? true
        let currentSidebarRecentItemsLimit = mainWindowController?.currentSidebarRecentItemsLimit ?? 10
        let currentStarEffectsEnabled = mainWindowController?.isStarEffectsEnabled ?? true
        let currentAnimationEffectSettings = mainWindowController?.currentAnimationEffectSettings ?? .allEnabled

        let appearanceVC = AppearanceSettingsViewController(
            selectedTheme: currentTheme,
            isTransparentBackgroundEnabled: currentTransparentBackground,
            transparentBackgroundOpacity: currentTransparentBackgroundOpacity,
            isActionFeedbackEnabled: currentActionFeedbackEnabled,
            selectedSpotlightSearchScope: currentSpotlightSearchScope,
            initialFileIconSize: currentFileIconSize,
            initialSidebarFavoritesVisible: currentSidebarFavoritesVisible,
            initialSidebarRecentItemsLimit: currentSidebarRecentItemsLimit,
            initialStarEffectsEnabled: currentStarEffectsEnabled,
            initialAnimationEffectSettings: currentAnimationEffectSettings
        )
        appearanceVC.onThemeChanged = { [weak self] theme in
            self?.mainWindowController?.updateFilerTheme(theme)
        }
        appearanceVC.onTransparentBackgroundChanged = { [weak self] enabled in
            self?.mainWindowController?.updateTransparentBackground(enabled)
        }
        appearanceVC.onTransparentBackgroundOpacityChanged = { [weak self] opacity in
            self?.mainWindowController?.updateTransparentBackgroundOpacity(opacity)
        }
        appearanceVC.onActionFeedbackChanged = { [weak self] enabled in
            self?.mainWindowController?.updateActionFeedbackEnabled(enabled)
        }
        appearanceVC.onSpotlightSearchScopeChanged = { [weak self] scope in
            self?.mainWindowController?.updateSpotlightSearchScope(scope)
        }
        appearanceVC.onFileIconSizeChanged = { [weak self] size in
            self?.mainWindowController?.updateFileIconSize(size)
        }
        appearanceVC.onSidebarFavoritesVisibilityChanged = { [weak self] visible in
            self?.mainWindowController?.updateSidebarFavoritesVisible(visible)
        }
        appearanceVC.onSidebarRecentItemsLimitChanged = { [weak self] limit in
            self?.mainWindowController?.updateSidebarRecentItemsLimit(limit)
        }
        appearanceVC.onStarEffectsChanged = { [weak self] enabled in
            self?.mainWindowController?.updateStarEffectsEnabled(enabled)
        }
        appearanceVC.onAnimationEffectSettingsChanged = { [weak self] settings in
            self?.mainWindowController?.updateAnimationEffectSettings(settings)
        }

        let keybindingsVC = KeybindingsViewController()
        keybindingsVC.onKeybindingsChanged = { [weak self] in
            self?.mainWindowController?.reloadKeybindings()
        }

        let bookmarksVC = BookmarksSettingsViewController(
            securityScopedBookmarkService: securityScopedBookmarkService
        )
        bookmarksVC.onBookmarksChanged = { [weak self] in
            self?.mainWindowController?.reloadBookmarksConfig()
        }

        let advancedVC = AdvancedSettingsViewController()

        let controller = SettingsWindowController(
            appearanceVC: appearanceVC,
            keybindingsVC: keybindingsVC,
            bookmarksVC: bookmarksVC,
            advancedVC: advancedVC
        )
        controller.showWindow(self)
        settingsWindowController = controller
    }
}
