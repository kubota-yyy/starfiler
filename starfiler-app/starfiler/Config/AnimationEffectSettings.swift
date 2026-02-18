import Foundation

struct AnimationEffectSettings: Codable, Sendable, Equatable {
    var directoryTransitionSlide: Bool
    var markSparkle: Bool
    var bookmarkJumpAnimation: Bool
    var activePanePulse: Bool
    var statusBarCountAnimation: Bool
    var windowIntroAnimation: Bool
    var previewCrossfade: Bool
    var cursorRipple: Bool
    var filterBarGlow: Bool
    var markCascade: Bool
    var dropZonePulse: Bool
    var visualModeWave: Bool
    var sortRowAnimation: Bool

    init(
        directoryTransitionSlide: Bool = true,
        markSparkle: Bool = true,
        bookmarkJumpAnimation: Bool = true,
        activePanePulse: Bool = true,
        statusBarCountAnimation: Bool = true,
        windowIntroAnimation: Bool = true,
        previewCrossfade: Bool = true,
        cursorRipple: Bool = true,
        filterBarGlow: Bool = true,
        markCascade: Bool = true,
        dropZonePulse: Bool = true,
        visualModeWave: Bool = true,
        sortRowAnimation: Bool = true
    ) {
        self.directoryTransitionSlide = directoryTransitionSlide
        self.markSparkle = markSparkle
        self.bookmarkJumpAnimation = bookmarkJumpAnimation
        self.activePanePulse = activePanePulse
        self.statusBarCountAnimation = statusBarCountAnimation
        self.windowIntroAnimation = windowIntroAnimation
        self.previewCrossfade = previewCrossfade
        self.cursorRipple = cursorRipple
        self.filterBarGlow = filterBarGlow
        self.markCascade = markCascade
        self.dropZonePulse = dropZonePulse
        self.visualModeWave = visualModeWave
        self.sortRowAnimation = sortRowAnimation
    }

    static let allEnabled = AnimationEffectSettings()
    static let allDisabled = AnimationEffectSettings(
        directoryTransitionSlide: false,
        markSparkle: false,
        bookmarkJumpAnimation: false,
        activePanePulse: false,
        statusBarCountAnimation: false,
        windowIntroAnimation: false,
        previewCrossfade: false,
        cursorRipple: false,
        filterBarGlow: false,
        markCascade: false,
        dropZonePulse: false,
        visualModeWave: false,
        sortRowAnimation: false
    )

    enum EffectKind: String, CaseIterable, Sendable {
        case directoryTransitionSlide
        case markSparkle
        case bookmarkJumpAnimation
        case activePanePulse
        case statusBarCountAnimation
        case windowIntroAnimation
        case previewCrossfade
        case cursorRipple
        case filterBarGlow
        case markCascade
        case dropZonePulse
        case visualModeWave
        case sortRowAnimation

        var displayName: String {
            switch self {
            case .directoryTransitionSlide: return "Directory Transition Slide"
            case .markSparkle: return "Mark Sparkle"
            case .bookmarkJumpAnimation: return "Bookmark Jump Animation"
            case .activePanePulse: return "Active Pane Pulse"
            case .statusBarCountAnimation: return "Status Bar Count Animation"
            case .windowIntroAnimation: return "Window Intro Animation"
            case .previewCrossfade: return "Preview Crossfade"
            case .cursorRipple: return "Cursor Ripple"
            case .filterBarGlow: return "Filter Bar Glow"
            case .markCascade: return "Mark All Cascade"
            case .dropZonePulse: return "Drop Zone Pulse"
            case .visualModeWave: return "Visual Mode Wave"
            case .sortRowAnimation: return "Sort Row Animation"
            }
        }
    }

    subscript(kind: EffectKind) -> Bool {
        get {
            switch kind {
            case .directoryTransitionSlide: return directoryTransitionSlide
            case .markSparkle: return markSparkle
            case .bookmarkJumpAnimation: return bookmarkJumpAnimation
            case .activePanePulse: return activePanePulse
            case .statusBarCountAnimation: return statusBarCountAnimation
            case .windowIntroAnimation: return windowIntroAnimation
            case .previewCrossfade: return previewCrossfade
            case .cursorRipple: return cursorRipple
            case .filterBarGlow: return filterBarGlow
            case .markCascade: return markCascade
            case .dropZonePulse: return dropZonePulse
            case .visualModeWave: return visualModeWave
            case .sortRowAnimation: return sortRowAnimation
            }
        }
        set {
            switch kind {
            case .directoryTransitionSlide: directoryTransitionSlide = newValue
            case .markSparkle: markSparkle = newValue
            case .bookmarkJumpAnimation: bookmarkJumpAnimation = newValue
            case .activePanePulse: activePanePulse = newValue
            case .statusBarCountAnimation: statusBarCountAnimation = newValue
            case .windowIntroAnimation: windowIntroAnimation = newValue
            case .previewCrossfade: previewCrossfade = newValue
            case .cursorRipple: cursorRipple = newValue
            case .filterBarGlow: filterBarGlow = newValue
            case .markCascade: markCascade = newValue
            case .dropZonePulse: dropZonePulse = newValue
            case .visualModeWave: visualModeWave = newValue
            case .sortRowAnimation: sortRowAnimation = newValue
            }
        }
    }
}
