import XCTest
@testable import Starfiler

final class TerminalSessionServiceTests: XCTestCase {

    private func makeSUT() -> TerminalSessionService {
        TerminalSessionService()
    }

    // MARK: - Create / Delete

    func testCreateSessionReturnsSession() async {
        let sut = makeSUT()
        let workingDir = URL(fileURLWithPath: "/tmp/test")

        let session = await sut.createSession(command: .claude, workingDirectory: workingDir)

        XCTAssertEqual(session.command, .claude)
        XCTAssertEqual(session.workingDirectory, workingDir)
        XCTAssertEqual(session.status, .launching)
        XCTAssertFalse(session.isPinned)
    }

    func testCreateMultipleSessions() async {
        let sut = makeSUT()
        let workingDir = URL(fileURLWithPath: "/tmp/test")

        let s1 = await sut.createSession(command: .claude, workingDirectory: workingDir)
        let s2 = await sut.createSession(command: .codex, workingDirectory: workingDir)

        let all = await sut.sessions()
        XCTAssertEqual(all.count, 2)
        XCTAssertTrue(all.contains(where: { $0.id == s1.id }))
        XCTAssertTrue(all.contains(where: { $0.id == s2.id }))
    }

    func testRemoveSession() async {
        let sut = makeSUT()
        let workingDir = URL(fileURLWithPath: "/tmp/test")

        let session = await sut.createSession(command: .claude, workingDirectory: workingDir)
        await sut.removeSession(id: session.id)

        let all = await sut.sessions()
        XCTAssertTrue(all.isEmpty)
    }

    func testRemoveNonexistentSessionDoesNothing() async {
        let sut = makeSUT()
        let workingDir = URL(fileURLWithPath: "/tmp/test")

        _ = await sut.createSession(command: .claude, workingDirectory: workingDir)
        await sut.removeSession(id: UUID())

        let all = await sut.sessions()
        XCTAssertEqual(all.count, 1)
    }

    // MARK: - Pin / Unpin

    func testPinSession() async {
        let sut = makeSUT()
        let session = await sut.createSession(command: .claude, workingDirectory: URL(fileURLWithPath: "/tmp"))

        await sut.pin(id: session.id)

        let fetched = await sut.session(for: session.id)
        XCTAssertTrue(fetched?.isPinned == true)
    }

    func testUnpinSession() async {
        let sut = makeSUT()
        let session = await sut.createSession(command: .claude, workingDirectory: URL(fileURLWithPath: "/tmp"))

        await sut.pin(id: session.id)
        await sut.unpin(id: session.id)

        let fetched = await sut.session(for: session.id)
        XCTAssertFalse(fetched?.isPinned == true)
    }

    // MARK: - Rename

    func testRenameSession() async {
        let sut = makeSUT()
        let session = await sut.createSession(command: .claude, workingDirectory: URL(fileURLWithPath: "/tmp"))

        await sut.rename(id: session.id, title: "Renamed")

        let fetched = await sut.session(for: session.id)
        XCTAssertEqual(fetched?.title, "Renamed")
    }

    // MARK: - Sort Order (pinned → active → lastActivity desc)

    func testSortOrderPinnedFirst() async {
        let sut = makeSUT()
        let dir = URL(fileURLWithPath: "/tmp")

        let s1 = await sut.createSession(command: .claude, workingDirectory: dir)
        let s2 = await sut.createSession(command: .codex, workingDirectory: dir)

        await sut.pin(id: s1.id)

        let sorted = await sut.sessions()
        XCTAssertEqual(sorted.first?.id, s1.id)
    }

    func testSortOrderActiveBeforeInactive() async {
        let sut = makeSUT()
        let dir = URL(fileURLWithPath: "/tmp")

        let s1 = await sut.createSession(command: .claude, workingDirectory: dir)
        try? await Task.sleep(for: .milliseconds(10))
        let s2 = await sut.createSession(command: .codex, workingDirectory: dir)

        // s1 is stopped, s2 stays launching (active)
        await sut.updateStatus(id: s1.id, status: .stopped)

        let sorted = await sut.sessions()
        XCTAssertEqual(sorted.first?.id, s2.id)
    }

    // MARK: - Log Ring Buffer

    func testAppendOutputStoresLines() async {
        let sut = makeSUT()
        let session = await sut.createSession(command: .claude, workingDirectory: URL(fileURLWithPath: "/tmp"))

        await sut.appendOutput(id: session.id, text: "Line 1\nLine 2\nLine 3")

        let lines = await sut.logLines(for: session.id)
        XCTAssertEqual(lines.count, 3)
        XCTAssertEqual(lines[0], "Line 1")
        XCTAssertEqual(lines[1], "Line 2")
        XCTAssertEqual(lines[2], "Line 3")
    }

    func testLogRotationAt2000Lines() async {
        let sut = makeSUT()
        let session = await sut.createSession(command: .claude, workingDirectory: URL(fileURLWithPath: "/tmp"))

        // Fill with 2000 lines
        for i in 0..<2000 {
            await sut.appendOutput(id: session.id, text: "Line \(i)")
        }

        var lines = await sut.logLines(for: session.id)
        XCTAssertEqual(lines.count, 2000)

        // Add one more → oldest should be evicted
        await sut.appendOutput(id: session.id, text: "Overflow line")

        lines = await sut.logLines(for: session.id)
        XCTAssertEqual(lines.count, 2000)
        XCTAssertEqual(lines.last, "Overflow line")
        XCTAssertFalse(lines.contains("Line 0"))
    }

