import Foundation

struct TerminalSessionsConfig: Codable, Sendable {
    static let formatVersion = 1

    struct SessionDTO: Codable, Sendable {
        let id: UUID
        var title: String
        var status: TerminalSessionStatus
        let workingDirectory: String
        let command: TerminalSessionCommand
        var exitCode: Int32?
        let createdAt: Date
        var lastActivityAt: Date
        var isPinned: Bool
        var lastOpenedAt: Date
        var updatedAt: Date

        init(session: TerminalSession) {
            self.id = session.id
            self.title = session.title
            self.status = session.status
            self.workingDirectory = session.workingDirectory.path
            self.command = session.command
            self.exitCode = session.exitCode
            self.createdAt = session.createdAt
            self.lastActivityAt = session.lastActivityAt
            self.isPinned = session.isPinned
            self.lastOpenedAt = session.lastOpenedAt
            self.updatedAt = session.updatedAt
        }

        func toSession() -> TerminalSession {
            var session = TerminalSession(
                id: id,
                title: title,
                command: command,
                workingDirectory: URL(fileURLWithPath: workingDirectory, isDirectory: true),
                isPinned: isPinned
            )
            session.status = status.isActive ? .stopped : status
            session.exitCode = exitCode
            session.lastActivityAt = lastActivityAt
            session.lastOpenedAt = lastOpenedAt
            session.updatedAt = updatedAt
            return session
        }
    }

    struct LogDTO: Codable, Sendable {
        let sessionId: UUID
        let lines: [String]
    }

    let formatVersion: Int
    let savedAt: Date
    let sessions: [SessionDTO]
    let logs: [LogDTO]

    init(sessions: [TerminalSession], logs: [UUID: [String]]) {
        self.formatVersion = Self.formatVersion
        self.savedAt = Date()
        self.sessions = sessions.map { SessionDTO(session: $0) }
        self.logs = logs.map { LogDTO(sessionId: $0.key, lines: $0.value) }
    }

    func toSessionsAndLogs() -> (sessions: [TerminalSession], logs: [UUID: [String]]) {
        let restoredSessions = sessions.map { $0.toSession() }
        var restoredLogs: [UUID: [String]] = [:]
        for log in logs {
            restoredLogs[log.sessionId] = log.lines
        }
        return (sessions: restoredSessions, logs: restoredLogs)
    }
}
