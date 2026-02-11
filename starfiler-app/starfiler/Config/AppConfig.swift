import Foundation

enum FilerTheme: String, Codable, CaseIterable, Sendable {
    case system
    case ocean
    case forest
    case sunset

    var displayName: String {
        switch self {
        case .system:
            return "System"
        case .ocean:
            return "Ocean"
        case .forest:
            return "Forest"
        case .sunset:
            return "Sunset"
        }
    }

    var descriptionText: String {
        switch self {
        case .system:
            return "Use macOS-native accents and neutral highlights."
        case .ocean:
            return "Cool blue accents with crisp selection highlights."
        case .forest:
            return "Green-toned accents for a calm workspace."
        case .sunset:
            return "Warm orange accents with strong visual focus."
        }
    }
}

struct AppConfig: Codable, Sendable {
    enum SortColumn: String, Codable, CaseIterable, Sendable {
        case name
        case size
        case date
    }

    var showHiddenFiles: Bool
    var defaultSortColumn: SortColumn
    var defaultSortAscending: Bool
    var previewPaneVisible: Bool
    var sidebarVisible: Bool
    var lastLeftPanePath: String
    var lastRightPanePath: String
    var lastActivePane: String
    var filerTheme: FilerTheme

    init(
        showHiddenFiles: Bool = true,
        defaultSortColumn: SortColumn = .name,
        defaultSortAscending: Bool = true,
        previewPaneVisible: Bool = false,
        sidebarVisible: Bool = true,
        lastLeftPanePath: String = UserPaths.homeDirectoryPath,
        lastRightPanePath: String = UserPaths.homeDirectoryPath,
        lastActivePane: String = "left",
        filerTheme: FilerTheme = .system
    ) {
        self.showHiddenFiles = showHiddenFiles
        self.defaultSortColumn = defaultSortColumn
        self.defaultSortAscending = defaultSortAscending
        self.previewPaneVisible = previewPaneVisible
        self.sidebarVisible = sidebarVisible
        self.lastLeftPanePath = lastLeftPanePath
        self.lastRightPanePath = lastRightPanePath
        self.lastActivePane = lastActivePane
        self.filerTheme = filerTheme
    }

    enum CodingKeys: String, CodingKey {
        case showHiddenFiles
        case defaultSortColumn
        case defaultSortAscending
        case previewPaneVisible
        case sidebarVisible
        case lastLeftPanePath
        case lastRightPanePath
        case lastActivePane
        case filerTheme
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        showHiddenFiles = try container.decodeIfPresent(Bool.self, forKey: .showHiddenFiles) ?? true
        defaultSortColumn = try container.decodeIfPresent(SortColumn.self, forKey: .defaultSortColumn) ?? .name
        defaultSortAscending = try container.decodeIfPresent(Bool.self, forKey: .defaultSortAscending) ?? true
        previewPaneVisible = try container.decodeIfPresent(Bool.self, forKey: .previewPaneVisible) ?? false
        sidebarVisible = try container.decodeIfPresent(Bool.self, forKey: .sidebarVisible) ?? true
        lastLeftPanePath = try container.decodeIfPresent(String.self, forKey: .lastLeftPanePath) ?? UserPaths.homeDirectoryPath
        lastRightPanePath = try container.decodeIfPresent(String.self, forKey: .lastRightPanePath) ?? UserPaths.homeDirectoryPath
        lastActivePane = try container.decodeIfPresent(String.self, forKey: .lastActivePane) ?? "left"
        filerTheme = try container.decodeIfPresent(FilerTheme.self, forKey: .filerTheme) ?? .system
    }
}
