import XCTest
@testable import Starfiler

final class DirectoryContentsTests: XCTestCase {

    // MARK: - Helpers

    private func makeFileItem(
        name: String,
        isDirectory: Bool = false,
        size: Int64? = nil,
        dateModified: Date? = nil,
        isHidden: Bool = false,
        isSymlink: Bool = false,
        isPackage: Bool = false
    ) -> FileItem {
        let url: URL
        if name.hasPrefix("/") {
            url = URL(fileURLWithPath: name, isDirectory: isDirectory)
        } else {
            url = URL(fileURLWithPath: "/test/\(name)", isDirectory: isDirectory)
        }
        return FileItem(
            url: url,
            name: name,
            isDirectory: isDirectory,
            size: size,
            dateModified: dateModified,
            isHidden: isHidden,
            isSymlink: isSymlink,
            isPackage: isPackage
        )
    }

    private let epoch = Date(timeIntervalSince1970: 0)

    // MARK: - Empty

    func testEmptyDirectory() {
        let contents = DirectoryContents(allItems: [])
        XCTAssertTrue(contents.displayedItems.isEmpty)
    }

    // MARK: - Sort by Name

    func testSortByNameAscending() {
        let items = [
            makeFileItem(name: "banana"),
            makeFileItem(name: "apple"),
            makeFileItem(name: "cherry"),
        ]
        let contents = DirectoryContents(
            allItems: items,
            sortDescriptor: .name(ascending: true)
        )
        XCTAssertEqual(contents.displayedItems.map(\.name), ["apple", "banana", "cherry"])
    }

    func testSortByNameDescending() {
        let items = [
            makeFileItem(name: "banana"),
            makeFileItem(name: "apple"),
            makeFileItem(name: "cherry"),
        ]
        let contents = DirectoryContents(
            allItems: items,
            sortDescriptor: .name(ascending: false)
        )
        XCTAssertEqual(contents.displayedItems.map(\.name), ["cherry", "banana", "apple"])
    }

    // MARK: - Sort by Size

    func testSortBySizeAscending() {
        let items = [
            makeFileItem(name: "big", size: 1000),
            makeFileItem(name: "small", size: 10),
            makeFileItem(name: "medium", size: 500),
        ]
        let contents = DirectoryContents(
            allItems: items,
            sortDescriptor: .size(ascending: true)
        )
        XCTAssertEqual(contents.displayedItems.map(\.name), ["small", "medium", "big"])
    }

    func testSortBySizeDescending() {
        let items = [
            makeFileItem(name: "big", size: 1000),
            makeFileItem(name: "small", size: 10),
            makeFileItem(name: "medium", size: 500),
        ]
        let contents = DirectoryContents(
            allItems: items,
            sortDescriptor: .size(ascending: false)
        )
        XCTAssertEqual(contents.displayedItems.map(\.name), ["big", "medium", "small"])
    }

    func testSortBySizeFallsBackToNameOnEqual() {
        let items = [
            makeFileItem(name: "beta", size: 100),
            makeFileItem(name: "alpha", size: 100),
        ]
        let contents = DirectoryContents(
            allItems: items,
            sortDescriptor: .size(ascending: true)
        )
        XCTAssertEqual(contents.displayedItems.map(\.name), ["alpha", "beta"])
    }

    // MARK: - Sort by Date

    func testSortByDateAscending() {
        let items = [
            makeFileItem(name: "new", dateModified: epoch.addingTimeInterval(100)),
            makeFileItem(name: "old", dateModified: epoch.addingTimeInterval(1)),
            makeFileItem(name: "mid", dateModified: epoch.addingTimeInterval(50)),
        ]
        let contents = DirectoryContents(
            allItems: items,
            sortDescriptor: .date(ascending: true)
        )
        XCTAssertEqual(contents.displayedItems.map(\.name), ["old", "mid", "new"])
    }

    func testSortByDateDescending() {
        let items = [
            makeFileItem(name: "new", dateModified: epoch.addingTimeInterval(100)),
            makeFileItem(name: "old", dateModified: epoch.addingTimeInterval(1)),
            makeFileItem(name: "mid", dateModified: epoch.addingTimeInterval(50)),
        ]
        let contents = DirectoryContents(
            allItems: items,
            sortDescriptor: .date(ascending: false)
        )
        XCTAssertEqual(contents.displayedItems.map(\.name), ["new", "mid", "old"])
    }

