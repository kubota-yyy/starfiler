import Foundation
@testable import Starfiler

actor MockTerminalSessionService: TerminalSessionProviding {
    // MARK: - Internal Storage

    private var sessionStore: [UUID: TerminalSession] = [:]
    private var sessionOrder: [UUID] = []
    private var sessionLogs: [UUID: [String]] = [:]

    // MARK: - Call Tracking

    private(set) var sessionsCallCount = 0
    private(set) var sessionForIdCallCount = 0
    private(set) var createSessionCallCount = 0
    private(set) var removeSessionCallCount = 0
    private(set) var updateStatusCallCount = 0
    private(set) var updateExitCodeCallCount = 0
    private(set) var updateLastActivityCallCount = 0
    private(set) var updateTitleCallCount = 0
    private(set) var pinCallCount = 0
    private(set) var unpinCallCount = 0
    private(set) var renameCallCount = 0
    private(set) var appendOutputCallCount = 0
    private(set) var searchCallCount = 0

    // MARK: - sessions

    func sessions() -> [TerminalSession] {
        sessionsCallCount += 1
        return sortedSessions()
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
        sessionLogs[session.id] = []
        return session
    }

    // MARK: - removeSession

    func removeSession(id: UUID) {
        removeSessionCallCount += 1
        sessionStore.removeValue(forKey: id)
        sessionOrder.removeAll { $0 == id }
        sessionLogs.removeValue(forKey: id)
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

    // MARK: - pin

    func pin(id: UUID) {
        pinCallCount += 1
        sessionStore[id]?.isPinned = true
    }

    // MARK: - unpin

    func unpin(id: UUID) {
        unpinCallCount += 1
        sessionStore[id]?.isPinned = false
    }

    // MARK: - rename

    func rename(id: UUID, title: String) {
        renameCallCount += 1
        sessionStore[id]?.title = title
    }

    // MARK: - appendOutput

    func appendOutput(id: UUID, text: String) {
        appendOutputCallCount += 1
        let lines = text.components(separatedBy: .newlines).filter { !$0.isEmpty }
        var existing = sessionLogs[id] ?? []
        existing.append(contentsOf: lines)
        if existing.count > 2000 {
            existing = Array(existing.suffix(2000))
        }
        sessionLogs[id] = existing
    }

    // MARK: - search

    func search(query: String, providerFilter: TerminalSessionCommand?) -> [TerminalSessionSearchResult] {
        searchCallCount += 1
        let lowercaseQuery = query.lowercased()
        guard !lowercaseQuery.isEmpty else {
            return sortedSessions()
                .filter { providerFilter == nil || $0.command == providerFilter }
                .map { TerminalSessionSearchResult(session: $0, matchedLines: []) }
        }

        var results: [TerminalSessionSearchResult] = []
        for session in sortedSessions() {
            if let filter = providerFilter, session.command != filter { continue }
            var matchedLines: [String] = []
            if session.title.lowercased().contains(lowercaseQuery) {
                matchedLines.append("Title: \(session.title)")
            }
            let lines = sessionLogs[session.id] ?? []
            for line in lines where line.lowercased().contains(lowercaseQuery) {
                matchedLines.append(line)
                if matchedLines.count >= 5 { break }
            }
            if !matchedLines.isEmpty {
                results.append(TerminalSessionSearchResult(session: session, matchedLines: matchedLines))
            }
        }
        return results
    }

    // MARK: - logLines

    func logLines(for id: UUID) -> [String] {
        sessionLogs[id] ?? []
    }

    // MARK: - loadPersistedSessions

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

    // MARK: - allSessionsWithLogs

    func allSessionsWithLogs() -> (sessions: [TerminalSession], logs: [UUID: [String]]) {
        (sessions: sortedSessions(), logs: sessionLogs)
    }

    // MARK: - Private

    private func sortedSessions() -> [TerminalSession] {
        let allSessions = sessionOrder.compactMap { sessionStore[$0] }
        return allSessions.sorted { lhs, rhs in
            if lhs.isPinned != rhs.isPinned { return lhs.isPinned }
            if lhs.status.isActive != rhs.status.isActive { return lhs.status.isActive }
            return lhs.lastActivityAt > rhs.lastActivityAt
        }
    }
}
