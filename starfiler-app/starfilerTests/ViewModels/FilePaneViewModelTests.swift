import XCTest
@testable import Starfiler

@MainActor
final class FilePaneViewModelTests: XCTestCase {

    // MARK: - Properties

    private var fileSystem: MockFileSystemService!
    private var bookmarkService: MockSecurityScopedBookmarkService!
    private var monitor: MockDirectoryMonitor!
    private var spotlight: MockSpotlightSearchService!

    private let testDir = URL(fileURLWithPath: "/tmp/test")

    // MARK: - Setup

    override func setUp() {
        super.setUp()
        fileSystem = MockFileSystemService()
        bookmarkService = MockSecurityScopedBookmarkService()
        monitor = MockDirectoryMonitor()
        spotlight = MockSpotlightSearchService()
    }

    // MARK: - Helpers

    private func makeFileItem(
        name: String,
        isDirectory: Bool = false,
        size: Int64 = 1024,
        dateModified: Date = Date(),
        isHidden: Bool = false,
        isPackage: Bool = false
    ) -> FileItem {
        FileItem(
            url: testDir.appendingPathComponent(name),
            name: name,
            isDirectory: isDirectory,
            size: size,
            dateModified: dateModified,
            isHidden: isHidden,
            isSymlink: false,
            isPackage: isPackage
        )
    }

    private var sampleItems: [FileItem] {
        [
            makeFileItem(name: "alpha.txt"),
            makeFileItem(name: "beta.txt"),
            makeFileItem(name: "gamma.txt"),
            makeFileItem(name: "delta.txt"),
            makeFileItem(name: "epsilon.txt"),
        ]
    }

    private func makeSUT(
        items: [FileItem]? = nil,
        showHiddenFiles: Bool = true,
        initialDirectory: URL? = nil
    ) -> FilePaneViewModel {
        let resolvedItems = items ?? sampleItems
        fileSystem.contentsOfDirectoryResult = .success(resolvedItems)
        return FilePaneViewModel(
            fileSystemService: fileSystem,
            securityScopedBookmarkService: bookmarkService,
            directoryMonitor: monitor,
            spotlightSearchService: spotlight,
            initialDirectory: initialDirectory ?? testDir
        )
    }

    private func waitForLoad() async {
        try? await Task.sleep(for: .milliseconds(100))
    }

    // MARK: - Initial State

    func testInitialLoadSetsDisplayedItems() async {
        let sut = makeSUT()
        await waitForLoad()

        XCTAssertEqual(sut.directoryContents.displayedItems.count, 5)
        XCTAssertEqual(sut.paneState.currentDirectory, testDir.standardizedFileURL)
    }

    func testInitialCursorIndexIsZero() async {
        let sut = makeSUT()
        await waitForLoad()

        XCTAssertEqual(sut.paneState.cursorIndex, 0)
    }

    func testInitialStateHasNoMarks() async {
        let sut = makeSUT()
        await waitForLoad()

        XCTAssertTrue(sut.paneState.markedIndices.isEmpty)
        XCTAssertEqual(sut.markedCount, 0)
    }

    // MARK: - selectedItem

    func testSelectedItemReturnsItemAtCursor() async {
        let sut = makeSUT()
        await waitForLoad()

        XCTAssertNotNil(sut.selectedItem)
        XCTAssertEqual(sut.selectedItem?.name, sut.directoryContents.displayedItems[0].name)
    }

    // MARK: - Navigation

    func testNavigateToChangesDirectory() async {
        let sut = makeSUT()
        await waitForLoad()

        let newDir = URL(fileURLWithPath: "/tmp/other")
        fileSystem.contentsOfDirectoryResult = .success([makeFileItem(name: "new.txt")])

        sut.navigate(to: newDir)
        await waitForLoad()

        XCTAssertEqual(sut.paneState.currentDirectory, newDir.standardizedFileURL)
    }

    func testNavigateToSameDirectoryIsNoOp() async {
        let sut = makeSUT()
        await waitForLoad()

        let initialCallCount = fileSystem.contentsOfDirectoryCallCount
        sut.navigate(to: testDir)
        await waitForLoad()

        // Should not reload since same directory
        XCTAssertEqual(fileSystem.contentsOfDirectoryCallCount, initialCallCount)
    }

