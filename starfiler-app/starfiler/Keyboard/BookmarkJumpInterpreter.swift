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
    private struct BookmarkJumpTarget: Sendable {
        let path: String
        let label: String
        let sequence: [String]
    }

    enum State: Equatable, Sendable {
        case idle
        case awaitingSelection(prefix: [String])
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

        let targets = bookmarkTargets()

        switch state {
        case .idle:
            if event.key == leaderKey {
                guard !targets.isEmpty else {
                    reset()
                    return .unhandled
                }

                state = .awaitingSelection(prefix: [])
                return pendingResult(for: [], targets: targets) ?? .unhandled
            }
            return .unhandled

        case .awaitingSelection(let prefix):
            if event.key == "Return", let target = firstExactTarget(for: prefix, in: targets) {
                reset()
                return .jumpTo(path: target.path)
            }

            let nextPrefix = prefix + [event.key]
            guard hasMatchingTarget(for: nextPrefix, in: targets) else {
                return pendingResult(for: prefix, targets: targets) ?? .unhandled
            }

            let hasDescendant = hasDescendantTarget(for: nextPrefix, in: targets)
            if !hasDescendant, let target = firstExactTarget(for: nextPrefix, in: targets) {
                reset()
                return .jumpTo(path: target.path)
            }

            state = .awaitingSelection(prefix: nextPrefix)
            return pendingResult(for: nextPrefix, targets: targets) ?? .unhandled
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
        let targets = bookmarkTargets()
        switch state {
        case .idle:
            return nil
        case .awaitingSelection(let prefix):
            return pendingResult(for: prefix, targets: targets)
        }
    }

    private func pendingResult(for prefix: [String], targets: [BookmarkJumpTarget]) -> BookmarkJumpResult? {
        let matchingTargets = matchingTargets(for: prefix, in: targets)
        guard !matchingTargets.isEmpty else {
            return nil
        }

        var candidates: [BookmarkJumpHintCandidate] = []
        if let exactTarget = matchingTargets.first(where: { $0.sequence.count == prefix.count }) {
            candidates.append(
                BookmarkJumpHintCandidate(key: "Enter", label: exactTarget.label)
            )
        }

        let descendantTargets = matchingTargets.filter { $0.sequence.count > prefix.count }
        let groupedByNextKey = Dictionary(grouping: descendantTargets) { $0.sequence[prefix.count] }
        for key in groupedByNextKey.keys.sorted() {
            guard let branchTargets = groupedByNextKey[key], !branchTargets.isEmpty else {
                continue
            }
            let label = candidateLabel(for: branchTargets, atDepth: prefix.count + 1)
            candidates.append(
                BookmarkJumpHintCandidate(key: BookmarkShortcut.displayToken(for: key), label: label)
            )
        }

        return .pending(
            hint: BookmarkJumpHint(
                title: title(for: prefix),
                candidates: candidates
            )
        )
    }

    private func title(for prefix: [String]) -> String {
        guard !prefix.isEmpty else {
            return "Bookmark key"
        }
        let pathText = prefix.map(BookmarkShortcut.displayToken(for:)).joined(separator: " ")
        return "Bookmark key (' \(pathText))"
    }

    private func candidateLabel(for branchTargets: [BookmarkJumpTarget], atDepth depth: Int) -> String {
        if let exactTarget = branchTargets.first(where: { $0.sequence.count == depth }) {
            return exactTarget.label
        }
        if branchTargets.count == 1, let only = branchTargets.first {
            return only.label
        }
        return "\(branchTargets.count) folders"
    }

    private func bookmarkTargets() -> [BookmarkJumpTarget] {
        var targets: [BookmarkJumpTarget] = []
        var seenSequences = Set<[String]>()

        for group in bookmarksConfig.groups {
            let groupTokens: [String]
            if group.isDefault {
                groupTokens = []
            } else {
                groupTokens = BookmarkShortcut.tokens(from: group.shortcutKey)
                if groupTokens.isEmpty {
                    continue
                }
            }

            for entry in group.entries {
                let entryTokens = BookmarkShortcut.tokens(from: entry.shortcutKey)
                guard !entryTokens.isEmpty else {
                    continue
                }

                let sequence = groupTokens + entryTokens
                guard seenSequences.insert(sequence).inserted else {
                    continue
                }

                targets.append(
                    BookmarkJumpTarget(
                        path: entry.path,
                        label: entry.displayName.isEmpty ? entry.path : entry.displayName,
                        sequence: sequence
                    )
                )
            }
        }

        return targets
    }

    private func matchingTargets(for prefix: [String], in targets: [BookmarkJumpTarget]) -> [BookmarkJumpTarget] {
        targets.filter { target in
            target.sequence.count >= prefix.count &&
                Array(target.sequence.prefix(prefix.count)) == prefix
        }
    }

    private func firstExactTarget(for prefix: [String], in targets: [BookmarkJumpTarget]) -> BookmarkJumpTarget? {
        matchingTargets(for: prefix, in: targets).first(where: { $0.sequence.count == prefix.count })
    }

    private func hasDescendantTarget(for prefix: [String], in targets: [BookmarkJumpTarget]) -> Bool {
        matchingTargets(for: prefix, in: targets).contains(where: { $0.sequence.count > prefix.count })
    }

    private func hasMatchingTarget(for prefix: [String], in targets: [BookmarkJumpTarget]) -> Bool {
        !matchingTargets(for: prefix, in: targets).isEmpty
    }
}
