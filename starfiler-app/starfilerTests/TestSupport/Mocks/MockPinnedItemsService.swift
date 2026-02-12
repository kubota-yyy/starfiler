import Foundation
@testable import Starfiler

@MainActor
final class MockPinnedItemsService: PinnedItemsProviding, @unchecked Sendable {
    // MARK: - Internal Storage

    private var items: [PinnedItem] = []

    // MARK: - togglePin

    private(set) var togglePinCallCount = 0
    private(set) var togglePinCapturedURLs: [URL] = []

    func togglePin(for url: URL, isDirectory: Bool) {
        togglePinCallCount += 1
        togglePinCapturedURLs.append(url)

        let path = url.standardizedFileURL.path
        if isPinned(path: path) {
            unpin(path: path)
        } else {
            pin(url: url, isDirectory: isDirectory)
        }
    }

    // MARK: - pin

    private(set) var pinCallCount = 0
    private(set) var pinCapturedURLs: [URL] = []

    func pin(url: URL, isDirectory: Bool) {
        pinCallCount += 1
        pinCapturedURLs.append(url)

        let path = url.standardizedFileURL.path
        guard !isPinned(path: path) else { return }
        let displayName = url.lastPathComponent.isEmpty ? path : url.lastPathComponent
        items.append(PinnedItem(path: path, displayName: displayName, isDirectory: isDirectory))
    }

    // MARK: - unpin

    private(set) var unpinCallCount = 0
    private(set) var unpinCapturedPaths: [String] = []

    func unpin(path: String) {
        unpinCallCount += 1
        unpinCapturedPaths.append(path)
        items.removeAll { $0.path == path }
    }

    // MARK: - isPinned

    private(set) var isPinnedCallCount = 0

    func isPinned(path: String) -> Bool {
        isPinnedCallCount += 1
        return items.contains { $0.path == path }
    }

    // MARK: - allPinnedItems

    private(set) var allPinnedItemsCallCount = 0

    func allPinnedItems() -> [PinnedItem] {
        allPinnedItemsCallCount += 1
        return items.sorted { $0.pinnedAt > $1.pinnedAt }
    }

    // MARK: - clearAllPins

    private(set) var clearAllPinsCallCount = 0

    func clearAllPins() {
        clearAllPinsCallCount += 1
        items.removeAll()
    }
}