    func testNavigatePushesHistory() async {
        let sut = makeSUT()
        await waitForLoad()

        let newDir = URL(fileURLWithPath: "/tmp/other")
        fileSystem.contentsOfDirectoryResult = .success([])

        sut.navigate(to: newDir)
        await waitForLoad()

        XCTAssertTrue(sut.canGoBack)
        XCTAssertFalse(sut.canGoForward)
    }

    func testGoBackReturnsToPreviousDirectory() async {
        let sut = makeSUT()
        await waitForLoad()

        let newDir = URL(fileURLWithPath: "/tmp/other")
        fileSystem.contentsOfDirectoryResult = .success([])
        sut.navigate(to: newDir)
        await waitForLoad()

        fileSystem.contentsOfDirectoryResult = .success(sampleItems)
        sut.goBack()
        await waitForLoad()

        XCTAssertEqual(sut.paneState.currentDirectory, testDir.standardizedFileURL)
        XCTAssertTrue(sut.canGoForward)
    }

    func testGoForwardReturnsToNextDirectory() async {
        let sut = makeSUT()
        await waitForLoad()

        let newDir = URL(fileURLWithPath: "/tmp/other")
        let otherItems = [makeFileItem(name: "other.txt")]
        fileSystem.contentsOfDirectoryResult = .success(otherItems)
        sut.navigate(to: newDir)
        await waitForLoad()

        fileSystem.contentsOfDirectoryResult = .success(sampleItems)
        sut.goBack()
        await waitForLoad()

        fileSystem.contentsOfDirectoryResult = .success(otherItems)
        sut.goForward()
        await waitForLoad()

        XCTAssertEqual(sut.paneState.currentDirectory, newDir.standardizedFileURL)
    }

    func testGoBackWhenNoHistoryDoesNothing() async {
        let sut = makeSUT()
        await waitForLoad()

        sut.goBack()
        await waitForLoad()

        XCTAssertEqual(sut.paneState.currentDirectory, testDir.standardizedFileURL)
    }

    func testGoToParentNavigatesUp() async {
        let deepDir = URL(fileURLWithPath: "/tmp/test/sub")
        fileSystem.contentsOfDirectoryResult = .success([])
        let sut = FilePaneViewModel(
            fileSystemService: fileSystem,
            securityScopedBookmarkService: bookmarkService,
            directoryMonitor: monitor,
            spotlightSearchService: spotlight,
            initialDirectory: deepDir
        )
        await waitForLoad()

        fileSystem.contentsOfDirectoryResult = .success(sampleItems)
        sut.goToParent()
        await waitForLoad()

        XCTAssertEqual(sut.paneState.currentDirectory.path, URL(fileURLWithPath: "/tmp/test").standardizedFileURL.path)
    }

    // MARK: - Cursor Movement

    func testMoveCursorDownIncrementsCursor() async {
        let sut = makeSUT()
        await waitForLoad()

        sut.moveCursorDown()

        XCTAssertEqual(sut.paneState.cursorIndex, 1)
    }

    func testMoveCursorUpDecrementsCursor() async {
        let sut = makeSUT()
        await waitForLoad()

        sut.moveCursorDown()
        sut.moveCursorDown()
        sut.moveCursorUp()

        XCTAssertEqual(sut.paneState.cursorIndex, 1)
    }

    func testMoveCursorDownClampsAtEnd() async {
        let items = [makeFileItem(name: "only.txt")]
        let sut = makeSUT(items: items)
        await waitForLoad()

        sut.moveCursorDown()
        sut.moveCursorDown()

        XCTAssertEqual(sut.paneState.cursorIndex, 0)
    }

    func testMoveCursorUpClampsAtZero() async {
        let sut = makeSUT()
        await waitForLoad()

        sut.moveCursorUp()

        XCTAssertEqual(sut.paneState.cursorIndex, 0)
    }

    func testMoveCursorToTop() async {
        let sut = makeSUT()
        await waitForLoad()

        sut.moveCursorDown()
        sut.moveCursorDown()
        sut.moveCursorDown()
        sut.moveCursorToTop()

        XCTAssertEqual(sut.paneState.cursorIndex, 0)
    }

    func testMoveCursorToBottom() async {
        let sut = makeSUT()
        await waitForLoad()

        sut.moveCursorToBottom()

        XCTAssertEqual(sut.paneState.cursorIndex, 4)
    }

