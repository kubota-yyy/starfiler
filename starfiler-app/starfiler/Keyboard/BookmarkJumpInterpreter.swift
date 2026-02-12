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
    private(set) var state: State = .idle

    init(bookmarksConfig: BookmarksConfig) {
        self.bookmarksConfig = bookmarksConfig
    }

    mutating func interpret(_ event: KeyEvent, now: Date = Date()) -> BookmarkJumpResult {
        _ = now
        if !event.modifiers.isEmpty {
            return currentPendingResult() ?? .unhandled
        }

        switch state {
        case .idle:
            if event.key == leaderKey {
                let projectCandidates = keyedProjectCandidates()
                guard !projectCandidates.isEmpty else {
                    reset()
                    return .unhandled
                }

                state = .awaitingTarget
                return .pending(
                    hint: BookmarkJumpHint(title: "Project key", candidates: projectCandidates)
                )
            }
            return .unhandled

        case .awaitingTarget:
            let key = event.key

            for (index, group) in bookmarksConfig.groups.enumerated() where !group.isDefault {
                guard !keyedEntryCandidates(in: group).isEmpty else {
                    continue
                }
                if normalizeShortcut(group.shortcutKey) == key {
                    let entryCandidates = keyedEntryCandidates(in: group)
                    state = .awaitingProjectEntry(groupIndex: index)
                    return .pending(
                        hint: BookmarkJumpHint(
                            title: "Folder key (\(group.name))",
                            candidates: entryCandidates
                        )
                    )
                }
            }

            return .pending(hint: BookmarkJumpHint(title: "Project key", candidates: keyedProjectCandidates()))

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

            return .pending(
                hint: BookmarkJumpHint(
                    title: "Folder key (\(group.name))",
                    candidates: keyedEntryCandidates(in: group)
                )
            )
        }
    }

    mutating func updateConfig(_ config: BookmarksConfig) {
        bookmarksConfig = config
        reset()
    }

    mutating func reset() {
        state = .idle
    }

    private func currentPendingResult() -> BookmarkJumpResult? {
        switch state {
        case .idle:
            return nil
        case .awaitingTarget:
            return .pending(
                hint: BookmarkJumpHint(
                    title: "Project key",
                    candidates: keyedProjectCandidates()
                )
            )
        case .awaitingProjectEntry(let groupIndex):
            guard bookmarksConfig.groups.indices.contains(groupIndex) else {
                return nil
            }
            let group = bookmarksConfig.groups[groupIndex]
            return .pending(
                hint: BookmarkJumpHint(
                    title: "Folder key (\(group.name))",
                    candidates: keyedEntryCandidates(in: group)
                )
            )
        }
    }

    private func keyedProjectCandidates() -> [BookmarkJumpHintCandidate] {
        bookmarksConfig.groups.compactMap { group in
            guard !group.isDefault, let key = normalizeShortcut(group.shortcutKey) else {
                return nil
            }
            guard !keyedEntryCandidates(in: group).isEmpty else {
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
