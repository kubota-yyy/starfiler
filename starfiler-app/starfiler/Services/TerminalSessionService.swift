import Foundation

struct TerminalSessionSearchResult: Sendable {
    let session: TerminalSession
    let matchedLines: [String]
}

protocol TerminalSessionProviding: Sendable {
    func sessions() async -> [TerminalSession]
    func session(for id: UUID) async -> TerminalSession?
    func createSession(command: TerminalSessionCommand, workingDirectory: URL) async -> TerminalSession
    func removeSession(id: UUID) async
    func updateStatus(id: UUID, status: TerminalSessionStatus) async
    func updateExitCode(id: UUID, exitCode: Int32) async
    func updateLastActivity(id: UUID) async
    func updateTitle(id: UUID, title: String) async
    func pin(id: UUID) async
    func unpin(id: UUID) async
    func rename(id: UUID, title: String) async
    func appendOutput(id: UUID, text: String) async
    func search(query: String, providerFilter: TerminalSessionCommand?) async -> [TerminalSessionSearchResult]
    func logLines(for id: UUID) async -> [String]
    func loadPersistedSessions(_ sessions: [TerminalSession], logs: [UUID: [String]]) async
    func allSessionsWithLogs() async -> (sessions: [TerminalSession], logs: [UUID: [String]])
}

actor TerminalSessionService: TerminalSessionProviding {
    private static let maxLogLines = 2000

    private var sessionStore: [UUID: TerminalSession] = [:]
    private var sessionOrder: [UUID] = []
    private var sessionLogs: [UUID: [String]] = [:]

    func sessions() -> [TerminalSession] {
        sortedSessions()
    }

    func session(for id: UUID) -> TerminalSession? {
        sessionStore[id]
    }

    func createSession(command: TerminalSessionCommand, workingDirectory: URL) -> TerminalSession {
        let session = TerminalSession(command: command, workingDirectory: workingDirectory)
        sessionStore[session.id] = session
        sessionOrder.append(session.id)
        sessionLogs[session.id] = []
        return session
    }

    func removeSession(id: UUID) {
        sessionStore.removeValue(forKey: id)
        sessionOrder.removeAll { $0 == id }
        sessionLogs.removeValue(forKey: id)
    }

    func updateStatus(id: UUID, status: TerminalSessionStatus) {
        sessionStore[id]?.status = status
        sessionStore[id]?.updatedAt = Date()
    }

    func updateExitCode(id: UUID, exitCode: Int32) {
        sessionStore[id]?.exitCode = exitCode
        sessionStore[id]?.status = exitCode == 0 ? .completed : .error
        sessionStore[id]?.updatedAt = Date()
    }

    func updateLastActivity(id: UUID) {
        let now = Date()
        sessionStore[id]?.lastActivityAt = now
        sessionStore[id]?.updatedAt = now
    }

    func updateTitle(id: UUID, title: String) {
        sessionStore[id]?.title = title
        sessionStore[id]?.updatedAt = Date()
    }

    func pin(id: UUID) {
        sessionStore[id]?.isPinned = true
        sessionStore[id]?.updatedAt = Date()
    }

    func unpin(id: UUID) {
        sessionStore[id]?.isPinned = false
        sessionStore[id]?.updatedAt = Date()
    }

    func rename(id: UUID, title: String) {
        sessionStore[id]?.title = title
        sessionStore[id]?.updatedAt = Date()
    }

    func appendOutput(id: UUID, text: String) {
        let cleaned = Self.stripANSI(text)
        let newLines = cleaned.components(separatedBy: .newlines).filter { !$0.isEmpty }
        guard !newLines.isEmpty else { return }

        var lines = sessionLogs[id] ?? []
        lines.append(contentsOf: newLines)
        if lines.count > Self.maxLogLines {
            lines = Array(lines.suffix(Self.maxLogLines))
        }
        sessionLogs[id] = lines

        let now = Date()
        sessionStore[id]?.lastActivityAt = now
        sessionStore[id]?.updatedAt = now
    }

    func search(query: String, providerFilter: TerminalSessionCommand?) -> [TerminalSessionSearchResult] {
        let lowercaseQuery = query.lowercased()
        guard !lowercaseQuery.isEmpty else {
            return sortedSessions()
                .filter { providerFilter == nil || $0.command == providerFilter }
                .map { TerminalSessionSearchResult(session: $0, matchedLines: []) }
        }

        var results: [TerminalSessionSearchResult] = []
        for session in sortedSessions() {
            if let filter = providerFilter, session.command != filter {
                continue
            }

            var matchedLines: [String] = []

            if session.title.lowercased().contains(lowercaseQuery) {
                matchedLines.append("Title: \(session.title)")
            }
            if session.workingDirectory.path.lowercased().contains(lowercaseQuery) {
                matchedLines.append("CWD: \(session.workingDirectory.path)")
            }
            if session.command.displayName.lowercased().contains(lowercaseQuery) {
                matchedLines.append("Provider: \(session.command.displayName)")
            }

            let lines = sessionLogs[session.id] ?? []
            for line in lines {
                if line.lowercased().contains(lowercaseQuery) {
                    matchedLines.append(line)
                    if matchedLines.count >= 5 { break }
                }
            }

            if !matchedLines.isEmpty {
                results.append(TerminalSessionSearchResult(session: session, matchedLines: matchedLines))
            }
        }

        return results
    }

    func logLines(for id: UUID) -> [String] {
        sessionLogs[id] ?? []
    }

    func loadPersistedSessions(_ sessions: [TerminalSession], logs: [UUID: [String]]) {
        for var session in sessions {
            if session.status.isActive {
                session.status = .stopped
            }
            sessionStore[session.id] = session
            sessionOrder.append(session.id)
            sessionLogs[session.id] = logs[session.id] ?? []
        }
    }

    func allSessionsWithLogs() -> (sessions: [TerminalSession], logs: [UUID: [String]]) {
        (sessions: sortedSessions(), logs: sessionLogs)
    }

    // MARK: - Private

    private func sortedSessions() -> [TerminalSession] {
        let allSessions = sessionOrder.compactMap { sessionStore[$0] }
        return allSessions.sorted { lhs, rhs in
            if lhs.isPinned != rhs.isPinned {
                return lhs.isPinned
            }
            if lhs.status.isActive != rhs.status.isActive {
                return lhs.status.isActive
            }
            return lhs.lastActivityAt > rhs.lastActivityAt
        }
    }

    private static let ansiPattern = try! NSRegularExpression(pattern: "\\x1b\\[[0-9;]*[a-zA-Z]|\\x1b\\][^\\x07]*\\x07|\\x1b[()][AB012]|\\x1b\\[\\?[0-9;]*[hl]", options: [])

    static func stripANSI(_ text: String) -> String {
        let range = NSRange(text.startIndex..., in: text)
        return ansiPattern.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: "")
    }
}
