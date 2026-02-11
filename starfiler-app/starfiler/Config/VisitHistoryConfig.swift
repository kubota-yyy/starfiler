import Foundation

struct VisitHistoryConfig: Codable, Sendable {
    var entries: [VisitHistoryEntry]
    var maxEntries: Int

    init(entries: [VisitHistoryEntry] = [], maxEntries: Int = 200) {
        self.entries = entries
        self.maxEntries = maxEntries
    }
}
