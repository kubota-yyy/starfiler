import XCTest
@testable import Starfiler

final class VimModeStateTests: XCTestCase {

    func testInitialNormalMode() {
        let state = VimModeState()
        XCTAssertEqual(state.mode, .normal)
        XCTAssertNil(state.visualAnchorIndex)
    }

    func testEnterVisualMode() {
        var state = VimModeState()
        state.enterVisualMode(anchorIndex: 5)
        XCTAssertEqual(state.mode, .visual)
        XCTAssertEqual(state.visualAnchorIndex, 5)
    }

    func testExitVisualMode() {
        var state = VimModeState()
        state.enterVisualMode(anchorIndex: 3)
        XCTAssertEqual(state.mode, .visual)

        state.exitVisualMode()
        XCTAssertEqual(state.mode, .normal)
        XCTAssertNil(state.visualAnchorIndex)
    }

    func testEnterFilterMode() {
        var state = VimModeState()
        state.enterFilterMode()
        XCTAssertEqual(state.mode, .filter)
        XCTAssertNil(state.visualAnchorIndex)
    }

    func testModeTransitions() {
        var state = VimModeState()

        // normal -> visual
        state.enterVisualMode(anchorIndex: 2)
        XCTAssertEqual(state.mode, .visual)
        XCTAssertEqual(state.visualAnchorIndex, 2)

        // visual -> normal
        state.enterNormalMode()
        XCTAssertEqual(state.mode, .normal)
        XCTAssertNil(state.visualAnchorIndex)

        // normal -> filter
        state.enterFilterMode()
        XCTAssertEqual(state.mode, .filter)
        XCTAssertNil(state.visualAnchorIndex)

        // filter -> normal
        state.enterNormalMode()
        XCTAssertEqual(state.mode, .normal)

        // normal -> visual -> filter
        state.enterVisualMode(anchorIndex: 10)
        XCTAssertEqual(state.visualAnchorIndex, 10)
        state.enterFilterMode()
        XCTAssertEqual(state.mode, .filter)
        XCTAssertNil(state.visualAnchorIndex)
    }

    func testInitWithCustomMode() {
        let state = VimModeState(mode: .visual, visualAnchorIndex: 7)
        XCTAssertEqual(state.mode, .visual)
        XCTAssertEqual(state.visualAnchorIndex, 7)
    }
}
