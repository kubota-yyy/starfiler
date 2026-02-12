import XCTest
@testable import Starfiler

@MainActor
final class PinnedItemsServiceTests: XCTestCase {

    // MARK: - Properties

    private var tempConfigDir: URL!
    private var configManager: ConfigManager!

    // MARK: - Setup

    override func setUp() {
        super.setUp()
        tempConfigDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("PinnedItemsTests-\(UUID().uuidString)", isDirectory: true)
        configManager = ConfigManager(configDirectory: tempConfigDir)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempConfigDir)
        super.tearDown()
    }

    // MARK: - Helpers

    private func makeSUT() -> PinnedItemsService {
        PinnedItemsService(configManager: configManager)
    }

    // MARK: - pin / unpin

    func testPinAddsItem() {
        let sut = makeSUT()
        let url = URL(fileURLWithPath: "/tmp/test")

        sut.pin(url: url, isDirectory: true)

        XCTAssertTrue(sut.isPinned(path: url.standardizedFileURL.path))
        XCTAssertEqual(sut.allPinnedItems().count, 1)
        XCTAssertEqual(sut.allPinnedItems().first?.displayName, "test")
    }

    func testPinDuplicatePathDoesNotAddTwice() {
        let sut = makeSUT()
        let url = URL(fileURLWithPath: "/tmp/test")

        sut.pin(url: url, isDirectory: true)
        sut.pin(url: url, isDirectory: true)

        XCTAssertEqual(sut.allPinnedItems().count, 1)
    }

    func testUnpinRemovesItem() {
        let sut = makeSUT()
        let url = URL(fileURLWithPath: "/tmp/test")

        sut.pin(url: url, isDirectory: true)
        sut.unpin(path: url.standardizedFileURL.path)

        XCTAssertFalse(sut.isPinned(path: url.standardizedFileURL.path))
        XCTAssertEqual(sut.allPinnedItems().count, 0)
    }

    func testUnpinNonexistentPathDoesNothing() {
        let sut = makeSUT()

        sut.unpin(path: "/nonexistent")

        XCTAssertEqual(sut.allPinnedItems().count, 0)
    }

    // MARK: - togglePin

    func testTogglePinAddsWhenNotPinned() {
        let sut = makeSUT()
        let url = URL(fileURLWithPath: "/tmp/test")

        sut.togglePin(for: url, isDirectory: true)

        XCTAssertTrue(sut.isPinned(path: url.standardizedFileURL.path))
    }

    func testTogglePinRemovesWhenPinned() {
        let sut = makeSUT()
        let url = URL(fileURLWithPath: "/tmp/test")

        sut.pin(url: url, isDirectory: true)
        sut.togglePin(for: url, isDirectory: true)

        XCTAssertFalse(sut.isPinned(path: url.standardizedFileURL.path))
    }

    // MARK: - isPinned

    func testIsPinnedReturnsFalseForUnknownPath() {
        let sut = makeSUT()

        XCTAssertFalse(sut.isPinned(path: "/nonexistent"))
    }

    // MARK: - allPinnedItems

    func testAllPinnedItemsReturnsSortedByDate() async {
        let sut = makeSUT()
        let url1 = URL(fileURLWithPath: "/tmp/first")
        let url2 = URL(fileURLWithPath: "/tmp/second")

        sut.pin(url: url1, isDirectory: true)
        try? await Task.sleep(for: .milliseconds(10))
        sut.pin(url: url2, isDirectory: true)

        let items = sut.allPinnedItems()
        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(items[0].displayName, "second")
        XCTAssertEqual(items[1].displayName, "first")
    }

    // MARK: - clearAllPins

    func testClearAllPinsRemovesEverything() {
        let sut = makeSUT()
        sut.pin(url: URL(fileURLWithPath: "/tmp/a"), isDirectory: true)
        sut.pin(url: URL(fileURLWithPath: "/tmp/b"), isDirectory: false)

        sut.clearAllPins()

        XCTAssertEqual(sut.allPinnedItems().count, 0)
    }

    // MARK: - maxItems

    func testMaxItemsLimitIsEnforced() {
        var config = PinnedItemsConfig()
        config.maxItems = 3
        try? configManager.savePinnedItemsConfig(config)
        let sut = makeSUT()

        for i in 0 ..< 5 {
            sut.pin(url: URL(fileURLWithPath: "/tmp/item\(i)"), isDirectory: true)
        }

        XCTAssertEqual(sut.allPinnedItems().count, 3)
    }

    // MARK: - File pinning

    func testPinFileItem() {
        let sut = makeSUT()
        let url = URL(fileURLWithPath: "/tmp/file.txt")

        sut.pin(url: url, isDirectory: false)

        let items = sut.allPinnedItems()
        XCTAssertEqual(items.count, 1)
        XCTAssertFalse(items[0].isDirectory)
        XCTAssertEqual(items[0].displayName, "file.txt")
    }
}