    func testMoveCursorPageDown() async {
        let sut = makeSUT()
        await waitForLoad()

        sut.moveCursorPageDown(pageStep: 3)

        XCTAssertEqual(sut.paneState.cursorIndex, 3)
    }

    func testMoveCursorPageUp() async {
        let sut = makeSUT()
        await waitForLoad()

        sut.moveCursorToBottom()
        sut.moveCursorPageUp(pageStep: 3)

        XCTAssertEqual(sut.paneState.cursorIndex, 1)
    }

    // MARK: - Cursor Changed Callback

    func testOnCursorChangedCallbackFires() async {
        let sut = makeSUT()
        await waitForLoad()

        var capturedIndex: Int?
        sut.onCursorChanged = { index in capturedIndex = index }

        sut.moveCursorDown()

        XCTAssertEqual(capturedIndex, 1)
    }

    // MARK: - Marks

    func testToggleMarkAddsAndRemovesMark() async {
        let sut = makeSUT()
        await waitForLoad()

        sut.toggleMark()

        XCTAssertTrue(sut.paneState.markedIndices.contains(0))
        XCTAssertEqual(sut.markedCount, 1)

        sut.toggleMark()

        XCTAssertFalse(sut.paneState.markedIndices.contains(0))
        XCTAssertEqual(sut.markedCount, 0)
    }

    func testMarkAllMarksEverything() async {
        let sut = makeSUT()
        await waitForLoad()

        sut.markAll()

        XCTAssertEqual(sut.markedCount, 5)
    }

    func testClearMarksRemovesAll() async {
        let sut = makeSUT()
        await waitForLoad()

        sut.markAll()
        sut.clearMarks()

        XCTAssertEqual(sut.markedCount, 0)
    }

    func testOnMarkedIndicesChangedCallbackFires() async {
        let sut = makeSUT()
        await waitForLoad()

        var capturedIndices: IndexSet?
        sut.onMarkedIndicesChanged = { indices in capturedIndices = indices }

        sut.toggleMark()

        XCTAssertNotNil(capturedIndices)
        XCTAssertTrue(capturedIndices?.contains(0) == true)
    }

    func testMarkedOrSelectedURLsReturnsMarkedWhenPresent() async {
        let sut = makeSUT()
        await waitForLoad()

        sut.moveCursorDown()
        sut.toggleMark()
        sut.moveCursorDown()
        sut.toggleMark()

        let urls = sut.markedOrSelectedURLs()
        XCTAssertEqual(urls.count, 2)
    }

    func testMarkedOrSelectedURLsReturnsSelectedWhenNoMarks() async {
        let sut = makeSUT()
        await waitForLoad()

        sut.moveCursorDown()

        let urls = sut.markedOrSelectedURLs()
        XCTAssertEqual(urls.count, 1)
    }

    // MARK: - Visual Mode

    func testEnterVisualModeSetsAnchor() async {
        let sut = makeSUT()
        await waitForLoad()

        sut.enterVisualMode()

        XCTAssertTrue(sut.isVisualMode)
        XCTAssertEqual(sut.paneState.visualAnchorIndex, 0)
    }

    func testVisualModeSelectionExpandsOnCursorMove() async {
        let sut = makeSUT()
        await waitForLoad()

        sut.enterVisualMode()
        sut.moveCursorDown()
        sut.moveCursorDown()

        // Visual mode should mark indices 0 through 2
        XCTAssertEqual(sut.paneState.markedIndices, IndexSet(integersIn: 0...2))
    }

    func testExitVisualModeClearsAnchor() async {
        let sut = makeSUT()
        await waitForLoad()

        sut.enterVisualMode()
        sut.exitVisualMode()

        XCTAssertFalse(sut.isVisualMode)
        XCTAssertNil(sut.paneState.visualAnchorIndex)
    }

    func testEnterVisualModeWithEmptyListDoesNothing() async {
        let sut = makeSUT(items: [])
        await waitForLoad()

        sut.enterVisualMode()

        XCTAssertFalse(sut.isVisualMode)
    }

    // MARK: - Filter

    func testSetFilterTextFiltersItems() async {
        let sut = makeSUT()
        await waitForLoad()

        sut.setFilterText("alpha")

        XCTAssertEqual(sut.directoryContents.displayedItems.count, 1)
        XCTAssertEqual(sut.directoryContents.displayedItems[0].name, "alpha.txt")
    }

