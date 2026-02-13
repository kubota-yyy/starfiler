import XCTest
@testable import Starfiler

@MainActor
final class MainViewModelTests: XCTestCase {

    // MARK: - Properties

    private var fileSystem: MockFileSystemService!
    private var bookmarkService: MockSecurityScopedBookmarkService!
    private var visitHistory: MockVisitHistoryService!
    private var fileOpQueue: FileOperationQueue!
    private var mockExecutor: MockFileOperationExecuting!

    private let testDir = URL(fileURLWithPath: "/tmp/test")

    // MARK: - Setup

    override func setUp() {
        super.setUp()
        fileSystem = MockFileSystemService()
        bookmarkService = MockSecurityScopedBookmarkService()
        visitHistory = MockVisitHistoryService()
        mockExecutor = MockFileOperationExecuting()
        fileOpQueue = FileOperationQueue(executor: mockExecutor)
        fileSystem.contentsOfDirectoryResult = .success([])
    }

    // MARK: - Helpers

    private func makeFileItem(name: String) -> FileItem {
        FileItem(
            url: testDir.appendingPathComponent(name),
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
        initialLeftDirectory: URL? = nil,
        initialRightDirectory: URL? = nil
    ) -> MainViewModel {
        MainViewModel(
            fileSystemService: fileSystem,
            securityScopedBookmarkService: bookmarkService,
            fileOperationQueue: fileOpQueue,
            visitHistoryService: visitHistory,
            pinnedItemsService: MockPinnedItemsService(),
            initialLeftDirectory: initialLeftDirectory ?? testDir,
            initialRightDirectory: initialRightDirectory ?? testDir
        )
    }

    private func waitForLoad() async {
        try? await Task.sleep(for: .milliseconds(100))
    }

    // MARK: - Active Pane Switching

    func testInitialActivePaneIsLeft() async {
        let sut = makeSUT()
        await waitForLoad()

        XCTAssertEqual(sut.activePaneSide, .left)
        XCTAssertTrue(sut.activePane === sut.leftPane)
    }

    func testSwitchActivePane() async {
        let sut = makeSUT()
        await waitForLoad()

        sut.switchActivePane()

        XCTAssertEqual(sut.activePaneSide, .right)
        XCTAssertTrue(sut.activePane === sut.rightPane)
    }

    func testSetActivePaneSide() async {
        let sut = makeSUT()
        await waitForLoad()

        sut.setActivePane(.right)

        XCTAssertEqual(sut.activePaneSide, .right)
        XCTAssertTrue(sut.activePane === sut.rightPane)
        XCTAssertTrue(sut.inactivePane === sut.leftPane)
    }

    func testSwitchActivePaneToggles() async {
        let sut = makeSUT()
        await waitForLoad()

        sut.switchActivePane()
        XCTAssertEqual(sut.activePaneSide, .right)

        sut.switchActivePane()
        XCTAssertEqual(sut.activePaneSide, .left)
    }

    // MARK: - Preview Toggle

    func testTogglePreviewPane() async {
        let sut = makeSUT()
        await waitForLoad()

        XCTAssertFalse(sut.previewVisible)

        sut.togglePreviewPane()
        XCTAssertTrue(sut.previewVisible)

        sut.togglePreviewPane()
        XCTAssertFalse(sut.previewVisible)
    }

    // MARK: - Sidebar Toggle

    func testToggleSidebar() async {
        let sut = makeSUT()
        await waitForLoad()

        XCTAssertTrue(sut.sidebarVisible)

        sut.toggleSidebar()
        XCTAssertFalse(sut.sidebarVisible)

        sut.toggleSidebar()
        XCTAssertTrue(sut.sidebarVisible)
    }

    // MARK: - Copy/Cut/Paste

    func testCopyMarkedSetsClipboard() async {
        let items = [makeFileItem(name: "file.txt")]
        fileSystem.contentsOfDirectoryResult = .success(items)
        let sut = makeSUT()
        await waitForLoad()

        sut.activePane.toggleMark()
        sut.copyMarked()
        await waitForLoad()

        XCTAssertFalse(sut.clipboard.isEmpty)
        XCTAssertEqual(sut.clipboardOperation, .copy)
    }

    func testCutMarkedSetsClipboardWithCutOperation() async {
        let items = [makeFileItem(name: "file.txt")]
        fileSystem.contentsOfDirectoryResult = .success(items)
        let sut = makeSUT()
        await waitForLoad()

        sut.activePane.toggleMark()
        sut.cutMarked()

        XCTAssertFalse(sut.clipboard.isEmpty)
        XCTAssertEqual(sut.clipboardOperation, .cut)
    }

    func testCopyMarkedWithNoSelectionDoesNothing() async {
        let sut = makeSUT()
        await waitForLoad()

        sut.copyMarked()
        await waitForLoad()

        XCTAssertTrue(sut.clipboard.isEmpty)
    }

    func testCopyMarkedToClipboardDoesNotExecuteOperation() async {
        let items = [makeFileItem(name: "file.txt")]
        fileSystem.contentsOfDirectoryResult = .success(items)
        let sut = makeSUT()
        await waitForLoad()

        sut.activePane.toggleMark()
        let copiedURLs = sut.copyMarkedToClipboard()
        await waitForLoad()

        XCTAssertEqual(copiedURLs, [items[0].url.standardizedFileURL])
        XCTAssertEqual(sut.clipboardOperation, .copy)
        XCTAssertEqual(mockExecutor.executeCallCount, 0)
    }

    func testPasteToActivePaneUsesActivePaneDirectoryAsDestination() async {
        let leftDir = URL(fileURLWithPath: "/tmp/left", isDirectory: true)
        let rightDir = URL(fileURLWithPath: "/tmp/right", isDirectory: true)
        let source = URL(fileURLWithPath: "/tmp/source/file.txt")
        let sut = makeSUT(initialLeftDirectory: leftDir, initialRightDirectory: rightDir)
        await waitForLoad()

        sut.replaceClipboard(urls: [source], operation: .copy)
        sut.setActivePane(.right)
        sut.pasteToActivePane()
        await waitForLoad()

        XCTAssertEqual(mockExecutor.executeCallCount, 1)
        XCTAssertEqual(
            mockExecutor.executeCapturedOperations.last,
            .copy(items: [source.standardizedFileURL], destinationDirectory: rightDir.standardizedFileURL)
        )
    }

    func testPasteToActivePaneAsMoveConvertsCopyClipboardIntoMoveOperation() async {
        let destinationDir = URL(fileURLWithPath: "/tmp/destination", isDirectory: true)
        let source = URL(fileURLWithPath: "/tmp/source/file.txt")
        let sut = makeSUT(initialLeftDirectory: destinationDir, initialRightDirectory: destinationDir)
        await waitForLoad()

        sut.replaceClipboard(urls: [source], operation: .copy)
        sut.pasteToActivePaneAsMove()
        await waitForLoad()

        let expectedMove = FileLocationChange(
            source: source.standardizedFileURL,
            destination: destinationDir.appendingPathComponent("file.txt", isDirectory: false).standardizedFileURL
        )

        XCTAssertEqual(mockExecutor.executeCallCount, 1)
        XCTAssertEqual(mockExecutor.executeCapturedOperations.last, .move(items: [expectedMove]))
    }

    func testPasteWithEmptyClipboardDoesNothing() async {
        let sut = makeSUT()
        await waitForLoad()

        sut.paste()
        await waitForLoad()

        XCTAssertEqual(mockExecutor.executeCallCount, 0)
    }

    // MARK: - Delete

    func testDeleteMarkedEnqueuesOperation() async {
        let items = [makeFileItem(name: "file.txt")]
        fileSystem.contentsOfDirectoryResult = .success(items)
        let sut = makeSUT()
        await waitForLoad()

        mockExecutor.executeResult = .success(
            FileOperationRecord(
                operation: .trash(items: [items[0].url]),
                result: .trashed([FileLocationChange(source: items[0].url, destination: items[0].url)]),
                timestamp: Date(),
                undoOperation: .trash(items: [])
            )
        )

        sut.activePane.toggleMark()
        sut.deleteMarked()
        await waitForLoad()

        XCTAssertEqual(mockExecutor.executeCallCount, 1)
    }

    func testDeleteWithEmptyURLsDoesNothing() async {
        let sut = makeSUT()
        await waitForLoad()

        sut.delete(urls: [])
        await waitForLoad()

        XCTAssertEqual(mockExecutor.executeCallCount, 0)
    }

    // MARK: - Rename

    func testRenameWithNoSelectedItemDoesNothing() async {
        let sut = makeSUT()
        await waitForLoad()

        sut.rename()
        await waitForLoad()

        XCTAssertEqual(mockExecutor.executeCallCount, 0)
    }

    func testRenameUsesTextInputPrompt() async {
        let items = [makeFileItem(name: "file.txt")]
        fileSystem.contentsOfDirectoryResult = .success(items)
        let sut = makeSUT()
        await waitForLoad()

        mockExecutor.executeResult = .success(
            FileOperationRecord(
                operation: .rename(item: items[0].url, newName: "newfile.txt"),
                result: .renamed(FileLocationChange(source: items[0].url, destination: testDir.appendingPathComponent("newfile.txt"))),
                timestamp: Date(),
                undoOperation: .rename(item: testDir.appendingPathComponent("newfile.txt"), newName: "file.txt")
            )
        )

        sut.requestTextInput = { _ in "newfile.txt" }
        sut.rename()
        await waitForLoad()

        XCTAssertEqual(mockExecutor.executeCallCount, 1)
    }

    // MARK: - Match/Move Pane Directories

    func testMatchOtherPaneDirectoryToActivePane() async {
        let leftDir = URL(fileURLWithPath: "/tmp/left")
        let rightDir = URL(fileURLWithPath: "/tmp/right")
        fileSystem.contentsOfDirectoryResult = .success([])
        let sut = MainViewModel(
            fileSystemService: fileSystem,
            securityScopedBookmarkService: bookmarkService,
            fileOperationQueue: fileOpQueue,
            visitHistoryService: visitHistory,
            pinnedItemsService: MockPinnedItemsService(),
            initialLeftDirectory: leftDir,
            initialRightDirectory: rightDir
        )
        await waitForLoad()

        let result = sut.matchOtherPaneDirectoryToActivePane()

        XCTAssertTrue(result)
    }

    func testMatchOtherPaneReturnsFalseWhenSameDirectory() async {
        let sut = makeSUT()
        await waitForLoad()

        let result = sut.matchOtherPaneDirectoryToActivePane()

        XCTAssertFalse(result)
    }

    // MARK: - onFileOperationCompleted

    func testOnFileOperationCompletedCallbackFires() async {
        let items = [makeFileItem(name: "file.txt")]
        fileSystem.contentsOfDirectoryResult = .success(items)
        let sut = makeSUT()
        await waitForLoad()

        let expectedRecord = FileOperationRecord(
            operation: .trash(items: [items[0].url]),
            result: .trashed([FileLocationChange(source: items[0].url, destination: items[0].url)]),
            timestamp: Date(),
            undoOperation: .trash(items: [])
        )
        mockExecutor.executeResult = .success(expectedRecord)

        var capturedRecord: FileOperationRecord?
        sut.onFileOperationCompleted = { record, _ in capturedRecord = record }

        sut.activePane.toggleMark()
        sut.deleteMarked()
        await waitForLoad()

        XCTAssertNotNil(capturedRecord)
    }

    // MARK: - Toggle Pin

    func testTogglePinForActivePanePinsCurrentDirectory() async {
        let pinnedService = MockPinnedItemsService()
        let sut = MainViewModel(
            fileSystemService: fileSystem,
            securityScopedBookmarkService: bookmarkService,
            fileOperationQueue: fileOpQueue,
            visitHistoryService: visitHistory,
            pinnedItemsService: pinnedService,
            initialLeftDirectory: testDir,
            initialRightDirectory: testDir
        )
        await waitForLoad()

        sut.togglePinForActivePane()

        XCTAssertEqual(pinnedService.togglePinCallCount, 1)
    }

    func testIsPinnedActiveItemReturnsFalseWhenNotPinned() async {
        let sut = makeSUT()
        await waitForLoad()

        XCTAssertFalse(sut.isPinnedActiveItem())
    }
}
