import XCTest
@testable import Starfiler

@MainActor
final class SyncViewModelTests: XCTestCase {

    // MARK: - Properties

    private var mockComparison: MockDirectoryComparing!
    private var mockExecution: MockSyncExecuting!
    private var tempConfigDir: URL!
    private var configManager: ConfigManager!

    private let leftDir = URL(fileURLWithPath: "/tmp/left")
    private let rightDir = URL(fileURLWithPath: "/tmp/right")

    // MARK: - Setup

    override func setUp() {
        super.setUp()
        mockComparison = MockDirectoryComparing()
        mockExecution = MockSyncExecuting()
        tempConfigDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("SyncTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempConfigDir, withIntermediateDirectories: true)
        configManager = ConfigManager(configDirectory: tempConfigDir)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempConfigDir)
        super.tearDown()
    }

    // MARK: - Helpers

    private func makeSUT() -> SyncViewModel {
        SyncViewModel(
            leftDirectory: leftDir,
            rightDirectory: rightDir,
            comparisonService: mockComparison,
            executionService: mockExecution,
            configManager: configManager
        )
    }

    private func makeSyncItem(
        relativePath: String,
        status: SyncItemStatus = .leftOnly,
        action: SyncItemAction = .copyToRight
    ) -> SyncItem {
        SyncItem(
            relativePath: relativePath,
            isDirectory: false,
            leftURL: leftDir.appendingPathComponent(relativePath),
            rightURL: nil,
            leftSize: 1024,
            rightSize: nil,
            leftDate: Date(),
            rightDate: nil,
            status: status,
            action: action
        )
    }

    // MARK: - Initial State

    func testInitialState() {
        let sut = makeSUT()

        XCTAssertEqual(sut.direction, .leftToRight)
        XCTAssertFalse(sut.isBusy)
        XCTAssertFalse(sut.isPreviewReady)
        XCTAssertFalse(sut.canSync)
        XCTAssertTrue(sut.items.isEmpty)
    }

    // MARK: - Compare

    func testComparePopulatesItems() async {
        let sut = makeSUT()
        let syncItems = [
            makeSyncItem(relativePath: "file1.txt"),
            makeSyncItem(relativePath: "file2.txt"),
        ]
        mockComparison.compareResult = .success(syncItems)

        sut.compare()
        try? await Task.sleep(for: .milliseconds(200))

        XCTAssertEqual(sut.items.count, 2)
        XCTAssertTrue(sut.isPreviewReady)
        XCTAssertEqual(mockComparison.compareCallCount, 1)
    }

    func testCompareErrorSetsErrorPhase() async {
        let sut = makeSUT()
        mockComparison.compareResult = .failure(NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Test error"]))

        sut.compare()
        try? await Task.sleep(for: .milliseconds(200))

        if case .error(let message) = sut.phase {
            XCTAssertEqual(message, "Test error")
        } else {
            XCTFail("Expected error phase")
        }
    }

    // MARK: - Item Selection

    func testToggleItemSelection() async {
        let sut = makeSUT()
        mockComparison.compareResult = .success([makeSyncItem(relativePath: "file.txt")])
        sut.compare()
        try? await Task.sleep(for: .milliseconds(200))

        sut.toggleItemSelection(at: 0)

        XCTAssertFalse(sut.items[0].isSelected)

        sut.toggleItemSelection(at: 0)

        XCTAssertTrue(sut.items[0].isSelected)
    }

    func testSelectAll() async {
        let sut = makeSUT()
        mockComparison.compareResult = .success([
            makeSyncItem(relativePath: "file1.txt"),
            makeSyncItem(relativePath: "file2.txt"),
        ])
        sut.compare()
        try? await Task.sleep(for: .milliseconds(200))

        sut.deselectAll()
        XCTAssertEqual(sut.selectedCount, 0)

        sut.selectAll()
        XCTAssertEqual(sut.selectedCount, 2)
    }

    func testDeselectAll() async {
        let sut = makeSUT()
        mockComparison.compareResult = .success([
            makeSyncItem(relativePath: "file1.txt"),
        ])
        sut.compare()
        try? await Task.sleep(for: .milliseconds(200))

        sut.deselectAll()

        XCTAssertEqual(sut.selectedCount, 0)
    }

    // MARK: - Set Item Action

    func testSetItemAction() async {
        let sut = makeSUT()
        mockComparison.compareResult = .success([makeSyncItem(relativePath: "file.txt")])
        sut.compare()
        try? await Task.sleep(for: .milliseconds(200))

        sut.setItemAction(.skip, at: 0)

        XCTAssertEqual(sut.items[0].action, .skip)
        XCTAssertFalse(sut.items[0].isSelected)
    }

    // MARK: - Filtered Items

    func testFilteredItemsExcludesIdentical() async {
        let sut = makeSUT()
        mockComparison.compareResult = .success([
            makeSyncItem(relativePath: "changed.txt", status: .leftOnly),
            makeSyncItem(relativePath: "same.txt", status: .identical, action: .skip),
        ])
        sut.compare()
        try? await Task.sleep(for: .milliseconds(200))

        XCTAssertFalse(sut.showIdentical)
        XCTAssertEqual(sut.filteredItems.count, 1)
        XCTAssertEqual(sut.filteredItems[0].relativePath, "changed.txt")
    }

    // MARK: - Exclude Rules

    func testAddExcludeRule() {
        let sut = makeSUT()
        let initialCount = sut.excludeRules.count

        sut.addExcludeRule("*.log")

        XCTAssertEqual(sut.excludeRules.count, initialCount + 1)
        XCTAssertEqual(sut.excludeRules.last?.pattern, "*.log")
    }

    func testRemoveExcludeRule() {
        let sut = makeSUT()
        let initialCount = sut.excludeRules.count

        sut.removeExcludeRule(at: 0)

        XCTAssertEqual(sut.excludeRules.count, initialCount - 1)
    }

    func testToggleExcludeRule() {
        let sut = makeSUT()
        let initialEnabled = sut.excludeRules[0].isEnabled

        sut.toggleExcludeRule(at: 0)

        XCTAssertNotEqual(sut.excludeRules[0].isEnabled, initialEnabled)
    }

    // MARK: - Synclet Management

    func testSaveSynclet() {
        let sut = makeSUT()

        sut.saveSynclet(name: "Test Sync")

        XCTAssertEqual(sut.synclets.count, 1)
        XCTAssertEqual(sut.synclets[0].name, "Test Sync")
    }

    func testLoadSynclet() {
        let sut = makeSUT()
        let synclet = Synclet(
            name: "Saved",
            leftPath: "/tmp/savedLeft",
            rightPath: "/tmp/savedRight",
            direction: .rightToLeft
        )

        sut.loadSynclet(synclet)

        XCTAssertEqual(sut.leftDirectory.path, "/tmp/savedLeft")
        XCTAssertEqual(sut.rightDirectory.path, "/tmp/savedRight")
        XCTAssertEqual(sut.direction, .rightToLeft)
    }

    func testDeleteSynclet() {
        let sut = makeSUT()
        sut.saveSynclet(name: "ToDelete")
        let synclet = sut.synclets[0]

        sut.deleteSynclet(synclet)

        XCTAssertTrue(sut.synclets.isEmpty)
    }
}
