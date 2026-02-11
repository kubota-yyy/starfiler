import Foundation

struct PaneState: Hashable, Sendable {
    var currentDirectory: URL
    var cursorIndex: Int
    var markedIndices: Set<Int>

    init(currentDirectory: URL, cursorIndex: Int = 0, markedIndices: Set<Int> = []) {
        self.currentDirectory = currentDirectory
        self.cursorIndex = cursorIndex
        self.markedIndices = markedIndices
    }
}
