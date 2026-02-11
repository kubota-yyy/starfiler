import Foundation

protocol VisitHistoryProviding: Sendable {
    func recordVisit(to directory: URL)
    func recentEntries(limit: Int) -> [VisitHistoryEntry]
    func allEntries() -> [VisitHistoryEntry]
    func clearHistory()
}

@MainActor
final class VisitHistoryService: VisitHistoryProviding {
    private let configManager: ConfigManager
    private var config: VisitHistoryConfig
    private var pendingSaveTask: Task<Void, Never>?

    init(configManager: ConfigManager) {
        self.configManager = configManager
        self.config = configManager.loadVisitHistoryConfig()
    }

    func recordVisit(to directory: URL) {
        let path = directory.standardizedFileURL.path
        let displayName = directory.lastPathComponent.isEmpty ? path : directory.lastPathComponent

        if let existingIndex = config.entries.firstIndex(where: { $0.path == path }) {
            config.entries[existingIndex].lastVisitedAt = Date()
            config.entries[existingIndex].visitCount += 1
            config.entries[existingIndex].displayName = displayName
        } else {
            let entry = VisitHistoryEntry(path: path, displayName: displayName)
            config.entries.append(entry)
        }

        if config.entries.count > config.maxEntries {
            config.entries.sort { $0.lastVisitedAt > $1.lastVisitedAt }
            config.entries = Array(config.entries.prefix(config.maxEntries))
        }

        scheduleSave()
    }

    func recentEntries(limit: Int) -> [VisitHistoryEntry] {
        let sorted = config.entries.sorted { $0.lastVisitedAt > $1.lastVisitedAt }
        return Array(sorted.prefix(limit))
    }

    func allEntries() -> [VisitHistoryEntry] {
        config.entries.sorted { $0.lastVisitedAt > $1.lastVisitedAt }
    }

    func clearHistory() {
        config.entries.removeAll()
        scheduleSave()
    }

    private func scheduleSave() {
        pendingSaveTask?.cancel()
        pendingSaveTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled, let self else {
                return
            }
            try? self.configManager.saveVisitHistoryConfig(self.config)
        }
    }
}
