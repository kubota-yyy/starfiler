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
        let isCurrentPosition: Bool
        let isLatestPosition: Bool
        let timelinePosition: Int?

        init(
            displayName: String,
            path: String,
            iconName: String,
            shortcutHint: String? = nil,
            isCurrentPosition: Bool = false,
            isLatestPosition: Bool = false,
            timelinePosition: Int? = nil
        ) {
            self.displayName = displayName
            self.path = path
            self.iconName = iconName
            self.shortcutHint = shortcutHint
            self.isCurrentPosition = isCurrentPosition
            self.isLatestPosition = isLatestPosition
            self.timelinePosition = timelinePosition
        }
    }

    private(set) var sections: [SidebarSection] = []

    var onSectionsChanged: (([SidebarSection]) -> Void)?

    private let configManager: ConfigManager
    private let visitHistoryService: VisitHistoryService?
    private var navigationHistorySection: SidebarSection?

    init(configManager: ConfigManager, visitHistoryService: VisitHistoryService? = nil) {
        self.configManager = configManager
        self.visitHistoryService = visitHistoryService
        reloadSections()
    }

    func reloadSections() {
        var result: [SidebarSection] = []

        let appConfig = configManager.loadAppConfig()
        let bookmarksConfig = configManager.loadBookmarksConfig()

        if appConfig.sidebarFavoritesVisible {
            let defaultGroup = bookmarksConfig.groups.first(where: { $0.isDefault })
            let favoritesTitle = defaultGroup?.name ?? "Favorites"
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
            result.append(SidebarSection(kind: .favorites, title: favoritesTitle, items: favorites))
        }

        if let navigationHistorySection {
            result.append(navigationHistorySection)
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
            guard !entries.isEmpty else {
                continue
            }
            result.append(SidebarSection(kind: .bookmarkGroup(name: group.name), title: group.name, items: entries))
        }

        sections = result
        onSectionsChanged?(sections)
    }

    func updateNavigationHistory(
        backStack: [URL],
        currentURL: URL,
        forwardStack: [URL],
        paneSide: PaneSide
    ) {
        let reversedForward = Array(forwardStack.reversed())
        let allURLs = backStack + [currentURL] + reversedForward
        let currentIndex = backStack.count
        let latestIndex = allURLs.count - 1

        let chronologicalItems = allURLs.enumerated().map { index, url in
            let name = url.lastPathComponent.isEmpty ? url.path : url.lastPathComponent
            let isCurrent = index == currentIndex
            let icon: String
            if isCurrent {
                icon = "folder.fill"
            } else {
                icon = "folder"
            }
            return SidebarEntry(
                displayName: name,
                path: url.path,
                iconName: icon,
                isCurrentPosition: isCurrent,
                isLatestPosition: index == latestIndex,
                timelinePosition: index
            )
        }
        let items = Array(chronologicalItems.reversed())

        let title = paneSide == .left ? "History (Left)" : "History (Right)"
        navigationHistorySection = SidebarSection(kind: .recent, title: title, items: items)
        reloadSections()
    }

    func urlForEntry(_ entry: SidebarEntry) -> URL? {
        let resolvedPath = UserPaths.resolveBookmarkPath(entry.path)
        let url = URL(fileURLWithPath: resolvedPath).standardizedFileURL
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
