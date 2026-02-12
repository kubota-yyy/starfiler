import Foundation

protocol TerminalSessionProviding: Sendable {
    func sessions() async -> [TerminalSession]
    func session(for id: UUID) async -> TerminalSession?
    func createSession(command: TerminalSessionCommand, workingDirectory: URL) async -> TerminalSession
    func removeSession(id: UUID) async
    func updateStatus(id: UUID, status: TerminalSessionStatus) async
    func updateExitCode(id: UUID, exitCode: Int32) async
    func updateLastActivity(id: UUID) async
    func updateTitle(id: UUID, title: String) async
}

actor TerminalSessionService: TerminalSessionProviding {
    private var sessionStore: [UUID: TerminalSession] = [:]
    private var sessionOrder: [UUID] = []

    func sessions() -> [TerminalSession] {
        sessionOrder.compactMap { sessionStore[$0] }
    }

    func session(for id: UUID) -> TerminalSession? {
        sessionStore[id]
    }

    func createSession(command: TerminalSessionCommand, workingDirectory: URL) -> TerminalSession {
        let session = TerminalSession(command: command, workingDirectory: workingDirectory)
        sessionStore[session.id] = session
        sessionOrder.append(session.id)
        return session
    }

    func removeSession(id: UUID) {
        sessionStore.removeValue(forKey: id)
        sessionOrder.removeAll { $0 == id }
    }

    func updateStatus(id: UUID, status: TerminalSessionStatus) {
        sessionStore[id]?.status = status
    }

    func updateExitCode(id: UUID, exitCode: Int32) {
        sessionStore[id]?.exitCode = exitCode
        sessionStore[id]?.status = exitCode == 0 ? .completed : .error
    }

    func updateLastActivity(id: UUID) {
        sessionStore[id]?.lastActivityAt = Date()
    }

    func updateTitle(id: UUID, title: String) {
        sessionStore[id]?.title = title
    }
}
