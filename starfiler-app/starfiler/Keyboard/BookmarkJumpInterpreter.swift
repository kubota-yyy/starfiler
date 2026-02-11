import Foundation

enum BookmarkJumpResult: Equatable, Sendable {
    case jumpTo(path: String)
    case pending(hint: String)
    case unhandled
}

struct BookmarkJumpInterpreter: Sendable {
    enum State: Equatable, Sendable {
        case idle
        case awaitingTarget
        case awaitingProjectEntry(groupIndex: Int)
    }

    private let leaderKey: String = "'"
    private var bookmarksConfig: BookmarksConfig
    private let timeout: TimeInterval = 0.8
    private(set) var state: State = .idle
    private var lastInputDate: Date?

    init(bookmarksConfig: BookmarksConfig) {
        self.bookmarksConfig = bookmarksConfig
    }

    mutating func interpret(_ event: KeyEvent, now: Date = Date()) -> BookmarkJumpResult {
        if !event.modifiers.isEmpty {
            reset()
            return .unhandled
        }

        expireIfNeeded(now: now)

        switch state {
        case .idle:
            if event.key == leaderKey {
                state = .awaitingTarget
                lastInputDate = now
                return .pending(hint: "' ...")
            }
            return .unhandled

        case .awaitingTarget:
            let key = event.key

            if let defaultGroup = bookmarksConfig.groups.first(where: { $0.isDefault }) {
                if let entry = defaultGroup.entries.first(where: { $0.shortcutKey == key }) {
                    reset()
                    return .jumpTo(path: entry.path)
                }
            }

            for (index, group) in bookmarksConfig.groups.enumerated() where !group.isDefault {
                if group.shortcutKey == key {
                    state = .awaitingProjectEntry(groupIndex: index)
                    lastInputDate = now
                    return .pending(hint: "' \(key) ...")
                }
            }

            reset()
            return .unhandled

        case .awaitingProjectEntry(let groupIndex):
            guard bookmarksConfig.groups.indices.contains(groupIndex) else {
                reset()
                return .unhandled
            }

            let group = bookmarksConfig.groups[groupIndex]
            let key = event.key

            if let entry = group.entries.first(where: { $0.shortcutKey == key }) {
                reset()
                return .jumpTo(path: entry.path)
            }

            reset()
            return .unhandled
        }
    }

    mutating func updateConfig(_ config: BookmarksConfig) {
        bookmarksConfig = config
        reset()
    }

    mutating func reset() {
        state = .idle
        lastInputDate = nil
    }

    private mutating func expireIfNeeded(now: Date) {
        guard let lastInputDate, now.timeIntervalSince(lastInputDate) >= timeout else {
            return
        }
        reset()
    }
}
