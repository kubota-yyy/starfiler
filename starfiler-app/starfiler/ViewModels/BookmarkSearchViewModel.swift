import Foundation
import Observation

@MainActor
@Observable
final class BookmarkSearchViewModel {
    struct SearchResult: Hashable, Sendable {
        let groupName: String
        let displayName: String
        let path: String
        let shortcutHint: String?
    }

    private(set) var results: [SearchResult] = []
    private(set) var selectedIndex: Int = 0
    private var allItems: [SearchResult] = []

    func load(from config: BookmarksConfig, history: [VisitHistoryEntry]) {
        var items: [SearchResult] = []

        for group in config.groups {
            for entry in group.entries {
                let hint: String?
                if group.isDefault {
                    hint = entry.shortcutKey.map { "' \($0)" }
                } else if let groupKey = group.shortcutKey, let entryKey = entry.shortcutKey {
                    hint = "' \(groupKey) \(entryKey)"
                } else {
                    hint = nil
                }

                items.append(SearchResult(
                    groupName: group.name,
                    displayName: entry.displayName,
                    path: entry.path,
                    shortcutHint: hint
                ))
            }
        }

        let existingPaths = Set(items.map(\.path))
        for entry in history where !existingPaths.contains(entry.path) {
            items.append(SearchResult(
                groupName: "Recent",
                displayName: entry.displayName,
                path: entry.path,
                shortcutHint: nil
            ))
        }

        allItems = items
        results = items
        selectedIndex = 0
    }

    func updateQuery(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        guard !trimmed.isEmpty else {
            results = allItems
            selectedIndex = 0
            return
        }

        var prefixMatches: [SearchResult] = []
        var substringMatches: [SearchResult] = []

        for item in allItems {
            let nameMatch = item.displayName.lowercased()
            let pathMatch = item.path.lowercased()

            if nameMatch.hasPrefix(trimmed) || pathMatch.hasPrefix(trimmed) {
                prefixMatches.append(item)
            } else if nameMatch.contains(trimmed) || pathMatch.contains(trimmed) {
                substringMatches.append(item)
            }
        }

        results = prefixMatches + substringMatches
        selectedIndex = results.isEmpty ? 0 : 0
    }

    func moveSelectionUp() {
        guard !results.isEmpty else {
            return
        }
        selectedIndex = max(0, selectedIndex - 1)
    }

    func moveSelectionDown() {
        guard !results.isEmpty else {
            return
        }
        selectedIndex = min(results.count - 1, selectedIndex + 1)
    }

    var selectedEntry: SearchResult? {
        guard results.indices.contains(selectedIndex) else {
            return nil
        }
        return results[selectedIndex]
    }
}
