import Foundation

struct BookmarksConfig: Codable, Sendable {
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

    func migratingLegacyPaths(fileManager: FileManager = .default) -> (config: BookmarksConfig, didChange: Bool) {
        var migratedGroups = groups
        var didChange = false

        for groupIndex in migratedGroups.indices {
            for entryIndex in migratedGroups[groupIndex].entries.indices {
                let entry = migratedGroups[groupIndex].entries[entryIndex]
                let resolvedPath = UserPaths.resolveBookmarkPath(entry.path, fileManager: fileManager)
                guard resolvedPath != entry.path else {
                    continue
                }
                migratedGroups[groupIndex].entries[entryIndex].path = resolvedPath
                didChange = true
            }
        }

        return (BookmarksConfig(groups: migratedGroups), didChange)
    }

    static func withDefaults() -> BookmarksConfig {
        let homePath = UserPaths.homeDirectoryPath
        let defaultGroup = BookmarkGroup(
            name: "Default",
            entries: [
                BookmarkEntry(displayName: "Home", path: homePath, shortcutKey: "h"),
                BookmarkEntry(displayName: "Desktop", path: homePath + "/Desktop", shortcutKey: "d"),
                BookmarkEntry(displayName: "Documents", path: homePath + "/Documents", shortcutKey: "o"),
                BookmarkEntry(displayName: "Downloads", path: homePath + "/Downloads", shortcutKey: "w"),
                BookmarkEntry(displayName: "Applications", path: "/Applications", shortcutKey: "a"),
            ],
            shortcutKey: nil,
            isDefault: true
        )
        return BookmarksConfig(groups: [defaultGroup])
    }
}
