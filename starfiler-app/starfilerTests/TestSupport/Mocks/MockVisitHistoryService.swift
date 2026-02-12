import Foundation
@testable import Starfiler

@MainActor
final class MockVisitHistoryService: VisitHistoryProviding, @unchecked Sendable {
    // MARK: - Internal Storage

    private var entries: [VisitHistoryEntry] = []

    // MARK: - recordVisit

    private(set) var recordVisitCallCount = 0
    private(set) var recordVisitCapturedURLs: [URL] = []

    func recordVisit(to directory: URL) {
        recordVisitCallCount += 1
        recordVisitCapturedURLs.append(directory)

        let path = directory.standardizedFileURL.path
        let displayName = directory.lastPathComponent.isEmpty ? path : directory.lastPathComponent

        if let existingIndex = entries.firstIndex(where: { $0.path == path }) {
            entries[existingIndex].lastVisitedAt = Date()
            entries[existingIndex].visitCount += 1
            entries[existingIndex].displayName = displayName
        } else {
            entries.append(VisitHistoryEntry(path: path, displayName: displayName))
        }
    }

    // MARK: - recentEntries

    var recentEntriesResult: [VisitHistoryEntry]?
    private(set) var recentEntriesCallCount = 0
    private(set) var recentEntriesCapturedLimits: [Int] = []

    func recentEntries(limit: Int) -> [VisitHistoryEntry] {
        recentEntriesCallCount += 1
        recentEntriesCapturedLimits.append(limit)

        if let overrideResult = recentEntriesResult {
            return Array(overrideResult.prefix(limit))
        }

        let sorted = entries.sorted { $0.lastVisitedAt > $1.lastVisitedAt }
        return Array(sorted.prefix(limit))
    }

    // MARK: - allEntries

    var allEntriesResult: [VisitHistoryEntry]?
    private(set) var allEntriesCallCount = 0

    func allEntries() -> [VisitHistoryEntry] {
        allEntriesCallCount += 1

        if let overrideResult = allEntriesResult {
            return overrideResult
        }

        return entries.sorted { $0.lastVisitedAt > $1.lastVisitedAt }
    }

    // MARK: - clearHistory

    private(set) var clearHistoryCallCount = 0

    func clearHistory() {
        clearHistoryCallCount += 1
        entries.removeAll()
    }
}
