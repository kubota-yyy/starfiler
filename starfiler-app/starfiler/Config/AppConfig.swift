import Foundation

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

    init(
        showHiddenFiles: Bool = false,
        defaultSortColumn: SortColumn = .name,
        defaultSortAscending: Bool = true,
        previewPaneVisible: Bool = false,
        sidebarVisible: Bool = true,
        lastLeftPanePath: String = UserPaths.homeDirectoryPath,
        lastRightPanePath: String = UserPaths.homeDirectoryPath,
        lastActivePane: String = "left"
    ) {
        self.showHiddenFiles = showHiddenFiles
        self.defaultSortColumn = defaultSortColumn
        self.defaultSortAscending = defaultSortAscending
        self.previewPaneVisible = previewPaneVisible
        self.sidebarVisible = sidebarVisible
        self.lastLeftPanePath = lastLeftPanePath
        self.lastRightPanePath = lastRightPanePath
        self.lastActivePane = lastActivePane
    }
}