    func testSortByDateFallsBackToNameOnEqual() {
        let items = [
            makeFileItem(name: "beta", dateModified: epoch),
            makeFileItem(name: "alpha", dateModified: epoch),
        ]
        let contents = DirectoryContents(
            allItems: items,
            sortDescriptor: .date(ascending: true)
        )
        XCTAssertEqual(contents.displayedItems.map(\.name), ["alpha", "beta"])
    }

    // MARK: - Directories First

    func testDirectoriesSortedBeforeFiles() {
        let items = [
            makeFileItem(name: "file_a.txt"),
            makeFileItem(name: "dir_b", isDirectory: true),
            makeFileItem(name: "file_c.txt"),
            makeFileItem(name: "dir_a", isDirectory: true),
        ]
        let contents = DirectoryContents(
            allItems: items,
            sortDescriptor: .name(ascending: true)
        )
        let names = contents.displayedItems.map(\.name)
        XCTAssertEqual(names[0], "dir_a")
        XCTAssertEqual(names[1], "dir_b")
        XCTAssertEqual(names[2], "file_a.txt")
        XCTAssertEqual(names[3], "file_c.txt")
    }

    func testPackageDirectoryTreatedAsFile() {
        let items = [
            makeFileItem(name: "file_a.txt"),
            makeFileItem(name: "Package.app", isDirectory: true, isPackage: true),
            makeFileItem(name: "dir_z", isDirectory: true),
        ]
        let contents = DirectoryContents(
            allItems: items,
            sortDescriptor: .name(ascending: true)
        )
        let names = contents.displayedItems.map(\.name)
        // dir_z should be first (browsable directory), then files+packages sorted together
        XCTAssertEqual(names[0], "dir_z")
        XCTAssertTrue(names[1...].contains("file_a.txt"))
        XCTAssertTrue(names[1...].contains("Package.app"))
    }

    // MARK: - Filter by Text

    func testFilterByTextCaseInsensitive() {
        let items = [
            makeFileItem(name: "README.md"),
            makeFileItem(name: "readme.txt"),
            makeFileItem(name: "other.swift"),
        ]
        let contents = DirectoryContents(
            allItems: items,
            sortDescriptor: .name(ascending: true),
            filterText: "readme"
        )
        XCTAssertEqual(contents.displayedItems.count, 2)
        let names = Set(contents.displayedItems.map(\.name))
        XCTAssertTrue(names.contains("README.md"))
        XCTAssertTrue(names.contains("readme.txt"))
    }

    func testFilterByTextEmptyShowsAll() {
        let items = [
            makeFileItem(name: "file_a"),
            makeFileItem(name: "file_b"),
        ]
        let contents = DirectoryContents(
            allItems: items,
            sortDescriptor: .name(ascending: true),
            filterText: ""
        )
        XCTAssertEqual(contents.displayedItems.count, 2)
    }

    func testFilterByTextWhitespaceOnlyShowsAll() {
        let items = [
            makeFileItem(name: "file_a"),
            makeFileItem(name: "file_b"),
        ]
        let contents = DirectoryContents(
            allItems: items,
            sortDescriptor: .name(ascending: true),
            filterText: "   "
        )
        XCTAssertEqual(contents.displayedItems.count, 2)
    }

    func testFilterByTextNoMatch() {
        let items = [
            makeFileItem(name: "file_a"),
            makeFileItem(name: "file_b"),
        ]
        let contents = DirectoryContents(
            allItems: items,
            sortDescriptor: .name(ascending: true),
            filterText: "xyz"
        )
        XCTAssertTrue(contents.displayedItems.isEmpty)
    }

    // MARK: - Show Hidden Files

    func testHiddenFilesHiddenByDefault() {
        let items = [
            makeFileItem(name: "visible"),
            makeFileItem(name: ".hidden", isHidden: true),
        ]
        let contents = DirectoryContents(
            allItems: items,
            sortDescriptor: .name(ascending: true),
            showHiddenFiles: false
        )
        XCTAssertEqual(contents.displayedItems.count, 1)
        XCTAssertEqual(contents.displayedItems[0].name, "visible")
    }

    func testShowHiddenFilesTrue() {
        let items = [
            makeFileItem(name: "visible"),
            makeFileItem(name: ".hidden", isHidden: true),
        ]
        let contents = DirectoryContents(
            allItems: items,
            sortDescriptor: .name(ascending: true),
            showHiddenFiles: true
        )
        XCTAssertEqual(contents.displayedItems.count, 2)
    }

    // MARK: - Content Filter

