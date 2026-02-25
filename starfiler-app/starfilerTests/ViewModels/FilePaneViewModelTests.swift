import XCTest
@testable import Starfiler

@MainActor
final class FilePaneViewModelTests: XCTestCase {
    private enum TestError: Error {
        case refreshFailure
    }

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
        initialDirectory: URL? = nil,
        initialNavigationHistory: NavigationHistory = NavigationHistory()
    ) -> FilePaneViewModel {
        let resolvedItems = items ?? sampleItems
        fileSystem.contentsOfDirectoryResult = .success(resolvedItems)
        fileSystem.recursiveContentsOfDirectoryResult = .success(resolvedItems)
        return FilePaneViewModel(
            fileSystemService: fileSystem,
            securityScopedBookmarkService: bookmarkService,
            directoryMonitor: monitor,
            spotlightSearchService: spotlight,
            initialDirectory: initialDirectory ?? testDir,
            initialNavigationHistory: initialNavigationHistory
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

    func testInitialNavigationHistoryIsRestored() async {
        let previous = URL(fileURLWithPath: "/tmp/previous")
        let next = URL(fileURLWithPath: "/tmp/next")
        let history = NavigationHistory(backStack: [previous], forwardStack: [next])
        let sut = makeSUT(initialNavigationHistory: history)
        await waitForLoad()

        XCTAssertEqual(sut.navigationHistory.backStack, [previous.standardizedFileURL])
        XCTAssertEqual(sut.navigationHistory.forwardStack, [next.standardizedFileURL])
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

    func testGoToParentSelectsPreviousDirectoryInParent() async {
        let deepDir = URL(fileURLWithPath: "/tmp/test/sub")
        let siblingDir = URL(fileURLWithPath: "/tmp/test/aaa")

        fileSystem.contentsOfDirectoryResult = .success([])
        let sut = FilePaneViewModel(
            fileSystemService: fileSystem,
            securityScopedBookmarkService: bookmarkService,
            directoryMonitor: monitor,
            spotlightSearchService: spotlight,
            initialDirectory: deepDir
        )
        await waitForLoad()

        fileSystem.contentsOfDirectoryResult = .success([
            FileItem(
                url: siblingDir,
                name: "aaa",
                isDirectory: true,
                size: 0,
                dateModified: Date(),
                isHidden: false,
                isSymlink: false,
                isPackage: false
            ),
            FileItem(
                url: deepDir,
                name: "sub",
                isDirectory: true,
                size: 0,
                dateModified: Date(),
                isHidden: false,
                isSymlink: false,
                isPackage: false
            ),
        ])

        sut.goToParent()
        await waitForLoad()

        XCTAssertEqual(sut.paneState.currentDirectory.path, URL(fileURLWithPath: "/tmp/test").standardizedFileURL.path)
        XCTAssertEqual(sut.selectedItem?.url.standardizedFileURL, deepDir.standardizedFileURL)
    }

    // MARK: - Tree Expand/Collapse

    func testExpandSelectedFolderLoadsChildren() async {
        let folder = makeFileItem(name: "Folder", isDirectory: true)
        let child = FileItem(
            url: folder.url.appendingPathComponent("inside.txt"),
            name: "inside.txt",
            isDirectory: false,
            size: 1,
            dateModified: Date(),
            isHidden: false,
            isSymlink: false,
            isPackage: false
        )

        let sut = makeSUT(items: [folder])
        await waitForLoad()

        fileSystem.contentsOfDirectoryResult = .success([child])
        sut.expandSelectedFolder()
        await waitForCondition(timeout: 2.0, description: "Folder expansion") {
            sut.directoryContents.displayedItems.contains(where: { $0.url.standardizedFileURL == child.url.standardizedFileURL })
        }

        XCTAssertTrue(sut.directoryContents.displayedItems.contains(where: { $0.url.standardizedFileURL == child.url.standardizedFileURL }))
    }

    func testExpandSelectedFolderDoesNotMoveCursorWhenAlreadyExpanded() async {
        let folder = makeFileItem(name: "Folder", isDirectory: true)
        let child = FileItem(
            url: folder.url.appendingPathComponent("inside.txt"),
            name: "inside.txt",
            isDirectory: false,
            size: 1,
            dateModified: Date(),
            isHidden: false,
            isSymlink: false,
            isPackage: false
        )

        let sut = makeSUT(items: [folder])
        await waitForLoad()

        fileSystem.contentsOfDirectoryResult = .success([child])
        sut.expandSelectedFolder()
        await waitForCondition(timeout: 2.0, description: "Folder expansion before second expand") {
            sut.directoryContents.displayedItems.contains(where: { $0.url.standardizedFileURL == child.url.standardizedFileURL })
        }

        XCTAssertEqual(sut.paneState.cursorIndex, 0)

        sut.expandSelectedFolder()

        XCTAssertEqual(sut.paneState.cursorIndex, 0)
    }

    func testCollapseSelectedFolderHidesChildrenAfterExpansion() async {
        let folder = makeFileItem(name: "Folder", isDirectory: true)
        let child = FileItem(
            url: folder.url.appendingPathComponent("inside.txt"),
            name: "inside.txt",
            isDirectory: false,
            size: 1,
            dateModified: Date(),
            isHidden: false,
            isSymlink: false,
            isPackage: false
        )

        let sut = makeSUT(items: [folder])
        await waitForLoad()

        fileSystem.contentsOfDirectoryResult = .success([child])
        sut.expandSelectedFolder()
        await waitForCondition(timeout: 2.0, description: "Folder expansion before collapse") {
            sut.directoryContents.displayedItems.contains(where: { $0.url.standardizedFileURL == child.url.standardizedFileURL })
        }

        sut.collapseSelectedFolder()

        XCTAssertFalse(sut.directoryContents.displayedItems.contains(where: { $0.url.standardizedFileURL == child.url.standardizedFileURL }))
    }

    func testExpandSelectedFolderDoesNotCrashWhenDisplayedItemsContainDuplicateURLs() async {
        let folder = makeFileItem(name: "Folder", isDirectory: true)
        let child = FileItem(
            url: folder.url.appendingPathComponent("inside.txt"),
            name: "inside.txt",
            isDirectory: false,
            size: 1,
            dateModified: Date(),
            isHidden: false,
            isSymlink: false,
            isPackage: false
        )

        let sut = makeSUT(items: [folder])
        await waitForLoad()

        fileSystem.recursiveContentsOfDirectoryResult = .success([folder, child])
        sut.setFilesRecursiveEnabled(true)
        await waitForCondition(timeout: 2.0, description: "Recursive browser load") {
            sut.directoryContents.displayedItems.contains(where: { $0.url.standardizedFileURL == child.url.standardizedFileURL })
        }

        fileSystem.contentsOfDirectoryResult = .success([child])
        let beforeExpandCallCount = fileSystem.contentsOfDirectoryCallCount
        sut.expandSelectedFolder()
        await waitForCondition(timeout: 2.0, description: "Folder expansion in recursive mode") {
            self.fileSystem.contentsOfDirectoryCallCount > beforeExpandCallCount
        }

        XCTAssertEqual(sut.paneState.cursorIndex, 0)
        XCTAssertTrue(sut.directoryContents.displayedItems.contains(where: { $0.url.standardizedFileURL == child.url.standardizedFileURL }))
    }

    // MARK: - Spotlight Search

    func testEnterSpotlightSearchModeClearsMarksAndVisualAnchor() async {
        let sut = makeSUT()
        await waitForLoad()

        sut.toggleMark()
        sut.enterVisualMode()
        sut.enterSpotlightSearchMode()

        XCTAssertTrue(sut.paneState.markedIndices.isEmpty)
        XCTAssertNil(sut.paneState.visualAnchorIndex)
        XCTAssertEqual(sut.directoryContents.displayedItems.count, 0)
    }

    func testUpdateSpotlightSearchQueryUsesCurrentScopeAndAppliesResults() async {
        let spotlightFile = FileItem(
            url: URL(fileURLWithPath: "/tmp/spotlight-result.txt"),
            name: "spotlight-result.txt",
            isDirectory: false,
            size: 32,
            dateModified: Date(),
            isHidden: false,
            isSymlink: false,
            isPackage: false
        )

        let sut = makeSUT()
        await waitForLoad()

        spotlight.searchResults = [spotlightFile]
        sut.setSpotlightSearchScope(.userHome)
        sut.enterSpotlightSearchMode()
        sut.updateSpotlightSearchQuery("spot")
        await waitForLoad()

        XCTAssertEqual(spotlight.searchCallCount, 1)
        XCTAssertEqual(spotlight.searchCapturedArgs.last?.scope, .userHome)
        XCTAssertEqual(sut.directoryContents.displayedItems.map(\.name), [spotlightFile.name])
    }

    func testExitSpotlightSearchModeRestoresDirectoryContents() async {
        let sut = makeSUT(items: sampleItems)
        await waitForLoad()

        spotlight.searchResults = [makeFileItem(name: "filtered.txt")]
        sut.enterSpotlightSearchMode()
        sut.updateSpotlightSearchQuery("filtered")
        await waitForLoad()
        XCTAssertEqual(sut.directoryContents.displayedItems.count, 1)

        sut.exitSpotlightSearchMode()
        await waitForLoad()

        XCTAssertEqual(sut.directoryContents.displayedItems.count, sampleItems.count)
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

    func testSetMarkedRangeMarksInclusiveRange() async {
        let sut = makeSUT()
        await waitForLoad()

        sut.setMarkedRange(anchorIndex: 3, currentIndex: 1)

        XCTAssertEqual(sut.paneState.markedIndices, IndexSet(integersIn: 1 ... 3))
    }

    func testSetMarkedRangeClampsToBounds() async {
        let sut = makeSUT()
        await waitForLoad()

        sut.setMarkedRange(anchorIndex: -10, currentIndex: 99)

        XCTAssertEqual(sut.paneState.markedIndices, IndexSet(integersIn: 0 ... 4))
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

    func testMarkedOrSelectedPathsReturnsMarkedWhenPresent() async {
        let sut = makeSUT()
        await waitForLoad()

        sut.moveCursorDown()
        sut.toggleMark()
        sut.moveCursorDown()
        sut.toggleMark()

        let paths = sut.markedOrSelectedPaths()
        let expected = sut.paneState.markedIndices.compactMap { index -> String? in
            guard sut.directoryContents.displayedItems.indices.contains(index) else {
                return nil
            }
            return sut.directoryContents.displayedItems[index].url.standardizedFileURL.path
        }
        XCTAssertEqual(paths, expected)
    }

    func testMarkedOrSelectedPathsReturnsSelectedWhenNoMarks() async {
        let sut = makeSUT()
        await waitForLoad()

        sut.moveCursorDown()

        let paths = sut.markedOrSelectedPaths()
        XCTAssertEqual(paths, ["/tmp/test/beta.txt"])
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

    func testSetFilterTextMovesCursorToFirstBrowsableDirectory() async {
        let items = [
            makeFileItem(name: "alpha-note.txt"),
            makeFileItem(name: "alpha-folder", isDirectory: true),
            makeFileItem(name: "alpha-zeta.txt"),
        ]
        let sut = makeSUT(items: items)
        await waitForLoad()

        sut.setSortDescriptor(.selection(ascending: true))
        sut.setFilterText("alpha")

        XCTAssertEqual(sut.paneState.cursorIndex, 1)
        XCTAssertEqual(sut.selectedItem?.name, "alpha-folder")
    }

    func testSetFilterTextWithoutDirectoryKeepsCursorAtTopItem() async {
        let items = [
            makeFileItem(name: "alpha-one.txt"),
            makeFileItem(name: "alpha-two.txt"),
        ]
        let sut = makeSUT(items: items)
        await waitForLoad()

        sut.setSortDescriptor(.selection(ascending: true))
        sut.moveCursorDown()
        XCTAssertEqual(sut.paneState.cursorIndex, 1)

        sut.setFilterText("alpha")

        XCTAssertEqual(sut.paneState.cursorIndex, 0)
        XCTAssertEqual(sut.selectedItem?.name, "alpha-one.txt")
    }

    func testSetCursorAllowsSelectingFilteredResult() async {
        let items = [
            makeFileItem(name: "alpha-one.txt"),
            makeFileItem(name: "alpha-two.txt"),
            makeFileItem(name: "beta.txt"),
        ]
        let sut = makeSUT(items: items)
        await waitForLoad()

        sut.setSortDescriptor(.selection(ascending: true))
        sut.setFilterText("alpha")
        XCTAssertEqual(sut.directoryContents.displayedItems.count, 2)
        XCTAssertEqual(sut.paneState.cursorIndex, 0)

        sut.setCursor(index: 1)

        XCTAssertEqual(sut.paneState.cursorIndex, 1)
        XCTAssertEqual(sut.selectedItem?.name, "alpha-two.txt")
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

    func testSetFilesRecursiveEnabledInBrowserReloadsRecursively() async {
        let sut = makeSUT(items: [makeFileItem(name: "top.txt")])
        await waitForLoad()

        fileSystem.recursiveContentsOfDirectoryResult = .success([
            makeFileItem(name: "child.txt"),
            makeFileItem(name: "nested", isDirectory: true)
        ])

        sut.setFilesRecursiveEnabled(true)
        await waitForLoad()

        XCTAssertTrue(sut.filesRecursiveEnabled)
        XCTAssertEqual(fileSystem.recursiveContentsOfDirectoryCallCount, 1)
        XCTAssertEqual(sut.directoryContents.displayedItems.count, 2)
    }

    func testSetFilesRecursiveEnabledKeepsExistingFilterText() async {
        let sut = makeSUT(items: [makeFileItem(name: "top.txt")])
        await waitForLoad()

        sut.setFilterText("child")
        XCTAssertEqual(sut.directoryContents.filterText, "child")

        fileSystem.recursiveContentsOfDirectoryResult = .success([
            makeFileItem(name: "child.txt"),
            makeFileItem(name: "nested.txt")
        ])

        sut.setFilesRecursiveEnabled(true)
        await waitForLoad()

        XCTAssertEqual(sut.directoryContents.filterText, "child")
        XCTAssertEqual(sut.directoryContents.displayedItems.map(\.name), ["child.txt"])
    }

    func testToggleHiddenFilesReloadsWhenFilesRecursiveEnabled() async {
        let sut = makeSUT()
        await waitForLoad()

        sut.setFilesRecursiveEnabled(true)
        await waitForLoad()
        let beforeToggleCallCount = fileSystem.recursiveContentsOfDirectoryCallCount

        sut.toggleHiddenFiles()
        await waitForLoad()

        XCTAssertEqual(fileSystem.recursiveContentsOfDirectoryCallCount, beforeToggleCallCount + 1)
        XCTAssertEqual(fileSystem.recursiveContentsOfDirectoryCapturedArgs.last?.includeHiddenFiles, true)
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

    // MARK: - Loading Callback

    func testOnLoadingStateChangedFiresWhenNavigatingAndCompleting() async {
        let destination = URL(fileURLWithPath: "/tmp/other")
        let expectedItems = sampleItems
        fileSystem.contentsOfDirectoryHandler = { url in
            if url.standardizedFileURL == destination.standardizedFileURL {
                try await Task.sleep(for: .milliseconds(150))
            }
            return expectedItems
        }

        let sut = makeSUT()
        await waitForLoad()

        var capturedStates: [FilePaneViewModel.LoadingContext?] = []
        sut.onLoadingStateChanged = { context in
            capturedStates.append(context)
        }

        sut.navigate(to: destination)

        await waitForCondition(timeout: 2.0, description: "Loading state transitions for navigation") {
            capturedStates.contains(where: { $0 != nil }) &&
                capturedStates.last.flatMap({ $0 }) == nil
        }

        guard let startState = capturedStates.compactMap(\.self).first else {
            XCTFail("Expected loading start state")
            return
        }

        XCTAssertEqual(startState.directory, destination.standardizedFileURL)
        XCTAssertEqual(startState.mode, .browser)
        XCTAssertFalse(startState.isRecursive)
        XCTAssertEqual(startState.statusText, "Loading files...")
    }

    func testOnLoadingStateChangedReportsMediaRecursiveContext() async {
        fileSystem.mediaItemsHandler = { [weak self] _, recursive, _ in
            guard let self else {
                return []
            }
            if recursive {
                try await Task.sleep(for: .milliseconds(150))
            }
            return [self.makeFileItem(name: recursive ? "recursive.jpg" : "single.jpg")]
        }

        let sut = makeSUT()
        await waitForLoad()

        sut.setDisplayMode(.media)
        await waitForCondition(timeout: 2.0, description: "Media mode base load") {
            sut.displayMode == .media && self.fileSystem.mediaItemsCallCount >= 1
        }

        var capturedStates: [FilePaneViewModel.LoadingContext?] = []
        sut.onLoadingStateChanged = { context in
            capturedStates.append(context)
        }

        sut.setMediaRecursiveEnabled(true)

        await waitForCondition(timeout: 2.0, description: "Loading state transitions for media recursive") {
            capturedStates.contains(where: { $0 != nil }) &&
                capturedStates.last.flatMap({ $0 }) == nil
        }

        guard let startState = capturedStates.compactMap(\.self).first else {
            XCTFail("Expected loading start state")
            return
        }

        XCTAssertEqual(startState.mode, .media)
        XCTAssertTrue(startState.isRecursive)
        XCTAssertEqual(startState.statusText, "Loading media recursively...")
    }

    // MARK: - Cancel Loading

    func testCancelLoadingReturnsFalseAfterLoadCompletes() async {
        let sut = makeSUT()
        await waitForCondition(timeout: 2.0, description: "Initial load completes") {
            sut.directoryContents.displayedItems.count == self.sampleItems.count
        }

        _ = sut.cancelLoading()
        XCTAssertFalse(sut.cancelLoading())
    }

    func testCancelLoadingStopsInFlightNavigationAndClearsLoadingState() async {
        let destination = URL(fileURLWithPath: "/tmp/slow-destination")
        fileSystem.contentsOfDirectoryHandler = { [weak self] url in
            guard let self else {
                return []
            }

            if url.standardizedFileURL == destination.standardizedFileURL {
                try await Task.sleep(for: .seconds(2))
                return [self.makeFileItem(name: "finished.txt")]
            }
            return self.sampleItems
        }

        let sut = makeSUT()
        await waitForLoad()

        var capturedStates: [FilePaneViewModel.LoadingContext?] = []
        sut.onLoadingStateChanged = { context in
            capturedStates.append(context)
        }

        sut.navigate(to: destination)

        await waitForCondition(timeout: 2.0, description: "Loading state starts") {
            capturedStates.contains(where: { $0 != nil })
        }

        XCTAssertTrue(sut.cancelLoading())

        await waitForCondition(timeout: 2.0, description: "Loading state clears after cancellation") {
            capturedStates.last.flatMap({ $0 }) == nil
        }

        XCTAssertEqual(sut.paneState.currentDirectory, testDir.standardizedFileURL)
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

    func testRefreshFailureTriggersDirectoryLoadFailedCallback() async {
        let sut = makeSUT()
        await waitForLoad()

        var capturedDirectory: URL?
        var capturedError: Error?
        sut.onDirectoryLoadFailed = { directory, error in
            capturedDirectory = directory
            capturedError = error
        }

        fileSystem.contentsOfDirectoryResult = .failure(TestError.refreshFailure)
        monitor.simulateChange()
        await waitForLoad()

        XCTAssertEqual(capturedDirectory, testDir.standardizedFileURL)
        XCTAssertTrue(capturedError is TestError)
    }

    func testDirectoryMonitorRefreshDoesNotCancelInFlightNavigation() async {
        let destination = URL(fileURLWithPath: "/tmp/test/untitled folder 2")
        let initialItems = sampleItems
        fileSystem.contentsOfDirectoryHandler = { url in
            if url.standardizedFileURL == destination.standardizedFileURL {
                try await Task.sleep(for: .milliseconds(250))
                return [FileItem(
                    url: destination.appendingPathComponent("inside.txt"),
                    name: "inside.txt",
                    isDirectory: false,
                    size: 1,
                    dateModified: Date(),
                    isHidden: false,
                    isSymlink: false,
                    isPackage: false
                )]
            }
            return initialItems
        }

        let sut = makeSUT()
        await waitForLoad()

        sut.navigate(to: destination)
        monitor.simulateChange()
        await waitForCondition(timeout: 2.0, description: "Navigation to destination completes") {
            sut.paneState.currentDirectory == destination.standardizedFileURL
        }

        XCTAssertEqual(sut.paneState.currentDirectory, destination.standardizedFileURL)
    }

    func testDirectoryMonitorRefreshDoesNotEmitLoadingStateCallback() async {
        let sut = makeSUT()
        await waitForLoad()

        var capturedStates: [FilePaneViewModel.LoadingContext?] = []
        sut.onLoadingStateChanged = { context in
            capturedStates.append(context)
        }

        let previousCallCount = fileSystem.contentsOfDirectoryCallCount
        monitor.simulateChange()
        await waitForCondition(timeout: 2.0, description: "Directory monitor refresh completes") {
            self.fileSystem.contentsOfDirectoryCallCount > previousCallCount
        }

        XCTAssertTrue(capturedStates.isEmpty)
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
