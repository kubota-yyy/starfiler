import Foundation
import Observation

@MainActor
@Observable
final class SidebarViewModel {
    enum SectionKind: Hashable, Sendable {
        case favorites
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
    }

    private(set) var sections: [SidebarSection] = []

    var onSectionsChanged: (([SidebarSection]) -> Void)?

    private let configManager: ConfigManager

    init(configManager: ConfigManager) {
        self.configManager = configManager
        reloadSections()
    }

    func reloadSections() {
        var result: [SidebarSection] = []

        let homePath = UserPaths.homeDirectoryPath
        let favorites: [SidebarEntry] = [
            SidebarEntry(displayName: "Home", path: homePath, iconName: "house"),
            SidebarEntry(displayName: "Desktop", path: homePath + "/Desktop", iconName: "menubar.dock.rectangle"),
            SidebarEntry(displayName: "Documents", path: homePath + "/Documents", iconName: "doc"),
            SidebarEntry(displayName: "Downloads", path: homePath + "/Downloads", iconName: "arrow.down.circle"),
            SidebarEntry(displayName: "Applications", path: "/Applications", iconName: "app"),
        ]
        result.append(SidebarSection(kind: .favorites, title: "Favorites", items: favorites))

        let bookmarksConfig = configManager.loadBookmarksConfig()
        for group in bookmarksConfig.groups {
            let entries = group.entries.map { entry in
                SidebarEntry(displayName: entry.displayName, path: entry.path, iconName: "folder")
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
}
