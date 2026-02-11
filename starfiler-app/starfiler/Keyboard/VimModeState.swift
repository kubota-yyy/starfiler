import Foundation

enum VimMode: String, Codable, Sendable {
    case normal
    case visual
    case filter
}

struct VimModeState: Sendable {
    private(set) var mode: VimMode
    private(set) var visualAnchorIndex: Int?

    init(mode: VimMode = .normal, visualAnchorIndex: Int? = nil) {
        self.mode = mode
        self.visualAnchorIndex = visualAnchorIndex
    }

    mutating func enterNormalMode() {
        mode = .normal
        visualAnchorIndex = nil
    }

    mutating func enterVisualMode(anchorIndex: Int) {
        mode = .visual
        visualAnchorIndex = anchorIndex
    }

    mutating func exitVisualMode() {
        enterNormalMode()
    }

    mutating func enterFilterMode() {
        mode = .filter
        visualAnchorIndex = nil
    }
}
