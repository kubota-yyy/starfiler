import Foundation
@testable import Starfiler

actor MockTerminalSessionService: TerminalSessionProviding {
    // MARK: - Internal Storage

    private var sessionStore: [UUID: TerminalSession] = [:]
    private var sessionOrder: [UUID] = []

    // MARK: - Call Tracking

    private(set) var sessionsCallCount = 0
    private(set) var sessionForIdCallCount = 0
    private(set) var createSessionCallCount = 0
    private(set) var removeSessionCallCount = 0
    private(set) var updateStatusCallCount = 0
    private(set) var updateExitCodeCallCount = 0
    private(set) var updateLastActivityCallCount = 0
    private(set) var updateTitleCallCount = 0

    // MARK: - sessions

    func sessions() -> [TerminalSession] {
        sessionsCallCount += 1
        return sessionOrder.compactMap { sessionStore[$0] }
    }

    // MARK: - session(for:)

    func session(for id: UUID) -> TerminalSession? {
        sessionForIdCallCount += 1
        return sessionStore[id]
    }

    // MARK: - createSession

    func createSession(command: TerminalSessionCommand, workingDirectory: URL) -> TerminalSession {
        createSessionCallCount += 1
        let session = TerminalSession(command: command, workingDirectory: workingDirectory)
        sessionStore[session.id] = session
        sessionOrder.append(session.id)
        return session
    }

    // MARK: - removeSession

    func removeSession(id: UUID) {
        removeSessionCallCount += 1
        sessionStore.removeValue(forKey: id)
        sessionOrder.removeAll { $0 == id }
    }

    // MARK: - updateStatus

    func updateStatus(id: UUID, status: TerminalSessionStatus) {
        updateStatusCallCount += 1
        sessionStore[id]?.status = status
    }

    // MARK: - updateExitCode

    func updateExitCode(id: UUID, exitCode: Int32) {
        updateExitCodeCallCount += 1
        sessionStore[id]?.exitCode = exitCode
        sessionStore[id]?.status = exitCode == 0 ? .completed : .error
    }

    // MARK: - updateLastActivity

    func updateLastActivity(id: UUID) {
        updateLastActivityCallCount += 1
        sessionStore[id]?.lastActivityAt = Date()
    }

    // MARK: - updateTitle

    func updateTitle(id: UUID, title: String) {
        updateTitleCallCount += 1
        sessionStore[id]?.title = title
    }
}
