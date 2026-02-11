import Foundation

enum FilerTheme: String, Codable, CaseIterable, Sendable {
    case system
    case nord
    case dracula
    case solarized
    case tokyoNight
    case gruvbox
    case catppuccinLatte
    case mintLight

    var displayName: String {
        switch self {
        case .system: return "System"
        case .nord: return "Nord"
        case .dracula: return "Dracula"
        case .solarized: return "Solarized"
        case .tokyoNight: return "Tokyo Night"
        case .gruvbox: return "Gruvbox"
        case .catppuccinLatte: return "Catppuccin Latte"
        case .mintLight: return "Mint Light"
        }
    }

    var descriptionText: String {
        switch self {
        case .system:
            return "Use macOS-native accents and neutral highlights."
        case .nord:
            return "Cool blue-grey tones with low contrast for a calm workspace."
        case .dracula:
            return "Dark purple and magenta accents with a modern feel."
        case .solarized:
            return "Precision-crafted palette with light/dark mode support."
        case .tokyoNight:
            return "Neon blue and purple accents inspired by Tokyo city lights."
        case .gruvbox:
            return "Warm retro tones with strong amber and olive accents."
        case .catppuccinLatte:
            return "Soft pastel light palette with crisp blue accents."
        case .mintLight:
            return "Bright mint and teal colors for a clean daytime workspace."
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        self = FilerTheme(rawValue: rawValue) ?? .system
    }
}

enum SpotlightSearchScope: String, Codable, CaseIterable, Sendable {
    case currentDirectory
    case userHome
    case localComputer

    var displayName: String {
        switch self {
        case .currentDirectory:
            return "Current Folder"
        case .userHome:
            return "Home Folder"
        case .localComputer:
            return "Entire Mac"
        }
    }

    var descriptionText: String {
        switch self {
        case .currentDirectory:
            return "Search only within the current folder and its subfolders."
        case .userHome:
            return "Search within your home directory."
        case .localComputer:
            return "Search across all locally indexed volumes."
        }
    }
}

struct AppConfig: Codable, Sendable {
    enum SortColumn: String, Codable, CaseIterable, Sendable {
        case name
        case size
        case date
        case selection

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let rawValue = try container.decode(String.self)
            self = SortColumn(rawValue: rawValue) ?? .name
        }
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
    var transparentBackground: Bool
    var transparentBackgroundOpacity: Double
    var actionFeedbackEnabled: Bool
    var spotlightSearchScope: SpotlightSearchScope
    var fileIconSize: Double
    var imagePreviewRecursiveMode: Bool

    init(
        showHiddenFiles: Bool = true,
        defaultSortColumn: SortColumn = .name,
        defaultSortAscending: Bool = true,
        previewPaneVisible: Bool = false,
        sidebarVisible: Bool = true,
        lastLeftPanePath: String = UserPaths.homeDirectoryPath,
        lastRightPanePath: String = UserPaths.homeDirectoryPath,
        lastActivePane: String = "left",
        filerTheme: FilerTheme = .system,
        transparentBackground: Bool = false,
        transparentBackgroundOpacity: Double = 0.7,
        actionFeedbackEnabled: Bool = true,
        spotlightSearchScope: SpotlightSearchScope = .currentDirectory,
        fileIconSize: Double = 16,
        imagePreviewRecursiveMode: Bool = false
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
        self.transparentBackground = transparentBackground
        self.transparentBackgroundOpacity = transparentBackgroundOpacity
        self.actionFeedbackEnabled = actionFeedbackEnabled
        self.spotlightSearchScope = spotlightSearchScope
        self.fileIconSize = fileIconSize
        self.imagePreviewRecursiveMode = imagePreviewRecursiveMode
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
        case transparentBackground
        case transparentBackgroundOpacity
        case actionFeedbackEnabled
        case spotlightSearchScope
        case fileIconSize
        case imagePreviewRecursiveMode
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
        transparentBackground = try container.decodeIfPresent(Bool.self, forKey: .transparentBackground) ?? false
        transparentBackgroundOpacity = try container.decodeIfPresent(Double.self, forKey: .transparentBackgroundOpacity) ?? 0.7
        actionFeedbackEnabled = try container.decodeIfPresent(Bool.self, forKey: .actionFeedbackEnabled) ?? true
        spotlightSearchScope = try container.decodeIfPresent(SpotlightSearchScope.self, forKey: .spotlightSearchScope) ?? .currentDirectory
        fileIconSize = try container.decodeIfPresent(Double.self, forKey: .fileIconSize) ?? 16
        imagePreviewRecursiveMode = try container.decodeIfPresent(Bool.self, forKey: .imagePreviewRecursiveMode) ?? false
    }
}