    func testClearFilterRestoresAllItems() async {
        let sut = makeSUT()
        await waitForCondition(timeout: 2.0, description: "Items loaded") {
            sut.directoryContents.displayedItems.count == 5
        }

        sut.setFilterText("alpha")
        XCTAssertEqual(sut.directoryContents.displayedItems.count, 1)

        sut.clearFilter()

        XCTAssertEqual(sut.directoryContents.displayedItems.count, 5)
    }

    func testFilterClampsMarkedIndices() async {
        let sut = makeSUT()
        await waitForLoad()

        sut.moveCursorDown()
        sut.moveCursorDown()
        sut.moveCursorDown()
        sut.moveCursorDown()
        sut.toggleMark() // mark index 4

        sut.setFilterText("alpha") // leaves only 1 item

        // Marked index 4 should be removed since it's out of bounds
        XCTAssertTrue(sut.paneState.markedIndices.isEmpty)
    }

    // MARK: - Sort

    func testSetSortDescriptorResorts() async {
        let items = [
            makeFileItem(name: "banana.txt", size: 100),
            makeFileItem(name: "apple.txt", size: 200),
        ]
        let sut = makeSUT(items: items)
        await waitForLoad()

        // Default sort is by name ascending: apple, banana
        XCTAssertEqual(sut.directoryContents.displayedItems[0].name, "apple.txt")

        sut.setSortDescriptor(.size(ascending: true))

        XCTAssertEqual(sut.directoryContents.displayedItems[0].name, "banana.txt")
        XCTAssertEqual(sut.directoryContents.displayedItems[1].name, "apple.txt")
    }

    func testReverseSortOrderTogglesDirection() async {
        let sut = makeSUT()
        await waitForLoad()

        XCTAssertTrue(sut.directoryContents.sortDescriptor.ascending)

        sut.reverseSortOrder()

        XCTAssertFalse(sut.directoryContents.sortDescriptor.ascending)
    }

    func testCycleSortMode() async {
        let sut = makeSUT()
        await waitForLoad()

        // name -> size -> date -> selection -> name
        XCTAssertEqual(sut.directoryContents.sortDescriptor.column, .name)

        sut.cycleSortMode()
        XCTAssertEqual(sut.directoryContents.sortDescriptor.column, .size)

        sut.cycleSortMode()
        XCTAssertEqual(sut.directoryContents.sortDescriptor.column, .date)

        sut.cycleSortMode()
        XCTAssertEqual(sut.directoryContents.sortDescriptor.column, .selection)

        sut.cycleSortMode()
        XCTAssertEqual(sut.directoryContents.sortDescriptor.column, .name)
    }

    // MARK: - Display Mode

    func testToggleDisplayMode() async {
        let sut = makeSUT()
        await waitForLoad()

        XCTAssertEqual(sut.displayMode, .browser)

        fileSystem.contentsOfDirectoryResult = .success([])
        sut.toggleDisplayMode()

        XCTAssertEqual(sut.displayMode, .media)
    }

    func testOnDisplayModeChangedCallbackFires() async {
        let sut = makeSUT()
        await waitForLoad()

        var capturedMode: PaneDisplayMode?
        sut.onDisplayModeChanged = { mode in capturedMode = mode }

        fileSystem.contentsOfDirectoryResult = .success([])
        sut.toggleDisplayMode()
        await waitForLoad()

        XCTAssertEqual(capturedMode, .media)
    }

    // MARK: - Directory Changed Callback

    func testOnDirectoryChangedCallbackFires() async {
        let sut = makeSUT()
        await waitForLoad()

        var capturedURL: URL?
        sut.onDirectoryChanged = { url in capturedURL = url }

        let newDir = URL(fileURLWithPath: "/tmp/other")
        fileSystem.contentsOfDirectoryResult = .success([])
        sut.navigate(to: newDir)
        await waitForLoad()

        XCTAssertEqual(capturedURL, newDir.standardizedFileURL)
    }

    // MARK: - Items Changed Callback

    func testOnItemsChangedCallbackFires() async {
        let sut = makeSUT()

        var capturedItems: [FileItem]?
        sut.onItemsChanged = { items in capturedItems = items }

        await waitForLoad()

        XCTAssertNotNil(capturedItems)
        XCTAssertEqual(capturedItems?.count, 5)
    }

