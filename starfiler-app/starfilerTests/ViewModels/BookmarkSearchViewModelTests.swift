import XCTest
@testable import Starfiler

@MainActor
final class BookmarkSearchViewModelTests: XCTestCase {

    // MARK: - Helpers

    private func makeConfig(
        entries: [BookmarkEntry] = [],
        groupName: String = "Default",
        shortcutKey: String? = nil,
        isDefault: Bool = true
    ) -> BookmarksConfig {
        let group = BookmarkGroup(
            name: groupName,
            entries: entries,
            shortcutKey: shortcutKey,
            isDefault: isDefault
        )
        return BookmarksConfig(groups: [group])
    }

    private func makeSUT() -> BookmarkSearchViewModel {
        BookmarkSearchViewModel()
    }

    // MARK: - load

    func testLoadPopulatesResultsFromBookmarks() {
        let sut = makeSUT()
        let config = makeConfig(entries: [
            BookmarkEntry(displayName: "Home", path: "/Users/test", shortcutKey: "h"),
            BookmarkEntry(displayName: "Documents", path: "/Users/test/Documents", shortcutKey: "d"),
        ])

        sut.load(from: config, history: [])

        XCTAssertEqual(sut.results.count, 2)
        XCTAssertEqual(sut.results[0].displayName, "Home")
        XCTAssertEqual(sut.results[1].displayName, "Documents")
    }

    func testLoadSetsShortcutHintForDefaultGroup() {
        let sut = makeSUT()
        let config = makeConfig(entries: [
            BookmarkEntry(displayName: "Home", path: "/Users/test", shortcutKey: "h"),
        ])

        sut.load(from: config, history: [])

        XCTAssertEqual(sut.results[0].shortcutHint, "' h")
    }

    func testLoadSetsShortcutHintForNestedSequenceInNonDefaultGroup() {
        let sut = makeSUT()
        let config = BookmarksConfig(groups: [
            BookmarkGroup(
                name: "RWD",
                entries: [
                    BookmarkEntry(displayName: "docs", path: "/Users/workspace/RWD/rwd/docs", shortcutKey: "d"),
                    BookmarkEntry(displayName: "unity", path: "/Users/workspace/RWD/rwd/docs/unity", shortcutKey: "d u"),
                ],
                shortcutKey: "r",
                isDefault: false
            )
        ])

        sut.load(from: config, history: [])

        XCTAssertEqual(sut.results[0].shortcutHint, "' r d")
        XCTAssertEqual(sut.results[1].shortcutHint, "' r d u")
    }

    func testLoadAddsHistoryEntriesNotInBookmarks() {
        let sut = makeSUT()
        let config = makeConfig(entries: [
            BookmarkEntry(displayName: "Home", path: "/Users/test"),
        ])
        let history = [
            VisitHistoryEntry(path: "/tmp/recent", displayName: "recent"),
        ]

        sut.load(from: config, history: history)

        XCTAssertEqual(sut.results.count, 2)
        XCTAssertEqual(sut.results[1].groupName, "Recent")
        XCTAssertEqual(sut.results[1].path, "/tmp/recent")
    }

    func testLoadDoesNotDuplicateHistoryEntryThatMatchesBookmark() {
        let sut = makeSUT()
        let config = makeConfig(entries: [
            BookmarkEntry(displayName: "Home", path: "/Users/test"),
        ])
        let history = [
            VisitHistoryEntry(path: "/Users/test", displayName: "Home"),
        ]

        sut.load(from: config, history: history)

        XCTAssertEqual(sut.results.count, 1)
    }

    func testLoadResetsSelectedIndex() {
        let sut = makeSUT()
        let config = makeConfig(entries: [
            BookmarkEntry(displayName: "A", path: "/a"),
            BookmarkEntry(displayName: "B", path: "/b"),
        ])

        sut.load(from: config, history: [])
        // Move selection down, then reload - should reset to 0
        sut.moveSelectionDown()
        XCTAssertEqual(sut.selectedIndex, 1)

        sut.load(from: config, history: [])
        XCTAssertEqual(sut.selectedIndex, 0)
    }

