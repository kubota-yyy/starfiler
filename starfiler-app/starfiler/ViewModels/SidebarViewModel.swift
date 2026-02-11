import Foundation
import Observation

@MainActor
@Observable
final class SidebarViewModel {
    enum SectionKind: Hashable, Sendable {
        case favorites
        case recent
        case bookmarkGroup(name: String)
    }

    struct SidebarSection: Hashable, Sendable {
        let kind: SectionKind
        let title: String
        let items: [SidebarEntry]
    }

    struct SidebarEntry: Hashable, Sendable {
        let displayName: String
        let path: String
        let iconName: String
        let shortcutHint: String?

        init(displayName: String, path: String, iconName: String, shortcutHint: String? = nil) {
            self.displayName = displayName
            self.path = path
            self.iconName = iconName
            self.shortcutHint = shortcutHint
        }
    }

    private(set) var sections: [SidebarSection] = []

    var onSectionsChanged: (([SidebarSection]) -> Void)?

    private let configManager: ConfigManager
    private let visitHistoryService: VisitHistoryService?

    init(configManager: ConfigManager, visitHistoryService: VisitHistoryService? = nil) {
        self.configManager = configManager
        self.visitHistoryService = visitHistoryService
        reloadSections()
    }

    func reloadSections() {
        var result: [SidebarSection] = []

        let bookmarksConfig = configManager.loadBookmarksConfig()

        let defaultGroup = bookmarksConfig.groups.first(where: { $0.isDefault })
        let favorites: [SidebarEntry]
        if let defaultGroup {
            favorites = defaultGroup.entries.map { entry in
                let hint = entry.shortcutKey.map { "' \($0)" }
                return SidebarEntry(
                    displayName: entry.displayName,
                    path: entry.path,
                    iconName: iconName(for: entry.displayName),
                    shortcutHint: hint
                )
            }
        } else {
            let homePath = UserPaths.homeDirectoryPath
            favorites = [
                SidebarEntry(displayName: "Home", path: homePath, iconName: "house"),
                SidebarEntry(displayName: "Desktop", path: homePath + "/Desktop", iconName: "menubar.dock.rectangle"),
                SidebarEntry(displayName: "Documents", path: homePath + "/Documents", iconName: "doc"),
                SidebarEntry(displayName: "Downloads", path: homePath + "/Downloads", iconName: "arrow.down.circle"),
                SidebarEntry(displayName: "Applications", path: "/Applications", iconName: "app"),
            ]
        }
        result.append(SidebarSection(kind: .favorites, title: "Favorites", items: favorites))

        if let visitHistoryService {
            let recentEntries = visitHistoryService.recentEntries(limit: 10)
            if !recentEntries.isEmpty {
                let recentItems = recentEntries.map { entry in
                    SidebarEntry(
                        displayName: entry.displayName,
                        path: entry.path,
                        iconName: "clock"
                    )
                }
                result.append(SidebarSection(kind: .recent, title: "Recent", items: recentItems))
            }
        }

        for group in bookmarksConfig.groups where !group.isDefault {
            let entries = group.entries.map { entry in
                let hint: String?
                if let groupKey = group.shortcutKey, let entryKey = entry.shortcutKey {
                    hint = "' \(groupKey) \(entryKey)"
                } else {
                    hint = nil
                }
                return SidebarEntry(
                    displayName: entry.displayName,
                    path: entry.path,
                    iconName: "folder",
                    shortcutHint: hint
                )
            }
            result.append(SidebarSection(kind: .bookmarkGroup(name: group.name), title: group.name, items: entries))
        }

        sections = result
        onSectionsChanged?(sections)
    }

    func urlForEntry(_ entry: SidebarEntry) -> URL? {
        let url = URL(fileURLWithPath: entry.path).standardizedFileURL
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            return nil
        }
        return isDirectory.boolValue ? url : url.deletingLastPathComponent().standardizedFileURL
    }

    func removeBookmarkEntry(_ entry: SidebarEntry, fromGroup groupName: String) {
        var bookmarksConfig = configManager.loadBookmarksConfig()
        guard let groupIndex = bookmarksConfig.groups.firstIndex(where: { $0.name == groupName }) else {
            return
        }
        bookmarksConfig.groups[groupIndex].entries.removeAll { $0.path == entry.path }
        if bookmarksConfig.groups[groupIndex].entries.isEmpty {
            bookmarksConfig.groups.remove(at: groupIndex)
        }
        try? configManager.saveBookmarksConfig(bookmarksConfig)
        reloadSections()
    }

    private func iconName(for displayName: String) -> String {
        switch displayName.lowercased() {
        case "home":
            return "house"
        case "desktop":
            return "menubar.dock.rectangle"
        case "documents":
            return "doc"
        case "downloads":
            return "arrow.down.circle"
        case "applications":
            return "app"
        default:
            return "folder"
        }
    }
}
