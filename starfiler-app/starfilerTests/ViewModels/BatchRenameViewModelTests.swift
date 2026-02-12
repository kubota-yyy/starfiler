import XCTest
@testable import Starfiler

@MainActor
final class BatchRenameViewModelTests: XCTestCase {

    // MARK: - Helpers

    private var mockRenameService: MockBatchRenameComputing!
    private var tempConfigDir: URL!
    private var configManager: ConfigManager!

    override func setUp() {
        super.setUp()
        mockRenameService = MockBatchRenameComputing()
        tempConfigDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("BatchRenameTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempConfigDir, withIntermediateDirectories: true)
        configManager = ConfigManager(configDirectory: tempConfigDir)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempConfigDir)
        super.tearDown()
    }

    private func makeFileItem(name: String) -> FileItem {
        FileItem(
            url: URL(fileURLWithPath: "/tmp/test/\(name)"),
            name: name,
            isDirectory: false,
            size: 1024,
            dateModified: Date(),
            isHidden: false,
            isSymlink: false,
            isPackage: false
        )
    }

    private func makeSUT(
        sourceFiles: [FileItem]? = nil,
        allDirectoryFiles: [FileItem]? = nil
    ) -> BatchRenameViewModel {
        let files = sourceFiles ?? [makeFileItem(name: "file1.txt"), makeFileItem(name: "file2.txt")]
        let allFiles = allDirectoryFiles ?? files
        return BatchRenameViewModel(
            sourceFiles: files,
            allDirectoryFiles: allFiles,
            configManager: configManager,
            renameService: mockRenameService
        )
    }

    // MARK: - Initial State

    func testInitialStateHasEmptyRulesAndPreview() {
        let sut = makeSUT()

        XCTAssertTrue(sut.rules.isEmpty)
        XCTAssertNil(sut.selectedRuleIndex)
        XCTAssertFalse(sut.canApply)
        XCTAssertEqual(sut.changedCount, 0)
        XCTAssertEqual(sut.conflictCount, 0)
    }

    // MARK: - addRule

    func testAddRuleAppendsAndSelectsIt() {
        let sut = makeSUT()
        let rule = BatchRenameRule.findReplace(find: "old", replace: "new")

        mockRenameService.computeNewNamesResult = [
            BatchRenameEntry(originalURL: URL(fileURLWithPath: "/tmp/test/file1.txt"), originalName: "file1.txt", newName: "new1.txt", hasConflict: false, errorMessage: nil),
            BatchRenameEntry(originalURL: URL(fileURLWithPath: "/tmp/test/file2.txt"), originalName: "file2.txt", newName: "new2.txt", hasConflict: false, errorMessage: nil),
        ]

        sut.addRule(rule)

        XCTAssertEqual(sut.rules.count, 1)
        XCTAssertEqual(sut.selectedRuleIndex, 0)
        XCTAssertEqual(mockRenameService.computeNewNamesCallCount, 1)
    }

    // MARK: - removeRule

    func testRemoveRuleRemovesAndAdjustsSelection() {
        let sut = makeSUT()
        mockRenameService.computeNewNamesResult = []

        sut.addRule(.findReplace(find: "a", replace: "b"))
        sut.addRule(.findReplace(find: "c", replace: "d"))
        XCTAssertEqual(sut.selectedRuleIndex, 1)

        sut.removeRule(at: 1)

        XCTAssertEqual(sut.rules.count, 1)
        XCTAssertEqual(sut.selectedRuleIndex, 0)
    }

    func testRemoveRuleSetsNilWhenEmpty() {
        let sut = makeSUT()
        mockRenameService.computeNewNamesResult = []

        sut.addRule(.findReplace(find: "a", replace: "b"))
        sut.removeRule(at: 0)

        XCTAssertTrue(sut.rules.isEmpty)
        XCTAssertNil(sut.selectedRuleIndex)
    }

    // MARK: - moveRuleUp / moveRuleDown

    func testMoveRuleUpSwapsRules() {
        let sut = makeSUT()
        mockRenameService.computeNewNamesResult = []

        let rule1 = BatchRenameRule.findReplace(find: "a", replace: "b")
        let rule2 = BatchRenameRule.findReplace(find: "c", replace: "d")
        sut.addRule(rule1)
        sut.addRule(rule2)

        sut.moveRuleUp(at: 1)

        XCTAssertEqual(sut.rules[0], rule2)
        XCTAssertEqual(sut.rules[1], rule1)
    }

