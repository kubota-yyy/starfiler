import Foundation

enum BookmarkJumpResult: Equatable, Sendable {
    case jumpTo(path: String)
    case pending(hint: BookmarkJumpHint)
    case unhandled
}

struct BookmarkJumpHint: Equatable, Sendable {
    let title: String
    let candidates: [BookmarkJumpHintCandidate]

    var statusText: String {
        let pairs = candidates.map { "\($0.key):\($0.label)" }.joined(separator: "  ")
        guard !pairs.isEmpty else {
            return title
        }
        return "\(title) \(pairs)"
    }
}

struct BookmarkJumpHintCandidate: Equatable, Sendable {
    let key: String
    let label: String
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
                let projectCandidates = keyedProjectCandidates()
                guard !projectCandidates.isEmpty else {
                    reset()
                    return .unhandled
                }

                state = .awaitingTarget
                lastInputDate = now
                return .pending(
                    hint: BookmarkJumpHint(title: "Project key", candidates: projectCandidates)
                )
            }
            return .unhandled

        case .awaitingTarget:
            let key = event.key

            for (index, group) in bookmarksConfig.groups.enumerated() where !group.isDefault {
                if normalizeShortcut(group.shortcutKey) == key {
                    let entryCandidates = keyedEntryCandidates(in: group)
                    guard !entryCandidates.isEmpty else {
                        reset()
                        return .unhandled
                    }

                    state = .awaitingProjectEntry(groupIndex: index)
                    lastInputDate = now
                    return .pending(
                        hint: BookmarkJumpHint(
                            title: "Folder key (\(group.name))",
                            candidates: entryCandidates
                        )
                    )
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

            if let entry = group.entries.first(where: { normalizeShortcut($0.shortcutKey) == key }) {
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

    private func keyedProjectCandidates() -> [BookmarkJumpHintCandidate] {
        bookmarksConfig.groups.compactMap { group in
            guard !group.isDefault, let key = normalizeShortcut(group.shortcutKey) else {
                return nil
            }
            return BookmarkJumpHintCandidate(key: key, label: group.name)
        }
    }

    private func keyedEntryCandidates(in group: BookmarkGroup) -> [BookmarkJumpHintCandidate] {
        group.entries.compactMap { entry in
            guard let key = normalizeShortcut(entry.shortcutKey) else {
                return nil
            }
            let label = entry.displayName.isEmpty ? entry.path : entry.displayName
            return BookmarkJumpHintCandidate(key: key, label: label)
        }
    }

    private func normalizeShortcut(_ shortcut: String?) -> String? {
        guard let shortcut else {
            return nil
        }
        let trimmed = shortcut.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }
        return String(trimmed.prefix(1)).lowercased()
    }
}
