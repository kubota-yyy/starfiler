import XCTest
@testable import Starfiler

final class NavigationHistoryTests: XCTestCase {

    // MARK: - Helpers

    private let urlA = URL(fileURLWithPath: "/a")
    private let urlB = URL(fileURLWithPath: "/b")
    private let urlC = URL(fileURLWithPath: "/c")
    private let urlD = URL(fileURLWithPath: "/d")

    // MARK: - Tests

    func testInitiallyEmpty() {
        let history = NavigationHistory()
        XCTAssertTrue(history.backStack.isEmpty)
        XCTAssertTrue(history.forwardStack.isEmpty)
    }

    func testPush() {
        var history = NavigationHistory()
        history.push(urlA)
        XCTAssertEqual(history.backStack, [urlA])
        XCTAssertTrue(history.forwardStack.isEmpty)
    }

    func testPushDoesNotDuplicateConsecutive() {
        var history = NavigationHistory()
        history.push(urlA)
        history.push(urlA)
        XCTAssertEqual(history.backStack, [urlA])
    }

    func testGoBack() {
        var history = NavigationHistory()
        history.push(urlA)
        let destination = history.goBack(from: urlB)
        XCTAssertEqual(destination, urlA)
        XCTAssertTrue(history.backStack.isEmpty)
        XCTAssertEqual(history.forwardStack, [urlB])
    }

    func testGoForward() {
        var history = NavigationHistory()
        history.push(urlA)
        _ = history.goBack(from: urlB)
        let destination = history.goForward(from: urlA)
        XCTAssertEqual(destination, urlB)
        XCTAssertEqual(history.backStack, [urlA])
        XCTAssertTrue(history.forwardStack.isEmpty)
    }

    func testGoBackFromEmpty() {
        var history = NavigationHistory()
        let destination = history.goBack(from: urlA)
        XCTAssertNil(destination)
    }

    func testGoForwardFromEmpty() {
        var history = NavigationHistory()
        let destination = history.goForward(from: urlA)
        XCTAssertNil(destination)
    }

    func testPushClearsForwardStack() {
        var history = NavigationHistory()
        history.push(urlA)
        history.push(urlB)
        _ = history.goBack(from: urlC)
        XCTAssertFalse(history.forwardStack.isEmpty)

        history.push(urlD)
        XCTAssertTrue(history.forwardStack.isEmpty)
    }

    func testMultipleNavigations() {
        var history = NavigationHistory()
        // Push A, then B, then C
        history.push(urlA)
        history.push(urlB)
        history.push(urlC)
        XCTAssertEqual(history.backStack, [urlA, urlB, urlC])

        // Go back from D -> C
        let first = history.goBack(from: urlD)
        XCTAssertEqual(first, urlC)
        XCTAssertEqual(history.forwardStack, [urlD])

        // Go back from C -> B
        let second = history.goBack(from: urlC)
        XCTAssertEqual(second, urlB)
        XCTAssertEqual(history.forwardStack, [urlD, urlC])

        // Go forward from B -> C
        let third = history.goForward(from: urlB)
        XCTAssertEqual(third, urlC)
        XCTAssertEqual(history.backStack, [urlA, urlB])
        XCTAssertEqual(history.forwardStack, [urlD])
    }

    func testTimeline() {
        var history = NavigationHistory()
        history.push(urlA)
        history.push(urlB)

        // Current is urlC, backStack = [A, B], forwardStack = []
        let timeline = history.timeline(current: urlC)
        XCTAssertEqual(timeline.count, 3)
        XCTAssertEqual(timeline[0].url, urlA)
        XCTAssertFalse(timeline[0].isCurrentPosition)
        XCTAssertEqual(timeline[0].timelineIndex, 0)
        XCTAssertEqual(timeline[1].url, urlB)
        XCTAssertFalse(timeline[1].isCurrentPosition)
        XCTAssertEqual(timeline[1].timelineIndex, 1)
        XCTAssertEqual(timeline[2].url, urlC)
        XCTAssertTrue(timeline[2].isCurrentPosition)
        XCTAssertEqual(timeline[2].timelineIndex, 2)
    }

    func testTimelineWithForwardStack() {
        var history = NavigationHistory()
        history.push(urlA)
        history.push(urlB)
        // Go back from C -> B
        _ = history.goBack(from: urlC)
        // backStack = [A], forwardStack = [C], current = B
        let timeline = history.timeline(current: urlB)
        XCTAssertEqual(timeline.count, 3)
        XCTAssertEqual(timeline[0].url, urlA)
        XCTAssertEqual(timeline[1].url, urlB)
        XCTAssertTrue(timeline[1].isCurrentPosition)
        XCTAssertEqual(timeline[2].url, urlC)
        XCTAssertFalse(timeline[2].isCurrentPosition)
    }

    func testJumpToTimelinePosition() {
        var history = NavigationHistory()
        history.push(urlA)
        history.push(urlB)
        // backStack = [A, B], forwardStack = [], current = C
        // timeline = [A(0), B(1), C(2)]

        let destination = history.jumpToTimelinePosition(0, from: urlC)
        XCTAssertEqual(destination, urlA)
        XCTAssertTrue(history.backStack.isEmpty)
        // forwardStack should be [C, B] (reversed from [B, C])
        XCTAssertEqual(history.forwardStack, [urlC, urlB])
    }

    func testJumpToTimelinePositionCurrentReturnsNil() {
        var history = NavigationHistory()
        history.push(urlA)
        // backStack = [A], current = B, timeline = [A(0), B(1)]
        let destination = history.jumpToTimelinePosition(1, from: urlB)
        XCTAssertNil(destination)
    }

    func testJumpToTimelinePositionOutOfBounds() {
        var history = NavigationHistory()
        history.push(urlA)
        let destination = history.jumpToTimelinePosition(5, from: urlB)
        XCTAssertNil(destination)
    }

    func testPushTrimsBackStackToEntryLimit() {
        var history = NavigationHistory()
        for index in 0..<(NavigationHistory.entryLimit + 5) {
            history.push(URL(fileURLWithPath: "/\(index)"))
        }

        XCTAssertEqual(history.backStack.count, NavigationHistory.entryLimit)
        XCTAssertEqual(history.backStack.first?.path, "/5")
        XCTAssertEqual(history.backStack.last?.path, "/\(NavigationHistory.entryLimit + 4)")
    }

    func testInitTrimsStacksToEntryLimit() {
        let backStack = (0..<(NavigationHistory.entryLimit + 3)).map { URL(fileURLWithPath: "/b\($0)") }
        let forwardStack = (0..<(NavigationHistory.entryLimit + 2)).map { URL(fileURLWithPath: "/f\($0)") }
        let history = NavigationHistory(backStack: backStack, forwardStack: forwardStack)

        XCTAssertEqual(history.backStack.count, NavigationHistory.entryLimit)
        XCTAssertEqual(history.forwardStack.count, NavigationHistory.entryLimit)
        XCTAssertEqual(history.backStack.first?.path, "/b3")
        XCTAssertEqual(history.forwardStack.first?.path, "/f2")
    }
}
