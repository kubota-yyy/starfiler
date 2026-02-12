import Foundation

enum PaneSide: Sendable {
    case left
    case right
}

enum PaneDisplayMode: String, Codable, CaseIterable, Sendable {
    case browser
    case media
}

struct PaneState: Hashable, Sendable {
    var currentDirectory: URL
    var cursorIndex: Int
    var markedIndices: IndexSet
    var visualAnchorIndex: Int?

    init(
        currentDirectory: URL,
        cursorIndex: Int = 0,
        markedIndices: IndexSet = [],
        visualAnchorIndex: Int? = nil
    ) {
        self.currentDirectory = currentDirectory
        self.cursorIndex = cursorIndex
        self.markedIndices = markedIndices
        self.visualAnchorIndex = visualAnchorIndex
    }
}
