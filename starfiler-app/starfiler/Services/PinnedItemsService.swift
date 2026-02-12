import Foundation

protocol PinnedItemsProviding: Sendable {
    func togglePin(for url: URL, isDirectory: Bool)
    func pin(url: URL, isDirectory: Bool)
    func unpin(path: String)
    func isPinned(path: String) -> Bool
    func allPinnedItems() -> [PinnedItem]
    func clearAllPins()
}

@MainActor
final class PinnedItemsService: PinnedItemsProviding {
    private let configManager: ConfigManager
    private var config: PinnedItemsConfig
    private var pendingSaveTask: Task<Void, Never>?

    init(configManager: ConfigManager) {
        self.configManager = configManager
        self.config = configManager.loadPinnedItemsConfig()
    }

    func togglePin(for url: URL, isDirectory: Bool) {
        let path = url.standardizedFileURL.path
        if isPinned(path: path) {
            unpin(path: path)
        } else {
            pin(url: url, isDirectory: isDirectory)
        }
    }

    func pin(url: URL, isDirectory: Bool) {
        let path = url.standardizedFileURL.path
        guard !isPinned(path: path) else {
            return
        }

        let displayName = url.lastPathComponent.isEmpty ? path : url.lastPathComponent
        let item = PinnedItem(path: path, displayName: displayName, isDirectory: isDirectory)
        config.items.append(item)

        if config.items.count > config.maxItems {
            config.items = Array(config.items.suffix(config.maxItems))
        }

        scheduleSave()
    }

    func unpin(path: String) {
        config.items.removeAll { $0.path == path }
        scheduleSave()
    }

    func isPinned(path: String) -> Bool {
        config.items.contains { $0.path == path }
    }

    func allPinnedItems() -> [PinnedItem] {
        config.items.sorted { $0.pinnedAt > $1.pinnedAt }
    }

    func clearAllPins() {
        config.items.removeAll()
        scheduleSave()
    }

    private func scheduleSave() {
        pendingSaveTask?.cancel()
        pendingSaveTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled, let self else {
                return
            }
            try? self.configManager.savePinnedItemsConfig(self.config)
        }
    }
}
