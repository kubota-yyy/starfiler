import Foundation

struct TreeDisplayItem: Hashable, Identifiable, Sendable {
    let fileItem: FileItem
    let depth: Int
    let isExpanded: Bool
    let isExpandable: Bool
    let parentURL: URL?

    var id: URL { fileItem.url }
}
