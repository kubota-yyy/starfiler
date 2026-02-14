import Foundation

struct BookmarksConfig: Codable, Sendable {
    struct ShortcutBinding: Equatable, Sendable {
        let groupName: String
        let entryDisplayName: String
        let path: String

        var entryLabel: String {
            entryDisplayName.isEmpty ? path : entryDisplayName
        }
    }

    struct ShortcutConflict: Equatable, Sendable {
        let sequence: [String]
        let existing: ShortcutBinding
        let incoming: ShortcutBinding

        var sequenceDisplayText: String {
            sequence.map(BookmarkShortcut.displayToken(for:)).joined(separator: " ")
        }
    }

    var groups: [BookmarkGroup]

    init(groups: [BookmarkGroup] = []) {
        self.groups = groups
    }

    static func load(from url: URL, fileManager: FileManager = .default) throws -> BookmarksConfig {
        guard fileManager.fileExists(atPath: url.path) else {
            return BookmarksConfig()
        }

        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(BookmarksConfig.self, from: data)
    }

    func save(to url: URL, fileManager: FileManager = .default) throws {
        let parentDirectory = url.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: parentDirectory.path) {
            try fileManager.createDirectory(at: parentDirectory, withIntermediateDirectories: true)
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(self)
        try data.write(to: url, options: [.atomic])
    }

    func normalizedForStorage(fileManager: FileManager = .default) -> BookmarksConfig {
        var normalizedGroups = groups
        for groupIndex in normalizedGroups.indices {
            for entryIndex in normalizedGroups[groupIndex].entries.indices {
                let path = normalizedGroups[groupIndex].entries[entryIndex].path
                normalizedGroups[groupIndex].entries[entryIndex].path = UserPaths.portableBookmarkPath(path, fileManager: fileManager)
            }
        }
        return BookmarksConfig(groups: normalizedGroups)
    }

    func migratingLegacyPaths(fileManager: FileManager = .default) -> (config: BookmarksConfig, didChange: Bool) {
        let normalizedConfig = normalizedForStorage(fileManager: fileManager)
        return (normalizedConfig, normalizedConfig.groups != groups)
    }

    func firstShortcutConflict() -> ShortcutConflict? {
        var seenBindingsBySequence: [[String]: ShortcutBinding] = [:]

        for group in groups {
            let groupTokens: [String]
            if group.isDefault {
                groupTokens = []
            } else {
                groupTokens = BookmarkShortcut.tokens(from: group.shortcutKey)
                guard !groupTokens.isEmpty else {
                    continue
                }
            }

            for entry in group.entries {
                let entryTokens = BookmarkShortcut.tokens(from: entry.shortcutKey)
                guard !entryTokens.isEmpty else {
                    continue
                }

                let sequence = groupTokens + entryTokens
                let binding = ShortcutBinding(
                    groupName: group.name,
                    entryDisplayName: entry.displayName,
                    path: entry.path
                )

                if let existing = seenBindingsBySequence[sequence] {
                    return ShortcutConflict(
                        sequence: sequence,
                        existing: existing,
                        incoming: binding
                    )
                }

                seenBindingsBySequence[sequence] = binding
            }
        }

        return nil
    }

    static func withDefaults() -> BookmarksConfig {
        let defaultGroup = BookmarkGroup(
            name: "Default",
            entries: [
                BookmarkEntry(displayName: "Home", path: "~", shortcutKey: "h"),
                BookmarkEntry(displayName: "Desktop", path: "~/Desktop", shortcutKey: "d"),
                BookmarkEntry(displayName: "Documents", path: "~/Documents", shortcutKey: "o"),
                BookmarkEntry(displayName: "Downloads", path: "~/Downloads", shortcutKey: "w"),
                BookmarkEntry(displayName: "Applications", path: "/Applications", shortcutKey: "a"),
            ],
            shortcutKey: nil,
            isDefault: true
        )
        return BookmarksConfig(groups: [defaultGroup])
    }
}
