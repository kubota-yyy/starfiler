import XCTest
@testable import Starfiler

@MainActor
final class TerminalSessionManagerViewModelTests: XCTestCase {

    private var mockService: MockTerminalSessionService!

    override func setUp() {
        super.setUp()
        mockService = MockTerminalSessionService()
    }

    private func makeSUT() -> TerminalSessionManagerViewModel {
        TerminalSessionManagerViewModel(service: mockService)
    }

    // MARK: - Initial State

    func testInitialState() {
        let sut = makeSUT()

        XCTAssertTrue(sut.sessions.isEmpty)
        XCTAssertTrue(sut.searchResults.isEmpty)
        XCTAssertEqual(sut.runningSessionCount, 0)
        XCTAssertEqual(sut.searchQuery, "")
        XCTAssertEqual(sut.providerFilter, .all)
        XCTAssertFalse(sut.isSearching)
    }

    // MARK: - Reload Sessions

    func testReloadSessionsPopulatesSessions() async {
        let sut = makeSUT()
        let dir = URL(fileURLWithPath: "/tmp")

        _ = await mockService.createSession(command: .claude, workingDirectory: dir)
        _ = await mockService.createSession(command: .codex, workingDirectory: dir)

        sut.reloadSessions()
        try? await Task.sleep(for: .milliseconds(200))

        XCTAssertEqual(sut.sessions.count, 2)
    }

    func testReloadSessionsCountsActiveSessions() async {
        let sut = makeSUT()
        let dir = URL(fileURLWithPath: "/tmp")

        let s1 = await mockService.createSession(command: .claude, workingDirectory: dir)
        let s2 = await mockService.createSession(command: .codex, workingDirectory: dir)

        // s1 stays launching (active), s2 goes to completed
        await mockService.updateStatus(id: s2.id, status: .completed)

        sut.reloadSessions()
        try? await Task.sleep(for: .milliseconds(200))

        XCTAssertEqual(sut.runningSessionCount, 1)
    }

    // MARK: - Provider Filter

    func testDisplayedSessionsFiltersByProvider() async {
        let sut = makeSUT()
        let dir = URL(fileURLWithPath: "/tmp")

        _ = await mockService.createSession(command: .claude, workingDirectory: dir)
        _ = await mockService.createSession(command: .codex, workingDirectory: dir)

        sut.reloadSessions()
        try? await Task.sleep(for: .milliseconds(200))

        sut.providerFilter = .claude
        let displayed = sut.displayedSessions()
        XCTAssertEqual(displayed.count, 1)
        XCTAssertEqual(displayed.first?.command, .claude)
    }

    func testDisplayedSessionsAllFilterShowsAll() async {
        let sut = makeSUT()
        let dir = URL(fileURLWithPath: "/tmp")

        _ = await mockService.createSession(command: .claude, workingDirectory: dir)
        _ = await mockService.createSession(command: .codex, workingDirectory: dir)

        sut.reloadSessions()
        try? await Task.sleep(for: .milliseconds(200))

        sut.providerFilter = .all
        let displayed = sut.displayedSessions()
        XCTAssertEqual(displayed.count, 2)
    }

    // MARK: - Pin / Unpin

    func testPinSession() async {
        let sut = makeSUT()
        let dir = URL(fileURLWithPath: "/tmp")

        let session = await mockService.createSession(command: .claude, workingDirectory: dir)

        sut.reloadSessions()
        try? await Task.sleep(for: .milliseconds(200))

        sut.pinSession(id: session.id)
        try? await Task.sleep(for: .milliseconds(200))

        let pinned = sut.sessions.first(where: { $0.id == session.id })
        XCTAssertTrue(pinned?.isPinned == true)
    }

    func testUnpinSession() async {
        let sut = makeSUT()
        let dir = URL(fileURLWithPath: "/tmp")

        let session = await mockService.createSession(command: .claude, workingDirectory: dir)
        await mockService.pin(id: session.id)

        sut.reloadSessions()
        try? await Task.sleep(for: .milliseconds(200))

        sut.unpinSession(id: session.id)
        try? await Task.sleep(for: .milliseconds(200))

        let unpinned = sut.sessions.first(where: { $0.id == session.id })
        XCTAssertFalse(unpinned?.isPinned == true)
    }

    // MARK: - Rename

    func testRenameSession() async {
        let sut = makeSUT()
        let dir = URL(fileURLWithPath: "/tmp")

        let session = await mockService.createSession(command: .claude, workingDirectory: dir)

        sut.reloadSessions()
        try? await Task.sleep(for: .milliseconds(200))

        sut.renameSession(id: session.id, title: "New Title")
        try? await Task.sleep(for: .milliseconds(200))

        let renamed = sut.sessions.first(where: { $0.id == session.id })
        XCTAssertEqual(renamed?.title, "New Title")
    }

    // MARK: - Remove

    func testRemoveSession() async {
        let sut = makeSUT()
        let dir = URL(fileURLWithPath: "/tmp")

        let session = await mockService.createSession(command: .claude, workingDirectory: dir)

        sut.reloadSessions()
        try? await Task.sleep(for: .milliseconds(200))
        XCTAssertEqual(sut.sessions.count, 1)

        sut.removeSession(id: session.id)
        try? await Task.sleep(for: .milliseconds(200))

        XCTAssertTrue(sut.sessions.isEmpty)
    }

    // MARK: - Open Session Callback

    func testOpenSessionInvokesCallback() async {
        let sut = makeSUT()
        let dir = URL(fileURLWithPath: "/tmp")

        let session = await mockService.createSession(command: .claude, workingDirectory: dir)

        var openedId: UUID?
        sut.onOpenSession = { id in openedId = id }

        sut.openSession(id: session.id)

        XCTAssertEqual(openedId, session.id)
    }

    // MARK: - Search

    func testIsSearchingReflectsQuery() {
        let sut = makeSUT()

        XCTAssertFalse(sut.isSearching)

        sut.searchQuery = "test"
        XCTAssertTrue(sut.isSearching)

        sut.searchQuery = ""
        XCTAssertFalse(sut.isSearching)
    }

    func testSearchPopulatesResults() async {
        let sut = makeSUT()
        let dir = URL(fileURLWithPath: "/tmp")

        let session = await mockService.createSession(command: .claude, workingDirectory: dir)
        await mockService.rename(id: session.id, title: "Searchable Session")

        sut.reloadSessions()
        try? await Task.sleep(for: .milliseconds(200))

        sut.searchQuery = "Searchable"
        // Wait for debounce + search
        try? await Task.sleep(for: .milliseconds(400))

        XCTAssertFalse(sut.searchResults.isEmpty)
        XCTAssertEqual(sut.searchResults.first?.session.id, session.id)
    }

    // MARK: - Sessions Changed Callback

    func testOnSessionsChangedCalledOnReload() async {
        let sut = makeSUT()

        var callbackCount = 0
        sut.onSessionsChanged = { callbackCount += 1 }

        sut.reloadSessions()
        try? await Task.sleep(for: .milliseconds(200))

        XCTAssertGreaterThan(callbackCount, 0)
    }
}