    // MARK: - Navigation clears marks

    func testNavigateClearsMarks() async {
        let sut = makeSUT()
        await waitForLoad()

        sut.markAll()
        XCTAssertEqual(sut.markedCount, 5)

        let newDir = URL(fileURLWithPath: "/tmp/other")
        fileSystem.contentsOfDirectoryResult = .success([makeFileItem(name: "new.txt")])
        sut.navigate(to: newDir)
        await waitForLoad()

        XCTAssertEqual(sut.markedCount, 0)
    }

    // MARK: - Security Scoped Bookmark

    func testNavigateCallsStartAccessing() async {
        let sut = makeSUT()
        await waitForLoad()

        let newDir = URL(fileURLWithPath: "/tmp/other")
        fileSystem.contentsOfDirectoryResult = .success([])
        sut.navigate(to: newDir)
        await waitForLoad()

        XCTAssertTrue(bookmarkService.startAccessingCallCount >= 2) // once for initial, once for navigate
    }

    // MARK: - Directory Monitor

    func testMonitorStartedAfterLoad() async {
        let sut = makeSUT()
        await waitForLoad()
        _ = sut // suppress unused warning

        XCTAssertTrue(monitor.startMonitoringCallCount >= 1)
    }

    func testSuspendAndResumeMonitoring() async {
        let sut = makeSUT()
        await waitForLoad()

        sut.suspendDirectoryMonitoring()
        XCTAssertEqual(monitor.suspendCallCount, 1)

        sut.resumeDirectoryMonitoring()
        XCTAssertEqual(monitor.resumeCallCount, 1)
    }

    // MARK: - Hidden Files

    func testToggleHiddenFilesChangesVisibility() async {
        let items = [
            makeFileItem(name: "visible.txt", isHidden: false),
            makeFileItem(name: ".hidden", isHidden: true),
        ]
        let sut = makeSUT(items: items)
        await waitForLoad()

        // By default showHiddenFiles is false
        let initialCount = sut.directoryContents.displayedItems.count

        sut.toggleHiddenFiles()

        let afterToggle = sut.directoryContents.displayedItems.count
        // Either showed or hid - should be different from initial
        XCTAssertNotEqual(initialCount, afterToggle)
    }

    // MARK: - enterSelected

    func testEnterSelectedNavigatesToDirectory() async {
        let dirItem = makeFileItem(name: "SubDir", isDirectory: true)
        let sut = makeSUT(items: [dirItem])
        await waitForLoad()

        fileSystem.contentsOfDirectoryResult = .success([])
        sut.enterSelected()
        await waitForLoad()

        XCTAssertEqual(
            sut.paneState.currentDirectory,
            testDir.appendingPathComponent("SubDir").standardizedFileURL
        )
    }

    func testEnterSelectedDoesNothingForFile() async {
        let sut = makeSUT()
        await waitForLoad()

        let originalDir = sut.paneState.currentDirectory
        sut.enterSelected()
        await waitForLoad()

        XCTAssertEqual(sut.paneState.currentDirectory, originalDir)
    }

    func testEnterSelectedDoesNothingForPackage() async {
        let pkg = makeFileItem(name: "App.app", isDirectory: true, isPackage: true)
        let sut = makeSUT(items: [pkg])
        await waitForLoad()

        let originalDir = sut.paneState.currentDirectory
        sut.enterSelected()
        await waitForLoad()

        XCTAssertEqual(sut.paneState.currentDirectory, originalDir)
    }

    // MARK: - Sort Mode Display Text

    func testSortModeDisplayText() async {
        let sut = makeSUT()
        await waitForLoad()

        XCTAssertTrue(sut.sortModeDisplayText.contains("Name"))

        sut.setSortDescriptor(.size(ascending: false))
        XCTAssertTrue(sut.sortModeDisplayText.contains("Size"))
        XCTAssertTrue(sut.sortModeDisplayText.contains("Desc"))

        sut.setSortDescriptor(.date(ascending: true))
        XCTAssertTrue(sut.sortModeDisplayText.contains("Date"))
        XCTAssertTrue(sut.sortModeDisplayText.contains("Asc"))
    }
}