    func testMoveRuleDownSwapsRules() {
        let sut = makeSUT()
        mockRenameService.computeNewNamesResult = []

        let rule1 = BatchRenameRule.findReplace(find: "a", replace: "b")
        let rule2 = BatchRenameRule.findReplace(find: "c", replace: "d")
        sut.addRule(rule1)
        sut.addRule(rule2)
        sut.selectedRuleIndex = 0

        sut.moveRuleDown(at: 0)

        XCTAssertEqual(sut.rules[0], rule2)
        XCTAssertEqual(sut.rules[1], rule1)
        XCTAssertEqual(sut.selectedRuleIndex, 1)
    }

    // MARK: - canApply / changedCount

    func testCanApplyIsTrueWhenChangesExist() {
        let sut = makeSUT()
        mockRenameService.computeNewNamesResult = [
            BatchRenameEntry(originalURL: URL(fileURLWithPath: "/tmp/test/file1.txt"), originalName: "file1.txt", newName: "renamed.txt", hasConflict: false, errorMessage: nil),
        ]

        sut.addRule(.findReplace(find: "file1", replace: "renamed"))

        XCTAssertTrue(sut.canApply)
        XCTAssertEqual(sut.changedCount, 1)
    }

    func testCanApplyIsFalseWhenConflictsExist() {
        let sut = makeSUT()
        mockRenameService.computeNewNamesResult = [
            BatchRenameEntry(originalURL: URL(fileURLWithPath: "/tmp/test/file1.txt"), originalName: "file1.txt", newName: "same.txt", hasConflict: true, errorMessage: "Conflict"),
            BatchRenameEntry(originalURL: URL(fileURLWithPath: "/tmp/test/file2.txt"), originalName: "file2.txt", newName: "same.txt", hasConflict: true, errorMessage: "Conflict"),
        ]

        sut.addRule(.findReplace(find: "file", replace: "same"))

        XCTAssertFalse(sut.canApply)
        XCTAssertTrue(sut.hasConflicts)
        XCTAssertEqual(sut.conflictCount, 2)
    }

    // MARK: - apply

    func testApplyCallsOnApplyRequestedWithChanges() {
        let sut = makeSUT()
        mockRenameService.computeNewNamesResult = [
            BatchRenameEntry(originalURL: URL(fileURLWithPath: "/tmp/test/file1.txt"), originalName: "file1.txt", newName: "renamed.txt", hasConflict: false, errorMessage: nil),
            BatchRenameEntry(originalURL: URL(fileURLWithPath: "/tmp/test/file2.txt"), originalName: "file2.txt", newName: "file2.txt", hasConflict: false, errorMessage: nil),
        ]
        sut.addRule(.findReplace(find: "file1", replace: "renamed"))

        var capturedChanges: [FileLocationChange]?
        sut.onApplyRequested = { changes in capturedChanges = changes }

        sut.apply()

        XCTAssertEqual(capturedChanges?.count, 1)
        XCTAssertEqual(capturedChanges?.first?.source, URL(fileURLWithPath: "/tmp/test/file1.txt"))
    }

    // MARK: - cancel

    func testCancelCallsOnDismissRequested() {
        let sut = makeSUT()
        var dismissed = false
        sut.onDismissRequested = { dismissed = true }

        sut.cancel()

        XCTAssertTrue(dismissed)
    }

    // MARK: - Presets

    func testSaveAndApplyPreset() {
        let sut = makeSUT()
        mockRenameService.computeNewNamesResult = []

        let rule = BatchRenameRule.findReplace(find: "a", replace: "b")
        sut.addRule(rule)
        sut.saveCurrentRulesAsPreset(name: "My Preset")

        XCTAssertEqual(sut.presets.count, 1)
        XCTAssertEqual(sut.presets[0].name, "My Preset")

        // Clear rules, then apply preset
        sut.removeRule(at: 0)
        XCTAssertTrue(sut.rules.isEmpty)

        sut.applyPreset(at: 0)
        XCTAssertEqual(sut.rules.count, 1)
        XCTAssertEqual(sut.selectedRuleIndex, 0)
    }

    func testDeletePreset() {
        let sut = makeSUT()
        mockRenameService.computeNewNamesResult = []

        sut.addRule(.findReplace(find: "a", replace: "b"))
        sut.saveCurrentRulesAsPreset(name: "Preset1")
        XCTAssertEqual(sut.presets.count, 1)

        sut.deletePreset(at: 0)
        XCTAssertTrue(sut.presets.isEmpty)
    }
}
