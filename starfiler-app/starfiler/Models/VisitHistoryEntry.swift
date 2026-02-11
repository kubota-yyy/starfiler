import Foundation

struct VisitHistoryEntry: Codable, Hashable, Sendable {
    let path: String
    var displayName: String
    var lastVisitedAt: Date
    var visitCount: Int

    init(path: String, displayName: String, lastVisitedAt: Date = Date(), visitCount: Int = 1) {
        self.path = path
        self.displayName = displayName
        self.lastVisitedAt = lastVisitedAt
        self.visitCount = visitCount
    }
}
