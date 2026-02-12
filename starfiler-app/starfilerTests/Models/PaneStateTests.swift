import XCTest
@testable import Starfiler

final class PaneStateTests: XCTestCase {

    // MARK: - Helpers

    private let homeURL = URL(fileURLWithPath: "/Users/test")

    // MARK: - Tests

    func testInitDefaultValues() {
        let state = PaneState(currentDirectory: homeURL)
        XCTAssertEqual(state.currentDirectory, homeURL)
        XCTAssertEqual(state.cursorIndex, 0)
        XCTAssertTrue(state.markedIndices.isEmpty)
        XCTAssertNil(state.visualAnchorIndex)
    }

    func testInitWithCustomValues() {
        let state = PaneState(
            currentDirectory: homeURL,
            cursorIndex: 5,
            markedIndices: IndexSet([1, 3, 5]),
            visualAnchorIndex: 2
        )
        XCTAssertEqual(state.cursorIndex, 5)
        XCTAssertEqual(state.markedIndices, IndexSet([1, 3, 5]))
        XCTAssertEqual(state.visualAnchorIndex, 2)
    }

    func testCursorIndexChanges() {
        var state = PaneState(currentDirectory: homeURL)
        state.cursorIndex = 10
        XCTAssertEqual(state.cursorIndex, 10)
        state.cursorIndex = 0
        XCTAssertEqual(state.cursorIndex, 0)
    }

    func testMarkedIndicesOperations() {
        var state = PaneState(currentDirectory: homeURL)
        state.markedIndices.insert(3)
        state.markedIndices.insert(7)
        XCTAssertEqual(state.markedIndices.count, 2)
        XCTAssertTrue(state.markedIndices.contains(3))
        XCTAssertTrue(state.markedIndices.contains(7))

        state.markedIndices.remove(3)
        XCTAssertEqual(state.markedIndices.count, 1)
        XCTAssertFalse(state.markedIndices.contains(3))
        XCTAssertTrue(state.markedIndices.contains(7))
    }

    func testVisualAnchorIndex() {
        var state = PaneState(currentDirectory: homeURL)
        XCTAssertNil(state.visualAnchorIndex)
        state.visualAnchorIndex = 5
        XCTAssertEqual(state.visualAnchorIndex, 5)
        state.visualAnchorIndex = nil
        XCTAssertNil(state.visualAnchorIndex)
    }

    func testHashableConformance() {
        let state1 = PaneState(currentDirectory: homeURL, cursorIndex: 0)
        let state2 = PaneState(currentDirectory: homeURL, cursorIndex: 0)
        XCTAssertEqual(state1, state2)
        XCTAssertEqual(state1.hashValue, state2.hashValue)

        let state3 = PaneState(currentDirectory: homeURL, cursorIndex: 5)
        XCTAssertNotEqual(state1, state3)
    }
}