    // MARK: - updateQuery

    func testEmptyQueryShowsAllItems() {
        let sut = makeSUT()
        let config = makeConfig(entries: [
            BookmarkEntry(displayName: "Home", path: "/Users/test"),
            BookmarkEntry(displayName: "Documents", path: "/Users/test/Documents"),
        ])
        sut.load(from: config, history: [])

        sut.updateQuery("")

        XCTAssertEqual(sut.results.count, 2)
    }

    func testQueryFiltersResultsByName() {
        let sut = makeSUT()
        let config = makeConfig(entries: [
            BookmarkEntry(displayName: "Home", path: "/Users/test"),
            BookmarkEntry(displayName: "Documents", path: "/Users/test/Documents"),
            BookmarkEntry(displayName: "Downloads", path: "/Users/test/Downloads"),
        ])
        sut.load(from: config, history: [])

        sut.updateQuery("Doc")

        XCTAssertEqual(sut.results.count, 1)
        XCTAssertEqual(sut.results[0].displayName, "Documents")
    }

    func testQueryPrefixMatchesAppearBeforeSubstringMatches() {
        let sut = makeSUT()
        let config = makeConfig(entries: [
            BookmarkEntry(displayName: "My Downloads", path: "/my-downloads"),
            BookmarkEntry(displayName: "Downloads", path: "/downloads"),
        ])
        sut.load(from: config, history: [])

        sut.updateQuery("down")

        XCTAssertEqual(sut.results.count, 2)
        XCTAssertEqual(sut.results[0].displayName, "Downloads")
        XCTAssertEqual(sut.results[1].displayName, "My Downloads")
    }

    func testQueryResetsSelectedIndex() {
        let sut = makeSUT()
        let config = makeConfig(entries: [
            BookmarkEntry(displayName: "A", path: "/a"),
            BookmarkEntry(displayName: "B", path: "/b"),
        ])
        sut.load(from: config, history: [])
        sut.moveSelectionDown()

        sut.updateQuery("A")

        XCTAssertEqual(sut.selectedIndex, 0)
    }

    // MARK: - moveSelectionUp / moveSelectionDown

    func testMoveSelectionDownIncrementsIndex() {
        let sut = makeSUT()
        let config = makeConfig(entries: [
            BookmarkEntry(displayName: "A", path: "/a"),
            BookmarkEntry(displayName: "B", path: "/b"),
            BookmarkEntry(displayName: "C", path: "/c"),
        ])
        sut.load(from: config, history: [])

        sut.moveSelectionDown()
        XCTAssertEqual(sut.selectedIndex, 1)

        sut.moveSelectionDown()
        XCTAssertEqual(sut.selectedIndex, 2)
    }

    func testMoveSelectionDownClampsAtEnd() {
        let sut = makeSUT()
        let config = makeConfig(entries: [
            BookmarkEntry(displayName: "A", path: "/a"),
        ])
        sut.load(from: config, history: [])

        sut.moveSelectionDown()
        sut.moveSelectionDown()

        XCTAssertEqual(sut.selectedIndex, 0)
    }

    func testMoveSelectionUpClampsAtZero() {
        let sut = makeSUT()
        let config = makeConfig(entries: [
            BookmarkEntry(displayName: "A", path: "/a"),
        ])
        sut.load(from: config, history: [])

        sut.moveSelectionUp()

        XCTAssertEqual(sut.selectedIndex, 0)
    }

    // MARK: - selectedEntry

    func testSelectedEntryReturnsCorrectItem() {
        let sut = makeSUT()
        let config = makeConfig(entries: [
            BookmarkEntry(displayName: "A", path: "/a"),
            BookmarkEntry(displayName: "B", path: "/b"),
        ])
        sut.load(from: config, history: [])

        sut.moveSelectionDown()

        XCTAssertEqual(sut.selectedEntry?.displayName, "B")
        XCTAssertEqual(sut.selectedEntry?.path, "/b")
    }

    func testSelectedEntryReturnsNilWhenEmpty() {
        let sut = makeSUT()

        XCTAssertNil(sut.selectedEntry)
    }
}
