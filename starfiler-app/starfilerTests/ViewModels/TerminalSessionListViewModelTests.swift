import XCTest
@testable import Starfiler

@MainActor
final class TerminalSessionListViewModelTests: XCTestCase {

    // MARK: - Properties

    private var mockService: MockTerminalSessionService!

    // MARK: - Setup

    override func setUp() {
        super.setUp()
        mockService = MockTerminalSessionService()
    }

    // MARK: - Helpers

    private func makeSUT() -> TerminalSessionListViewModel {
        TerminalSessionListViewModel(service: mockService)
    }

    // MARK: - Initial State

    func testInitialState() {
        let sut = makeSUT()

        XCTAssertTrue(sut.sessions.isEmpty)
        XCTAssertNil(sut.activeSessionId)
    }

    // MARK: - Create Session

    func testCreateSession() async {
        let sut = makeSUT()
        let workingDir = URL(fileURLWithPath: "/tmp/test")

        var createdSession: TerminalSession?
        sut.onSessionCreated = { session in createdSession = session }

        sut.createSession(command: .claude, workingDirectory: workingDir)
        try? await Task.sleep(for: .milliseconds(200))

        XCTAssertNotNil(createdSession)
        XCTAssertNotNil(sut.activeSessionId)
        XCTAssertEqual(sut.sessions.count, 1)
    }

    // MARK: - Remove Session

    func testRemoveSession() async {
        let sut = makeSUT()
        let workingDir = URL(fileURLWithPath: "/tmp/test")

        sut.createSession(command: .claude, workingDirectory: workingDir)
        try? await Task.sleep(for: .milliseconds(200))

        guard let sessionId = sut.sessions.first?.id else {
            XCTFail("No session created")
            return
        }

        var removedId: UUID?
        sut.onSessionRemoved = { id in removedId = id }

        sut.removeSession(id: sessionId)
        try? await Task.sleep(for: .milliseconds(200))

        XCTAssertEqual(removedId, sessionId)
        XCTAssertTrue(sut.sessions.isEmpty)
    }

    func testRemoveActiveSessionSelectsLastSession() async {
        let sut = makeSUT()
        let workingDir = URL(fileURLWithPath: "/tmp/test")

        sut.createSession(command: .claude, workingDirectory: workingDir)
        try? await Task.sleep(for: .milliseconds(200))
        sut.createSession(command: .codex, workingDirectory: workingDir)
        try? await Task.sleep(for: .milliseconds(200))

        let firstId = sut.activeSessionId

        // Remove the active session (last created)
        guard let activeId = sut.activeSessionId else {
            XCTFail("No active session")
            return
        }

        sut.removeSession(id: activeId)
        try? await Task.sleep(for: .milliseconds(200))

        XCTAssertEqual(sut.sessions.count, 1)
        // After removing active, the remaining session becomes active
        XCTAssertNotNil(sut.activeSessionId)
    }

    // MARK: - Set Active Session

    func testSetActiveSessionWithValidId() async {
        let sut = makeSUT()
        let workingDir = URL(fileURLWithPath: "/tmp/test")

        sut.createSession(command: .claude, workingDirectory: workingDir)
        try? await Task.sleep(for: .milliseconds(200))

        guard let sessionId = sut.sessions.first?.id else {
            XCTFail("No session created")
            return
        }

        var capturedId: UUID?
        sut.onActiveSessionChanged = { id in capturedId = id }

        sut.setActiveSession(id: sessionId)

        XCTAssertEqual(sut.activeSessionId, sessionId)
        XCTAssertEqual(capturedId, sessionId)
    }

    func testSetActiveSessionWithInvalidIdDoesNothing() {
        let sut = makeSUT()
        let bogusId = UUID()

        sut.setActiveSession(id: bogusId)

        XCTAssertNil(sut.activeSessionId)
    }

    // MARK: - Update Session Status

    func testUpdateSessionStatus() async {
        let sut = makeSUT()
        let workingDir = URL(fileURLWithPath: "/tmp/test")

        sut.createSession(command: .claude, workingDirectory: workingDir)
        try? await Task.sleep(for: .milliseconds(200))

        guard let sessionId = sut.sessions.first?.id else {
            XCTFail("No session created")
            return
        }

        sut.updateSessionStatus(id: sessionId, status: .running)
        try? await Task.sleep(for: .milliseconds(200))

        let updatedSession = sut.sessions.first(where: { $0.id == sessionId })
        XCTAssertEqual(updatedSession?.status, .running)
    }

    // MARK: - Update Session Title

    func testUpdateSessionTitle() async {
        let sut = makeSUT()
        let workingDir = URL(fileURLWithPath: "/tmp/test")

        sut.createSession(command: .claude, workingDirectory: workingDir)
        try? await Task.sleep(for: .milliseconds(200))

        guard let sessionId = sut.sessions.first?.id else {
            XCTFail("No session created")
            return
        }

        sut.updateSessionTitle(id: sessionId, title: "My Custom Title")
        try? await Task.sleep(for: .milliseconds(200))

        let updatedSession = sut.sessions.first(where: { $0.id == sessionId })
        XCTAssertEqual(updatedSession?.title, "My Custom Title")
    }
}
