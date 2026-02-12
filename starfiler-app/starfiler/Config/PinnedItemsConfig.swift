import Foundation

struct PinnedItemsConfig: Codable, Sendable {
    var items: [PinnedItem]
    var maxItems: Int

    init(items: [PinnedItem] = [], maxItems: Int = 50) {
        self.items = items
        self.maxItems = maxItems
    }
}