    // MARK: - ANSI Stripping

    func testStripANSIRemovesEscapeSequences() {
        let input = "\u{1b}[32mHello\u{1b}[0m World"
        let result = TerminalSessionService.stripANSI(input)
        XCTAssertEqual(result, "Hello World")
    }

    func testStripANSIPreservesPlainText() {
        let input = "Plain text without escapes"
        let result = TerminalSessionService.stripANSI(input)
        XCTAssertEqual(result, "Plain text without escapes")
    }

    // MARK: - Search

    func testSearchByTitle() async {
        let sut = makeSUT()
        let dir = URL(fileURLWithPath: "/tmp")

        let s1 = await sut.createSession(command: .claude, workingDirectory: dir)
        await sut.rename(id: s1.id, title: "My Claude Session")
        let s2 = await sut.createSession(command: .codex, workingDirectory: dir)
        await sut.rename(id: s2.id, title: "My Codex Session")

        let results = await sut.search(query: "Claude", providerFilter: nil)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.session.id, s1.id)
    }

    func testSearchByLogContent() async {
        let sut = makeSUT()
        let dir = URL(fileURLWithPath: "/tmp")

        let session = await sut.createSession(command: .claude, workingDirectory: dir)
        await sut.appendOutput(id: session.id, text: "ERROR: connection refused")

        let results = await sut.search(query: "connection", providerFilter: nil)
        XCTAssertEqual(results.count, 1)
        XCTAssertTrue(results.first?.matchedLines.contains(where: { $0.contains("connection") }) == true)
    }

    func testSearchWithProviderFilter() async {
        let sut = makeSUT()
        let dir = URL(fileURLWithPath: "/tmp")

        _ = await sut.createSession(command: .claude, workingDirectory: dir)
        _ = await sut.createSession(command: .codex, workingDirectory: dir)

        let results = await sut.search(query: "Claude", providerFilter: .codex)
        XCTAssertTrue(results.isEmpty)
    }

    func testSearchEmptyQueryReturnsAllSessions() async {
        let sut = makeSUT()
        let dir = URL(fileURLWithPath: "/tmp")

        _ = await sut.createSession(command: .claude, workingDirectory: dir)
        _ = await sut.createSession(command: .codex, workingDirectory: dir)

        let results = await sut.search(query: "", providerFilter: nil)
        XCTAssertEqual(results.count, 2)
    }

    // MARK: - Persistence Restore

    func testLoadPersistedSessionsNormalizesActiveToStopped() async {
        let sut = makeSUT()
        let dir = URL(fileURLWithPath: "/tmp")

        let runningSession = TerminalSession(
            id: UUID(),
            title: "Running Session",
            status: .running,
            command: .claude,
            workingDirectory: dir,
            exitCode: nil,
            createdAt: Date(),
            lastActivityAt: Date(),
            isPinned: false,
            lastOpenedAt: Date(),
            updatedAt: Date()
        )

        await sut.loadPersistedSessions([runningSession], logs: [:])

        let sessions = await sut.sessions()
        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(sessions.first?.status, .stopped)
    }

    func testLoadPersistedSessionsPreservesCompletedStatus() async {
        let sut = makeSUT()
        let dir = URL(fileURLWithPath: "/tmp")

        let completedSession = TerminalSession(
            id: UUID(),
            title: "Done Session",
            status: .completed,
            command: .claude,
            workingDirectory: dir,
            exitCode: 0,
            createdAt: Date(),
            lastActivityAt: Date(),
            isPinned: false,
            lastOpenedAt: Date(),
            updatedAt: Date()
        )

        await sut.loadPersistedSessions([completedSession], logs: [:])

        let sessions = await sut.sessions()
        XCTAssertEqual(sessions.first?.status, .completed)
    }

    func testLoadPersistedSessionsRestoresLogs() async {
        let sut = makeSUT()
        let dir = URL(fileURLWithPath: "/tmp")
        let id = UUID()

        let session = TerminalSession(
            id: id,
            title: "Test",
            status: .stopped,
            command: .claude,
            workingDirectory: dir,
            exitCode: nil,
            createdAt: Date(),
            lastActivityAt: Date(),
            isPinned: false,
            lastOpenedAt: Date(),
            updatedAt: Date()
        )

        let logs: [UUID: [String]] = [id: ["log line 1", "log line 2"]]
        await sut.loadPersistedSessions([session], logs: logs)

        let restoredLogs = await sut.logLines(for: id)
        XCTAssertEqual(restoredLogs, ["log line 1", "log line 2"])
    }

    // MARK: - allSessionsWithLogs

    func testAllSessionsWithLogs() async {
        let sut = makeSUT()
        let dir = URL(fileURLWithPath: "/tmp")

        let session = await sut.createSession(command: .claude, workingDirectory: dir)
        await sut.appendOutput(id: session.id, text: "Hello")

        let data = await sut.allSessionsWithLogs()
        XCTAssertEqual(data.sessions.count, 1)
        XCTAssertEqual(data.logs[session.id]?.count, 1)
    }
}