    func testContentFilterAllFilesShowsEverything() {
        let items = [
            makeFileItem(name: "dir", isDirectory: true),
            makeFileItem(name: "file.txt"),
            makeFileItem(name: "photo.jpg"),
        ]
        let contents = DirectoryContents(
            allItems: items,
            sortDescriptor: .name(ascending: true),
            contentFilter: .allFiles
        )
        XCTAssertEqual(contents.displayedItems.count, 3)
    }

    func testContentFilterMediaOnlyFiltersNonMedia() {
        let items = [
            makeFileItem(name: "dir", isDirectory: true),
            makeFileItem(name: "file.txt"),
            makeFileItem(name: "photo.jpg"),
        ]
        let contents = DirectoryContents(
            allItems: items,
            sortDescriptor: .name(ascending: true),
            contentFilter: .mediaOnly
        )
        // mediaOnly filters to items where !isDirectory && url.isMediaFile
        // Only "photo.jpg" should match
        XCTAssertEqual(contents.displayedItems.count, 1)
        XCTAssertEqual(contents.displayedItems[0].name, "photo.jpg")
    }

    // MARK: - Recompute

    func testRecompute() {
        var contents = DirectoryContents(
            allItems: [
                makeFileItem(name: "banana"),
                makeFileItem(name: "apple"),
            ],
            sortDescriptor: .name(ascending: true)
        )
        XCTAssertEqual(contents.displayedItems.map(\.name), ["apple", "banana"])

        // Add a new item
        contents.allItems.append(makeFileItem(name: "cherry"))
        contents.recompute()
        XCTAssertEqual(contents.displayedItems.map(\.name), ["apple", "banana", "cherry"])
    }

    // MARK: - setSortDescriptor

    func testSetSortDescriptor() {
        var contents = DirectoryContents(
            allItems: [
                makeFileItem(name: "big", size: 1000),
                makeFileItem(name: "small", size: 10),
            ],
            sortDescriptor: .name(ascending: true)
        )
        XCTAssertEqual(contents.displayedItems.map(\.name), ["big", "small"])

        contents.setSortDescriptor(.size(ascending: true))
        XCTAssertEqual(contents.displayedItems.map(\.name), ["small", "big"])
    }

    // MARK: - SortDescriptor

    func testSortDescriptorColumnAndAscending() {
        let desc = DirectoryContents.SortDescriptor.name(ascending: true)
        XCTAssertEqual(desc.column, .name)
        XCTAssertTrue(desc.ascending)

        let desc2 = DirectoryContents.SortDescriptor.size(ascending: false)
        XCTAssertEqual(desc2.column, .size)
        XCTAssertFalse(desc2.ascending)

        let desc3 = DirectoryContents.SortDescriptor(column: .date, ascending: true)
        XCTAssertEqual(desc3.column, .date)
        XCTAssertTrue(desc3.ascending)
    }

    func testSortDescriptorSelectionKeepsOrder() {
        let items = [
            makeFileItem(name: "banana"),
            makeFileItem(name: "apple"),
            makeFileItem(name: "cherry"),
        ]
        let contents = DirectoryContents(
            allItems: items,
            sortDescriptor: .selection(ascending: true)
        )
        // selection ascending preserves order
        XCTAssertEqual(contents.displayedItems.map(\.name), ["banana", "apple", "cherry"])
    }

    func testSortDescriptorSelectionDescendingReversesOrder() {
        let items = [
            makeFileItem(name: "banana"),
            makeFileItem(name: "apple"),
            makeFileItem(name: "cherry"),
        ]
        let contents = DirectoryContents(
            allItems: items,
            sortDescriptor: .selection(ascending: false)
        )
        XCTAssertEqual(contents.displayedItems.map(\.name), ["cherry", "apple", "banana"])
    }

    // MARK: - Mixed Files and Directories

    func testMixedFilesAndDirectories() {
        let items = [
            makeFileItem(name: "z_file.txt", size: 100, dateModified: epoch),
            makeFileItem(name: "a_dir", isDirectory: true),
            makeFileItem(name: ".hidden_file", isHidden: true, isSymlink: true),
            makeFileItem(name: "b_dir", isDirectory: true),
            makeFileItem(name: "m_file.swift", size: 200, dateModified: epoch.addingTimeInterval(10)),
        ]
        let contents = DirectoryContents(
            allItems: items,
            sortDescriptor: .name(ascending: true),
            showHiddenFiles: false
        )
        // Hidden file excluded, directories first
        let names = contents.displayedItems.map(\.name)
        XCTAssertEqual(names, ["a_dir", "b_dir", "m_file.swift", "z_file.txt"])
    }
}
