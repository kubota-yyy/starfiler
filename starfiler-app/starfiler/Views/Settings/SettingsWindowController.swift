import AppKit

final class SettingsWindowController: NSWindowController {
    private let tabViewController = NSTabViewController()

    init(
        appearanceVC: AppearanceSettingsViewController,
        keybindingsVC: KeybindingsViewController,
        bookmarksVC: BookmarksSettingsViewController,
        advancedVC: AdvancedSettingsViewController
    ) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 500),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Settings"
        window.minSize = NSSize(width: 500, height: 400)

        super.init(window: window)

        tabViewController.tabStyle = .toolbar

        let appearanceItem = NSTabViewItem(viewController: appearanceVC)
        appearanceItem.label = "Appearance"
        appearanceItem.image = NSImage(systemSymbolName: "paintbrush", accessibilityDescription: "Appearance")

        let keybindingsItem = NSTabViewItem(viewController: keybindingsVC)
        keybindingsItem.label = "Keybindings"
        keybindingsItem.image = NSImage(systemSymbolName: "keyboard", accessibilityDescription: "Keybindings")

        let bookmarksItem = NSTabViewItem(viewController: bookmarksVC)
        bookmarksItem.label = "Bookmarks"
        bookmarksItem.image = NSImage(systemSymbolName: "bookmark", accessibilityDescription: "Bookmarks")

        let advancedItem = NSTabViewItem(viewController: advancedVC)
        advancedItem.label = "Advanced"
        advancedItem.image = NSImage(systemSymbolName: "gearshape.2", accessibilityDescription: "Advanced")

        tabViewController.addTabViewItem(appearanceItem)
        tabViewController.addTabViewItem(keybindingsItem)
        tabViewController.addTabViewItem(bookmarksItem)
        tabViewController.addTabViewItem(advancedItem)

        window.contentViewController = tabViewController
        window.center()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
