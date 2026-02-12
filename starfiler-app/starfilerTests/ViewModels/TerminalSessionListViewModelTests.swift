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

    private func makeSUT(initialPanelVisible: Bool = false) -> TerminalSessionListViewModel {
        TerminalSessionListViewModel(
            service: mockService,
            initialPanelVisible: initialPanelVisible
        )
    }

    // MARK: - Initial State

    func testInitialState() {
        let sut = makeSUT()

        XCTAssertTrue(sut.sessions.isEmpty)
        XCTAssertNil(sut.activeSessionId)
        XCTAssertFalse(sut.terminalPanelVisible)
    }

    func testInitialPanelVisibleRespected() {
        let sut = makeSUT(initialPanelVisible: true)

        XCTAssertTrue(sut.terminalPanelVisible)
    }

    // MARK: - Toggle Panel

    func testTogglePanel() {
        let sut = makeSUT()

        var capturedVisible: Bool?
        sut.onPanelVisibilityChanged = { visible in capturedVisible = visible }

        sut.togglePanel()

        XCTAssertTrue(sut.terminalPanelVisible)
        XCTAssertEqual(capturedVisible, true)

        sut.togglePanel()

        XCTAssertFalse(sut.terminalPanelVisible)
        XCTAssertEqual(capturedVisible, false)
    }

    // MARK: - Show/Hide Panel

    func testShowPanel() {
        let sut = makeSUT()

        sut.showPanel()
        XCTAssertTrue(sut.terminalPanelVisible)

        // Calling again should be no-op
        var callbackCount = 0
        sut.onPanelVisibilityChanged = { _ in callbackCount += 1 }
        sut.showPanel()
        XCTAssertEqual(callbackCount, 0) // guard returns early
    }

    func testHidePanel() {
        let sut = makeSUT(initialPanelVisible: true)

        sut.hidePanel()
        XCTAssertFalse(sut.terminalPanelVisible)

        // Calling again should be no-op
        var callbackCount = 0
        sut.onPanelVisibilityChanged = { _ in callbackCount += 1 }
        sut.hidePanel()
        XCTAssertEqual(callbackCount, 0) // guard returns early
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
        XCTAssertTrue(sut.terminalPanelVisible)
        XCTAssertEqual(sut.sessions.count, 1)
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
}
