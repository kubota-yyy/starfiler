import XCTest
@testable import Starfiler

@MainActor
final class SidebarViewModelTests: XCTestCase {

    // MARK: - Properties

    private var tempConfigDir: URL!
    private var configManager: ConfigManager!

    // MARK: - Setup

    override func setUp() {
        super.setUp()
        tempConfigDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("SidebarTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempConfigDir, withIntermediateDirectories: true)
        configManager = ConfigManager(configDirectory: tempConfigDir)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempConfigDir)
        super.tearDown()
    }

    // MARK: - Tests

    func testInitialSectionsContainFavorites() {
        let sut = SidebarViewModel(configManager: configManager)

        // Default config has sidebarFavoritesVisible = true, so favorites section should exist
        XCTAssertFalse(sut.sections.isEmpty)
        XCTAssertTrue(sut.sections.contains(where: { $0.kind == .favorites }))
    }

    func testReloadSectionsUpdatesAfterConfigChange() throws {
        let sut = SidebarViewModel(configManager: configManager)
        let initialCount = sut.sections.count

        // Add a bookmark group to the config
        let group = BookmarkGroup(
            name: "Projects",
            entries: [BookmarkEntry(displayName: "Project A", path: "/tmp/projectA")],
            shortcutKey: "p",
            isDefault: false
        )
        let existingConfig = configManager.loadBookmarksConfig()
        var newConfig = existingConfig
        newConfig.groups.append(group)
        try configManager.saveBookmarksConfig(newConfig)

        sut.reloadSections()

        XCTAssertTrue(sut.sections.count > initialCount)
        XCTAssertTrue(sut.sections.contains(where: {
            if case .bookmarkGroup(let name) = $0.kind { return name == "Projects" }
            return false
        }))
    }

    func testOnSectionsChangedCallbackFires() {
        var callbackFired = false
        let sut = SidebarViewModel(configManager: configManager)
        sut.onSectionsChanged = { _ in callbackFired = true }

        sut.reloadSections()

        XCTAssertTrue(callbackFired)
    }

    func testUpdateNavigationHistoryAddsSection() {
        let sut = SidebarViewModel(configManager: configManager)

        sut.updateNavigationHistory(
            backStack: [URL(fileURLWithPath: "/tmp/a")],
            currentURL: URL(fileURLWithPath: "/tmp/b"),
            forwardStack: [URL(fileURLWithPath: "/tmp/c")],
            paneSide: .left
        )

        XCTAssertTrue(sut.sections.contains(where: { $0.kind == .recent }))
        let recentSection = sut.sections.first(where: { $0.kind == .recent })
        XCTAssertEqual(recentSection?.title, "History (Left)")
        // 3 entries: a (back), b (current), c (forward)
        XCTAssertEqual(recentSection?.items.count, 3)
    }

    func testRemoveBookmarkEntry() throws {
        let group = BookmarkGroup(
            name: "TestGroup",
            entries: [
                BookmarkEntry(displayName: "Entry1", path: "/tmp/entry1"),
                BookmarkEntry(displayName: "Entry2", path: "/tmp/entry2"),
            ],
            shortcutKey: nil,
            isDefault: false
        )
        let config = BookmarksConfig(groups: [group])
        try configManager.saveBookmarksConfig(config)

        let sut = SidebarViewModel(configManager: configManager)
        let entry = SidebarViewModel.SidebarEntry(
            displayName: "Entry1",
            path: "/tmp/entry1",
            iconName: "folder"
        )

        sut.removeBookmarkEntry(entry, fromGroup: "TestGroup")

        // Reload config and verify entry was removed
        let updatedConfig = configManager.loadBookmarksConfig()
        let updatedGroup = updatedConfig.groups.first(where: { $0.name == "TestGroup" })
        XCTAssertEqual(updatedGroup?.entries.count, 1)
        XCTAssertEqual(updatedGroup?.entries.first?.displayName, "Entry2")
    }
}
