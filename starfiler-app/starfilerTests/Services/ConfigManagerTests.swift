import XCTest
@testable import Starfiler

final class ConfigManagerTests: XCTestCase {

    // MARK: - Properties

    private var tempConfigDir: URL!
    private var sut: ConfigManager!

    // MARK: - Setup

    override func setUp() {
        super.setUp()
        tempConfigDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ConfigManagerTests-\(UUID().uuidString)", isDirectory: true)
        sut = ConfigManager(configDirectory: tempConfigDir)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempConfigDir)
        super.tearDown()
    }

    // MARK: - AppConfig

    func testLoadAppConfigReturnsDefaultWhenNoFile() {
        let config = sut.loadAppConfig()

        // Default AppConfig values
        XCTAssertTrue(config.showHiddenFiles)
        XCTAssertEqual(config.defaultSortColumn, .name)
        XCTAssertTrue(config.defaultSortAscending)
    }

    func testSaveAndLoadAppConfig() throws {
        var config = AppConfig()
        config.showHiddenFiles = false
        config.defaultSortColumn = .size
        config.defaultSortAscending = false

        try sut.saveAppConfig(config)
        let loaded = sut.loadAppConfig()

        XCTAssertFalse(loaded.showHiddenFiles)
        XCTAssertEqual(loaded.defaultSortColumn, .size)
        XCTAssertFalse(loaded.defaultSortAscending)
    }

    // MARK: - BookmarksConfig

    func testLoadBookmarksConfigReturnsDefaultWhenNoFile() {
        let config = sut.loadBookmarksConfig()

        XCTAssertTrue(config.groups.isEmpty)
    }

    func testSaveAndLoadBookmarksConfig() throws {
        let group = BookmarkGroup(
            name: "TestGroup",
            entries: [BookmarkEntry(displayName: "Test", path: "/tmp/test")],
            shortcutKey: "t",
            isDefault: false
        )
        let config = BookmarksConfig(groups: [group])

        try sut.saveBookmarksConfig(config)
        let loaded = sut.loadBookmarksConfig()

        XCTAssertEqual(loaded.groups.count, 1)
        XCTAssertEqual(loaded.groups[0].name, "TestGroup")
        XCTAssertEqual(loaded.groups[0].entries.count, 1)
        XCTAssertEqual(loaded.groups[0].entries[0].displayName, "Test")
    }

    // MARK: - BatchRenamePresetsConfig

    func testSaveAndLoadBatchRenamePresetsConfig() throws {
        let preset = BatchRenamePreset(
            name: "My Preset",
            rules: [.findReplace(find: "old", replace: "new")]
        )
        let config = BatchRenamePresetsConfig(presets: [preset])

        try sut.saveBatchRenamePresetsConfig(config)
        let loaded = sut.loadBatchRenamePresetsConfig()

        XCTAssertEqual(loaded.presets.count, 1)
        XCTAssertEqual(loaded.presets[0].name, "My Preset")
    }

    // MARK: - Config Directory

    func testConfigDirectoryIsCreated() {
        XCTAssertTrue(FileManager.default.fileExists(atPath: tempConfigDir.path))
    }

    func testConfigURLsPointToCorrectFiles() {
        XCTAssertTrue(sut.appConfigURL.path.hasSuffix("AppConfig.json"))
        XCTAssertTrue(sut.bookmarksConfigURL.path.hasSuffix("Bookmarks.json"))
        XCTAssertTrue(sut.batchRenamePresetsConfigURL.path.hasSuffix("BatchRenamePresets.json"))
        XCTAssertTrue(sut.syncletsConfigURL.path.hasSuffix("Synclets.json"))
        XCTAssertTrue(sut.visitHistoryConfigURL.path.hasSuffix("VisitHistory.json"))
        XCTAssertTrue(sut.pinnedItemsConfigURL.path.hasSuffix("PinnedItems.json"))
    }

    // MARK: - PinnedItemsConfig

    func testLoadPinnedItemsConfigReturnsDefaultWhenNoFile() {
        let config = sut.loadPinnedItemsConfig()

        XCTAssertTrue(config.items.isEmpty)
        XCTAssertEqual(config.maxItems, 50)
    }

    func testSaveAndLoadPinnedItemsConfig() throws {
        let item = PinnedItem(path: "/tmp/pinned", displayName: "pinned", isDirectory: true)
        let config = PinnedItemsConfig(items: [item], maxItems: 30)

        try sut.savePinnedItemsConfig(config)
        let loaded = sut.loadPinnedItemsConfig()

        XCTAssertEqual(loaded.items.count, 1)
        XCTAssertEqual(loaded.items[0].path, "/tmp/pinned")
        XCTAssertEqual(loaded.items[0].displayName, "pinned")
        XCTAssertTrue(loaded.items[0].isDirectory)
        XCTAssertEqual(loaded.maxItems, 30)
    }
}
