import AppKit

struct FilerThemePalette {
    let activeBorderColor: NSColor
    let inactiveBorderColor: NSColor
    let dropTargetBorderColor: NSColor
    let activeHeaderColor: NSColor
    let inactiveHeaderColor: NSColor
    let activePathTextColor: NSColor
    let inactivePathTextColor: NSColor
    let markedColor: NSColor
    let visualMarkedColor: NSColor
    let activePaneAlpha: CGFloat
    let inactivePaneAlpha: CGFloat
    let sidebarSectionHeaderColor: NSColor
    let sidebarEntryTextColor: NSColor
    let sidebarIconTintColor: NSColor
    let sidebarShortcutHintColor: NSColor
    let statusBarBackgroundColor: NSColor
    let statusBarTextColor: NSColor
    let filterBarPromptColor: NSColor
    let filterBarTextColor: NSColor
    let previewBorderColor: NSColor
    let accentColor: NSColor
    let windowBackgroundColor: NSColor
    let paneBackgroundColor: NSColor
    let tableBackgroundColor: NSColor
    let sidebarBackgroundColor: NSColor
    let filterBarBackgroundColor: NSColor
    let filterBarBorderColor: NSColor
    let previewBackgroundColor: NSColor
    let primaryTextColor: NSColor
    let secondaryTextColor: NSColor

    init(
        activeBorderColor: NSColor,
        inactiveBorderColor: NSColor,
        dropTargetBorderColor: NSColor,
        activeHeaderColor: NSColor,
        inactiveHeaderColor: NSColor,
        activePathTextColor: NSColor,
        inactivePathTextColor: NSColor,
        markedColor: NSColor,
        visualMarkedColor: NSColor,
        activePaneAlpha: CGFloat,
        inactivePaneAlpha: CGFloat,
        sidebarSectionHeaderColor: NSColor,
        sidebarEntryTextColor: NSColor,
        sidebarIconTintColor: NSColor,
        sidebarShortcutHintColor: NSColor,
        statusBarBackgroundColor: NSColor,
        statusBarTextColor: NSColor,
        filterBarPromptColor: NSColor,
        filterBarTextColor: NSColor,
        previewBorderColor: NSColor,
        accentColor: NSColor,
        windowBackgroundColor: NSColor = .windowBackgroundColor,
        paneBackgroundColor: NSColor = .textBackgroundColor,
        tableBackgroundColor: NSColor = .textBackgroundColor,
        sidebarBackgroundColor: NSColor = .windowBackgroundColor,
        filterBarBackgroundColor: NSColor = NSColor.controlBackgroundColor.withAlphaComponent(0.72),
        filterBarBorderColor: NSColor = NSColor.separatorColor.withAlphaComponent(0.45),
        previewBackgroundColor: NSColor = .textBackgroundColor,
        primaryTextColor: NSColor = .labelColor,
        secondaryTextColor: NSColor = .secondaryLabelColor
    ) {
        self.activeBorderColor = activeBorderColor
        self.inactiveBorderColor = inactiveBorderColor
        self.dropTargetBorderColor = dropTargetBorderColor
        self.activeHeaderColor = activeHeaderColor
        self.inactiveHeaderColor = inactiveHeaderColor
        self.activePathTextColor = activePathTextColor
        self.inactivePathTextColor = inactivePathTextColor
        self.markedColor = markedColor
        self.visualMarkedColor = visualMarkedColor
        self.activePaneAlpha = activePaneAlpha
        self.inactivePaneAlpha = inactivePaneAlpha
        self.sidebarSectionHeaderColor = sidebarSectionHeaderColor
        self.sidebarEntryTextColor = sidebarEntryTextColor
        self.sidebarIconTintColor = sidebarIconTintColor
        self.sidebarShortcutHintColor = sidebarShortcutHintColor
        self.statusBarBackgroundColor = statusBarBackgroundColor
        self.statusBarTextColor = statusBarTextColor
        self.filterBarPromptColor = filterBarPromptColor
        self.filterBarTextColor = filterBarTextColor
        self.previewBorderColor = previewBorderColor
        self.accentColor = accentColor
        self.windowBackgroundColor = windowBackgroundColor
        self.paneBackgroundColor = paneBackgroundColor
        self.tableBackgroundColor = tableBackgroundColor
        self.sidebarBackgroundColor = sidebarBackgroundColor
        self.filterBarBackgroundColor = filterBarBackgroundColor
        self.filterBarBorderColor = filterBarBorderColor
        self.previewBackgroundColor = previewBackgroundColor
        self.primaryTextColor = primaryTextColor
        self.secondaryTextColor = secondaryTextColor
    }
}

extension FilerTheme {
    static func dynamicColor(light: NSColor, dark: NSColor) -> NSColor {
        NSColor(name: nil) { appearance in
            let bestMatch = appearance.bestMatch(from: [.aqua, .darkAqua])
            return bestMatch == .darkAqua ? dark : light
        }
    }

    var palette: FilerThemePalette {
        switch self {
        case .system:
            return FilerThemePalette(
                activeBorderColor: .controlAccentColor,
                inactiveBorderColor: .separatorColor,
                dropTargetBorderColor: .systemBlue,
                activeHeaderColor: NSColor.controlAccentColor.withAlphaComponent(0.16),
                inactiveHeaderColor: NSColor.quaternaryLabelColor.withAlphaComponent(0.1),
                activePathTextColor: .labelColor,
                inactivePathTextColor: .secondaryLabelColor,
                markedColor: NSColor.systemOrange.withAlphaComponent(0.14),
                visualMarkedColor: NSColor.controlAccentColor.withAlphaComponent(0.22),
                activePaneAlpha: 1.0,
                inactivePaneAlpha: 0.86,
                sidebarSectionHeaderColor: .secondaryLabelColor,
                sidebarEntryTextColor: .labelColor,
                sidebarIconTintColor: .controlAccentColor,
                sidebarShortcutHintColor: .tertiaryLabelColor,
                statusBarBackgroundColor: .windowBackgroundColor,
                statusBarTextColor: .secondaryLabelColor,
                filterBarPromptColor: .labelColor,
                filterBarTextColor: .labelColor,
                previewBorderColor: NSColor.separatorColor.withAlphaComponent(0.6),
                accentColor: .controlAccentColor,
                windowBackgroundColor: .windowBackgroundColor,
                paneBackgroundColor: .textBackgroundColor,
                tableBackgroundColor: .textBackgroundColor,
                sidebarBackgroundColor: .underPageBackgroundColor,
                filterBarBackgroundColor: NSColor.controlBackgroundColor.withAlphaComponent(0.76),
                filterBarBorderColor: NSColor.separatorColor.withAlphaComponent(0.4),
                previewBackgroundColor: .textBackgroundColor,
                primaryTextColor: .labelColor,
                secondaryTextColor: .secondaryLabelColor
            )
        case .nord:
            let nordBg = Self.dynamicColor(
                light: NSColor(calibratedRed: 0.93, green: 0.94, blue: 0.96, alpha: 1.0),
                dark: NSColor(calibratedRed: 0.18, green: 0.20, blue: 0.25, alpha: 1.0)
            )
            let nordAccent = Self.dynamicColor(
                light: NSColor(calibratedRed: 0.53, green: 0.75, blue: 0.82, alpha: 1.0),
                dark: NSColor(calibratedRed: 0.53, green: 0.75, blue: 0.82, alpha: 1.0)
            )
            let nordFrost2 = Self.dynamicColor(
                light: NSColor(calibratedRed: 0.51, green: 0.63, blue: 0.76, alpha: 1.0),
                dark: NSColor(calibratedRed: 0.51, green: 0.63, blue: 0.76, alpha: 1.0)
            )
            return FilerThemePalette(
                activeBorderColor: nordAccent,
                inactiveBorderColor: Self.dynamicColor(
                    light: NSColor(calibratedRed: 0.82, green: 0.84, blue: 0.87, alpha: 1.0),
                    dark: NSColor(calibratedRed: 0.26, green: 0.30, blue: 0.37, alpha: 1.0)
                ),
                dropTargetBorderColor: nordFrost2,
                activeHeaderColor: Self.dynamicColor(
                    light: NSColor(calibratedRed: 0.53, green: 0.75, blue: 0.82, alpha: 0.18),
                    dark: NSColor(calibratedRed: 0.53, green: 0.75, blue: 0.82, alpha: 0.22)
                ),
                inactiveHeaderColor: Self.dynamicColor(
                    light: NSColor(calibratedRed: 0.82, green: 0.84, blue: 0.87, alpha: 0.15),
                    dark: NSColor(calibratedRed: 0.23, green: 0.26, blue: 0.32, alpha: 0.3)
                ),
                activePathTextColor: .labelColor,
                inactivePathTextColor: .secondaryLabelColor,
                markedColor: Self.dynamicColor(
                    light: NSColor(calibratedRed: 0.92, green: 0.80, blue: 0.55, alpha: 0.2),
                    dark: NSColor(calibratedRed: 0.92, green: 0.80, blue: 0.55, alpha: 0.25)
                ),
                visualMarkedColor: Self.dynamicColor(
                    light: NSColor(calibratedRed: 0.53, green: 0.75, blue: 0.82, alpha: 0.25),
                    dark: NSColor(calibratedRed: 0.53, green: 0.75, blue: 0.82, alpha: 0.3)
                ),
                activePaneAlpha: 1.0,
                inactivePaneAlpha: 0.88,
                sidebarSectionHeaderColor: Self.dynamicColor(
                    light: NSColor(calibratedRed: 0.30, green: 0.34, blue: 0.42, alpha: 1.0),
                    dark: NSColor(calibratedRed: 0.82, green: 0.84, blue: 0.87, alpha: 1.0)
                ),
                sidebarEntryTextColor: .labelColor,
                sidebarIconTintColor: nordAccent,
                sidebarShortcutHintColor: nordFrost2,
                statusBarBackgroundColor: nordBg,
                statusBarTextColor: Self.dynamicColor(
                    light: NSColor(calibratedRed: 0.30, green: 0.34, blue: 0.42, alpha: 1.0),
                    dark: NSColor(calibratedRed: 0.82, green: 0.84, blue: 0.87, alpha: 1.0)
                ),
                filterBarPromptColor: nordAccent,
                filterBarTextColor: .labelColor,
                previewBorderColor: Self.dynamicColor(
                    light: NSColor(calibratedRed: 0.82, green: 0.84, blue: 0.87, alpha: 0.8),
                    dark: NSColor(calibratedRed: 0.26, green: 0.30, blue: 0.37, alpha: 0.8)
                ),
                accentColor: nordAccent,
                windowBackgroundColor: nordBg,
                paneBackgroundColor: Self.dynamicColor(
                    light: NSColor(calibratedRed: 0.95, green: 0.96, blue: 0.98, alpha: 1.0),
                    dark: NSColor(calibratedRed: 0.15, green: 0.17, blue: 0.22, alpha: 1.0)
                ),
                tableBackgroundColor: Self.dynamicColor(
                    light: NSColor(calibratedRed: 0.97, green: 0.98, blue: 0.99, alpha: 1.0),
                    dark: NSColor(calibratedRed: 0.12, green: 0.14, blue: 0.19, alpha: 1.0)
                ),
                sidebarBackgroundColor: Self.dynamicColor(
                    light: NSColor(calibratedRed: 0.91, green: 0.93, blue: 0.96, alpha: 1.0),
                    dark: NSColor(calibratedRed: 0.14, green: 0.16, blue: 0.21, alpha: 1.0)
                ),
                filterBarBackgroundColor: Self.dynamicColor(
                    light: NSColor(calibratedRed: 0.88, green: 0.92, blue: 0.97, alpha: 0.88),
                    dark: NSColor(calibratedRed: 0.20, green: 0.24, blue: 0.31, alpha: 0.86)
                ),
                filterBarBorderColor: nordAccent.withAlphaComponent(0.35),
                previewBackgroundColor: Self.dynamicColor(
                    light: NSColor(calibratedRed: 0.95, green: 0.96, blue: 0.98, alpha: 1.0),
                    dark: NSColor(calibratedRed: 0.13, green: 0.15, blue: 0.20, alpha: 1.0)
                ),
                primaryTextColor: .labelColor,
                secondaryTextColor: .secondaryLabelColor
            )
        case .dracula:
            let draculaPurple = Self.dynamicColor(
                light: NSColor(calibratedRed: 0.74, green: 0.58, blue: 0.98, alpha: 1.0),
                dark: NSColor(calibratedRed: 0.74, green: 0.58, blue: 0.98, alpha: 1.0)
            )
            let draculaPink = Self.dynamicColor(
                light: NSColor(calibratedRed: 1.0, green: 0.47, blue: 0.78, alpha: 1.0),
                dark: NSColor(calibratedRed: 1.0, green: 0.47, blue: 0.78, alpha: 1.0)
            )
            let draculaBg = Self.dynamicColor(
                light: NSColor(calibratedRed: 0.95, green: 0.94, blue: 0.96, alpha: 1.0),
                dark: NSColor(calibratedRed: 0.16, green: 0.16, blue: 0.21, alpha: 1.0)
            )
            return FilerThemePalette(
                activeBorderColor: draculaPurple,
                inactiveBorderColor: Self.dynamicColor(
                    light: NSColor(calibratedRed: 0.80, green: 0.76, blue: 0.86, alpha: 1.0),
                    dark: NSColor(calibratedRed: 0.27, green: 0.28, blue: 0.35, alpha: 1.0)
                ),
                dropTargetBorderColor: draculaPink,
                activeHeaderColor: Self.dynamicColor(
                    light: NSColor(calibratedRed: 0.74, green: 0.58, blue: 0.98, alpha: 0.16),
                    dark: NSColor(calibratedRed: 0.74, green: 0.58, blue: 0.98, alpha: 0.22)
                ),
                inactiveHeaderColor: Self.dynamicColor(
                    light: NSColor(calibratedRed: 0.80, green: 0.76, blue: 0.86, alpha: 0.12),
                    dark: NSColor(calibratedRed: 0.20, green: 0.20, blue: 0.27, alpha: 0.3)
                ),
                activePathTextColor: .labelColor,
                inactivePathTextColor: .secondaryLabelColor,
                markedColor: Self.dynamicColor(
                    light: NSColor(calibratedRed: 1.0, green: 0.47, blue: 0.78, alpha: 0.18),
                    dark: NSColor(calibratedRed: 1.0, green: 0.47, blue: 0.78, alpha: 0.22)
                ),
                visualMarkedColor: Self.dynamicColor(
                    light: NSColor(calibratedRed: 0.74, green: 0.58, blue: 0.98, alpha: 0.24),
                    dark: NSColor(calibratedRed: 0.74, green: 0.58, blue: 0.98, alpha: 0.3)
                ),
                activePaneAlpha: 1.0,
                inactivePaneAlpha: 0.88,
                sidebarSectionHeaderColor: Self.dynamicColor(
                    light: NSColor(calibratedRed: 0.38, green: 0.34, blue: 0.48, alpha: 1.0),
                    dark: NSColor(calibratedRed: 0.62, green: 0.58, blue: 0.72, alpha: 1.0)
                ),
                sidebarEntryTextColor: .labelColor,
                sidebarIconTintColor: draculaPurple,
                sidebarShortcutHintColor: draculaPink,
                statusBarBackgroundColor: draculaBg,
                statusBarTextColor: Self.dynamicColor(
                    light: NSColor(calibratedRed: 0.38, green: 0.34, blue: 0.48, alpha: 1.0),
                    dark: NSColor(calibratedRed: 0.62, green: 0.58, blue: 0.72, alpha: 1.0)
                ),
                filterBarPromptColor: draculaPurple,
                filterBarTextColor: .labelColor,
                previewBorderColor: Self.dynamicColor(
                    light: NSColor(calibratedRed: 0.80, green: 0.76, blue: 0.86, alpha: 0.8),
                    dark: NSColor(calibratedRed: 0.27, green: 0.28, blue: 0.35, alpha: 0.8)
                ),
                accentColor: draculaPurple,
                windowBackgroundColor: draculaBg,
                paneBackgroundColor: Self.dynamicColor(
                    light: NSColor(calibratedRed: 0.96, green: 0.95, blue: 0.98, alpha: 1.0),
                    dark: NSColor(calibratedRed: 0.12, green: 0.12, blue: 0.17, alpha: 1.0)
                ),
                tableBackgroundColor: Self.dynamicColor(
                    light: NSColor(calibratedRed: 0.98, green: 0.97, blue: 0.99, alpha: 1.0),
                    dark: NSColor(calibratedRed: 0.09, green: 0.10, blue: 0.15, alpha: 1.0)
                ),
                sidebarBackgroundColor: Self.dynamicColor(
                    light: NSColor(calibratedRed: 0.93, green: 0.90, blue: 0.97, alpha: 1.0),
                    dark: NSColor(calibratedRed: 0.13, green: 0.13, blue: 0.18, alpha: 1.0)
                ),
                filterBarBackgroundColor: Self.dynamicColor(
                    light: NSColor(calibratedRed: 0.92, green: 0.89, blue: 0.97, alpha: 0.86),
                    dark: NSColor(calibratedRed: 0.24, green: 0.20, blue: 0.33, alpha: 0.82)
                ),
                filterBarBorderColor: draculaPink.withAlphaComponent(0.32),
                previewBackgroundColor: Self.dynamicColor(
                    light: NSColor(calibratedRed: 0.96, green: 0.94, blue: 0.98, alpha: 1.0),
                    dark: NSColor(calibratedRed: 0.10, green: 0.10, blue: 0.16, alpha: 1.0)
                ),
                primaryTextColor: .labelColor,
                secondaryTextColor: .secondaryLabelColor
            )
        case .solarized:
            let solarAccent = Self.dynamicColor(
                light: NSColor(calibratedRed: 0.15, green: 0.55, blue: 0.82, alpha: 1.0),
                dark: NSColor(calibratedRed: 0.15, green: 0.55, blue: 0.82, alpha: 1.0)
            )
            let solarOrange = Self.dynamicColor(
                light: NSColor(calibratedRed: 0.80, green: 0.29, blue: 0.09, alpha: 1.0),
                dark: NSColor(calibratedRed: 0.80, green: 0.29, blue: 0.09, alpha: 1.0)
            )
            let solarBg = Self.dynamicColor(
                light: NSColor(calibratedRed: 0.99, green: 0.96, blue: 0.89, alpha: 1.0),
                dark: NSColor(calibratedRed: 0.0, green: 0.17, blue: 0.21, alpha: 1.0)
            )
            return FilerThemePalette(
                activeBorderColor: solarAccent,
                inactiveBorderColor: Self.dynamicColor(
                    light: NSColor(calibratedRed: 0.93, green: 0.91, blue: 0.84, alpha: 1.0),
                    dark: NSColor(calibratedRed: 0.03, green: 0.21, blue: 0.26, alpha: 1.0)
                ),
                dropTargetBorderColor: solarOrange,
                activeHeaderColor: Self.dynamicColor(
                    light: NSColor(calibratedRed: 0.15, green: 0.55, blue: 0.82, alpha: 0.15),
                    dark: NSColor(calibratedRed: 0.15, green: 0.55, blue: 0.82, alpha: 0.2)
                ),
                inactiveHeaderColor: Self.dynamicColor(
                    light: NSColor(calibratedRed: 0.93, green: 0.91, blue: 0.84, alpha: 0.2),
                    dark: NSColor(calibratedRed: 0.03, green: 0.21, blue: 0.26, alpha: 0.3)
                ),
                activePathTextColor: .labelColor,
                inactivePathTextColor: .secondaryLabelColor,
                markedColor: Self.dynamicColor(
                    light: NSColor(calibratedRed: 0.80, green: 0.29, blue: 0.09, alpha: 0.16),
                    dark: NSColor(calibratedRed: 0.80, green: 0.29, blue: 0.09, alpha: 0.22)
                ),
                visualMarkedColor: Self.dynamicColor(
                    light: NSColor(calibratedRed: 0.15, green: 0.55, blue: 0.82, alpha: 0.22),
                    dark: NSColor(calibratedRed: 0.15, green: 0.55, blue: 0.82, alpha: 0.28)
                ),
                activePaneAlpha: 1.0,
                inactivePaneAlpha: 0.88,
                sidebarSectionHeaderColor: Self.dynamicColor(
                    light: NSColor(calibratedRed: 0.40, green: 0.48, blue: 0.51, alpha: 1.0),
                    dark: NSColor(calibratedRed: 0.58, green: 0.63, blue: 0.63, alpha: 1.0)
                ),
                sidebarEntryTextColor: .labelColor,
                sidebarIconTintColor: solarAccent,
                sidebarShortcutHintColor: Self.dynamicColor(
                    light: NSColor(calibratedRed: 0.51, green: 0.58, blue: 0.59, alpha: 1.0),
                    dark: NSColor(calibratedRed: 0.51, green: 0.58, blue: 0.59, alpha: 1.0)
                ),
                statusBarBackgroundColor: solarBg,
                statusBarTextColor: Self.dynamicColor(
                    light: NSColor(calibratedRed: 0.40, green: 0.48, blue: 0.51, alpha: 1.0),
                    dark: NSColor(calibratedRed: 0.58, green: 0.63, blue: 0.63, alpha: 1.0)
                ),
                filterBarPromptColor: solarAccent,
                filterBarTextColor: .labelColor,
                previewBorderColor: Self.dynamicColor(
                    light: NSColor(calibratedRed: 0.93, green: 0.91, blue: 0.84, alpha: 0.8),
                    dark: NSColor(calibratedRed: 0.03, green: 0.21, blue: 0.26, alpha: 0.8)
                ),
                accentColor: solarAccent,
                windowBackgroundColor: solarBg,
                paneBackgroundColor: Self.dynamicColor(
                    light: NSColor(calibratedRed: 0.995, green: 0.98, blue: 0.92, alpha: 1.0),
                    dark: NSColor(calibratedRed: 0.0, green: 0.14, blue: 0.18, alpha: 1.0)
                ),
                tableBackgroundColor: Self.dynamicColor(
                    light: NSColor(calibratedRed: 1.0, green: 0.985, blue: 0.93, alpha: 1.0),
                    dark: NSColor(calibratedRed: 0.0, green: 0.12, blue: 0.16, alpha: 1.0)
                ),
                sidebarBackgroundColor: Self.dynamicColor(
                    light: NSColor(calibratedRed: 0.96, green: 0.93, blue: 0.84, alpha: 1.0),
                    dark: NSColor(calibratedRed: 0.0, green: 0.15, blue: 0.19, alpha: 1.0)
                ),
                filterBarBackgroundColor: Self.dynamicColor(
                    light: NSColor(calibratedRed: 0.95, green: 0.90, blue: 0.75, alpha: 0.84),
                    dark: NSColor(calibratedRed: 0.02, green: 0.26, blue: 0.31, alpha: 0.8)
                ),
                filterBarBorderColor: solarAccent.withAlphaComponent(0.34),
                previewBackgroundColor: Self.dynamicColor(
                    light: NSColor(calibratedRed: 0.995, green: 0.97, blue: 0.90, alpha: 1.0),
                    dark: NSColor(calibratedRed: 0.0, green: 0.13, blue: 0.17, alpha: 1.0)
                ),
                primaryTextColor: .labelColor,
                secondaryTextColor: .secondaryLabelColor
            )
        case .tokyoNight:
            let tokyoBlue = Self.dynamicColor(
                light: NSColor(calibratedRed: 0.20, green: 0.50, blue: 0.84, alpha: 1.0),
                dark: NSColor(calibratedRed: 0.48, green: 0.64, blue: 0.97, alpha: 1.0)
            )
            let tokyoPurple = Self.dynamicColor(
                light: NSColor(calibratedRed: 0.55, green: 0.38, blue: 0.84, alpha: 1.0),
                dark: NSColor(calibratedRed: 0.73, green: 0.60, blue: 0.97, alpha: 1.0)
            )
            let tokyoBg = Self.dynamicColor(
                light: NSColor(calibratedRed: 0.95, green: 0.95, blue: 0.97, alpha: 1.0),
                dark: NSColor(calibratedRed: 0.10, green: 0.11, blue: 0.15, alpha: 1.0)
            )
            return FilerThemePalette(
                activeBorderColor: tokyoBlue,
                inactiveBorderColor: Self.dynamicColor(
                    light: NSColor(calibratedRed: 0.82, green: 0.83, blue: 0.88, alpha: 1.0),
                    dark: NSColor(calibratedRed: 0.19, green: 0.20, blue: 0.28, alpha: 1.0)
                ),
                dropTargetBorderColor: tokyoPurple,
                activeHeaderColor: Self.dynamicColor(
                    light: NSColor(calibratedRed: 0.20, green: 0.50, blue: 0.84, alpha: 0.14),
                    dark: NSColor(calibratedRed: 0.48, green: 0.64, blue: 0.97, alpha: 0.2)
                ),
                inactiveHeaderColor: Self.dynamicColor(
                    light: NSColor(calibratedRed: 0.82, green: 0.83, blue: 0.88, alpha: 0.15),
                    dark: NSColor(calibratedRed: 0.15, green: 0.16, blue: 0.22, alpha: 0.3)
                ),
                activePathTextColor: .labelColor,
                inactivePathTextColor: .secondaryLabelColor,
                markedColor: Self.dynamicColor(
                    light: NSColor(calibratedRed: 0.89, green: 0.59, blue: 0.24, alpha: 0.18),
                    dark: NSColor(calibratedRed: 0.89, green: 0.59, blue: 0.24, alpha: 0.24)
                ),
                visualMarkedColor: Self.dynamicColor(
                    light: NSColor(calibratedRed: 0.48, green: 0.64, blue: 0.97, alpha: 0.22),
                    dark: NSColor(calibratedRed: 0.48, green: 0.64, blue: 0.97, alpha: 0.28)
                ),
                activePaneAlpha: 1.0,
                inactivePaneAlpha: 0.88,
                sidebarSectionHeaderColor: Self.dynamicColor(
                    light: NSColor(calibratedRed: 0.35, green: 0.36, blue: 0.46, alpha: 1.0),
                    dark: NSColor(calibratedRed: 0.73, green: 0.74, blue: 0.84, alpha: 1.0)
                ),
                sidebarEntryTextColor: .labelColor,
                sidebarIconTintColor: tokyoBlue,
                sidebarShortcutHintColor: tokyoPurple,
                statusBarBackgroundColor: tokyoBg,
                statusBarTextColor: Self.dynamicColor(
                    light: NSColor(calibratedRed: 0.35, green: 0.36, blue: 0.46, alpha: 1.0),
                    dark: NSColor(calibratedRed: 0.73, green: 0.74, blue: 0.84, alpha: 1.0)
                ),
                filterBarPromptColor: tokyoBlue,
                filterBarTextColor: .labelColor,
                previewBorderColor: Self.dynamicColor(
                    light: NSColor(calibratedRed: 0.82, green: 0.83, blue: 0.88, alpha: 0.8),
                    dark: NSColor(calibratedRed: 0.19, green: 0.20, blue: 0.28, alpha: 0.8)
                ),
                accentColor: tokyoBlue,
                windowBackgroundColor: tokyoBg,
                paneBackgroundColor: Self.dynamicColor(
                    light: NSColor(calibratedRed: 0.97, green: 0.97, blue: 0.99, alpha: 1.0),
                    dark: NSColor(calibratedRed: 0.08, green: 0.09, blue: 0.14, alpha: 1.0)
                ),
                tableBackgroundColor: Self.dynamicColor(
                    light: NSColor(calibratedRed: 0.99, green: 0.99, blue: 1.0, alpha: 1.0),
                    dark: NSColor(calibratedRed: 0.07, green: 0.08, blue: 0.13, alpha: 1.0)
                ),
                sidebarBackgroundColor: Self.dynamicColor(
                    light: NSColor(calibratedRed: 0.92, green: 0.93, blue: 0.98, alpha: 1.0),
                    dark: NSColor(calibratedRed: 0.10, green: 0.11, blue: 0.16, alpha: 1.0)
                ),
                filterBarBackgroundColor: Self.dynamicColor(
                    light: NSColor(calibratedRed: 0.90, green: 0.94, blue: 1.0, alpha: 0.84),
                    dark: NSColor(calibratedRed: 0.19, green: 0.23, blue: 0.36, alpha: 0.78)
                ),
                filterBarBorderColor: tokyoBlue.withAlphaComponent(0.36),
                previewBackgroundColor: Self.dynamicColor(
                    light: NSColor(calibratedRed: 0.98, green: 0.98, blue: 1.0, alpha: 1.0),
                    dark: NSColor(calibratedRed: 0.07, green: 0.08, blue: 0.13, alpha: 1.0)
                ),
                primaryTextColor: .labelColor,
                secondaryTextColor: .secondaryLabelColor
            )
        case .gruvbox:
            let gruvAccent = Self.dynamicColor(
                light: NSColor(calibratedRed: 0.80, green: 0.40, blue: 0.16, alpha: 1.0),
                dark: NSColor(calibratedRed: 0.98, green: 0.58, blue: 0.21, alpha: 1.0)
            )
            let gruvGreen = Self.dynamicColor(
                light: NSColor(calibratedRed: 0.60, green: 0.63, blue: 0.22, alpha: 1.0),
                dark: NSColor(calibratedRed: 0.72, green: 0.73, blue: 0.29, alpha: 1.0)
            )
            let gruvBg = Self.dynamicColor(
                light: NSColor(calibratedRed: 0.99, green: 0.95, blue: 0.86, alpha: 1.0),
                dark: NSColor(calibratedRed: 0.16, green: 0.14, blue: 0.13, alpha: 1.0)
            )
            return FilerThemePalette(
                activeBorderColor: gruvAccent,
                inactiveBorderColor: Self.dynamicColor(
                    light: NSColor(calibratedRed: 0.88, green: 0.82, blue: 0.71, alpha: 1.0),
                    dark: NSColor(calibratedRed: 0.28, green: 0.25, blue: 0.23, alpha: 1.0)
                ),
                dropTargetBorderColor: gruvGreen,
                activeHeaderColor: gruvAccent.withAlphaComponent(0.2),
                inactiveHeaderColor: Self.dynamicColor(
                    light: NSColor(calibratedRed: 0.91, green: 0.86, blue: 0.75, alpha: 0.35),
                    dark: NSColor(calibratedRed: 0.24, green: 0.21, blue: 0.19, alpha: 0.42)
                ),
                activePathTextColor: .labelColor,
                inactivePathTextColor: .secondaryLabelColor,
                markedColor: gruvGreen.withAlphaComponent(0.2),
                visualMarkedColor: gruvAccent.withAlphaComponent(0.24),
                activePaneAlpha: 1.0,
                inactivePaneAlpha: 0.9,
                sidebarSectionHeaderColor: Self.dynamicColor(
                    light: NSColor(calibratedRed: 0.46, green: 0.35, blue: 0.22, alpha: 1.0),
                    dark: NSColor(calibratedRed: 0.86, green: 0.75, blue: 0.58, alpha: 1.0)
                ),
                sidebarEntryTextColor: .labelColor,
                sidebarIconTintColor: gruvAccent,
                sidebarShortcutHintColor: gruvGreen,
                statusBarBackgroundColor: gruvBg,
                statusBarTextColor: .secondaryLabelColor,
                filterBarPromptColor: gruvAccent,
                filterBarTextColor: .labelColor,
                previewBorderColor: gruvAccent.withAlphaComponent(0.55),
                accentColor: gruvAccent,
                windowBackgroundColor: gruvBg,
                paneBackgroundColor: Self.dynamicColor(
                    light: NSColor(calibratedRed: 0.995, green: 0.96, blue: 0.88, alpha: 1.0),
                    dark: NSColor(calibratedRed: 0.12, green: 0.11, blue: 0.10, alpha: 1.0)
                ),
                tableBackgroundColor: Self.dynamicColor(
                    light: NSColor(calibratedRed: 0.998, green: 0.97, blue: 0.90, alpha: 1.0),
                    dark: NSColor(calibratedRed: 0.10, green: 0.09, blue: 0.09, alpha: 1.0)
                ),
                sidebarBackgroundColor: Self.dynamicColor(
                    light: NSColor(calibratedRed: 0.95, green: 0.90, blue: 0.79, alpha: 1.0),
                    dark: NSColor(calibratedRed: 0.18, green: 0.16, blue: 0.15, alpha: 1.0)
                ),
                filterBarBackgroundColor: Self.dynamicColor(
                    light: NSColor(calibratedRed: 0.94, green: 0.88, blue: 0.72, alpha: 0.86),
                    dark: NSColor(calibratedRed: 0.35, green: 0.24, blue: 0.14, alpha: 0.78)
                ),
                filterBarBorderColor: gruvAccent.withAlphaComponent(0.35),
                previewBackgroundColor: Self.dynamicColor(
                    light: NSColor(calibratedRed: 0.995, green: 0.96, blue: 0.88, alpha: 1.0),
                    dark: NSColor(calibratedRed: 0.11, green: 0.10, blue: 0.10, alpha: 1.0)
                ),
                primaryTextColor: .labelColor,
                secondaryTextColor: .secondaryLabelColor
            )
        case .catppuccinLatte:
            let latteBlue = NSColor(calibratedRed: 0.11, green: 0.42, blue: 0.79, alpha: 1.0)
            let latteRose = NSColor(calibratedRed: 0.85, green: 0.35, blue: 0.45, alpha: 1.0)
            let latteBg = NSColor(calibratedRed: 0.94, green: 0.93, blue: 0.96, alpha: 1.0)
            return FilerThemePalette(
                activeBorderColor: latteBlue,
                inactiveBorderColor: NSColor(calibratedRed: 0.82, green: 0.81, blue: 0.86, alpha: 1.0),
                dropTargetBorderColor: latteRose,
                activeHeaderColor: latteBlue.withAlphaComponent(0.16),
                inactiveHeaderColor: NSColor(calibratedRed: 0.85, green: 0.84, blue: 0.89, alpha: 0.3),
                activePathTextColor: NSColor(calibratedRed: 0.29, green: 0.27, blue: 0.35, alpha: 1.0),
                inactivePathTextColor: NSColor(calibratedRed: 0.43, green: 0.41, blue: 0.50, alpha: 1.0),
                markedColor: latteRose.withAlphaComponent(0.16),
                visualMarkedColor: latteBlue.withAlphaComponent(0.24),
                activePaneAlpha: 1.0,
                inactivePaneAlpha: 0.92,
                sidebarSectionHeaderColor: NSColor(calibratedRed: 0.45, green: 0.43, blue: 0.52, alpha: 1.0),
                sidebarEntryTextColor: NSColor(calibratedRed: 0.26, green: 0.25, blue: 0.33, alpha: 1.0),
                sidebarIconTintColor: latteBlue,
                sidebarShortcutHintColor: NSColor(calibratedRed: 0.62, green: 0.45, blue: 0.55, alpha: 1.0),
                statusBarBackgroundColor: latteBg,
                statusBarTextColor: NSColor(calibratedRed: 0.45, green: 0.43, blue: 0.52, alpha: 1.0),
                filterBarPromptColor: latteBlue,
                filterBarTextColor: NSColor(calibratedRed: 0.30, green: 0.28, blue: 0.37, alpha: 1.0),
                previewBorderColor: NSColor(calibratedRed: 0.76, green: 0.75, blue: 0.83, alpha: 0.9),
                accentColor: latteBlue,
                windowBackgroundColor: latteBg,
                paneBackgroundColor: NSColor(calibratedRed: 0.98, green: 0.97, blue: 0.99, alpha: 1.0),
                tableBackgroundColor: NSColor(calibratedRed: 0.99, green: 0.99, blue: 1.0, alpha: 1.0),
                sidebarBackgroundColor: NSColor(calibratedRed: 0.90, green: 0.89, blue: 0.94, alpha: 1.0),
                filterBarBackgroundColor: NSColor(calibratedRed: 0.88, green: 0.92, blue: 1.0, alpha: 0.86),
                filterBarBorderColor: latteBlue.withAlphaComponent(0.32),
                previewBackgroundColor: NSColor(calibratedRed: 0.99, green: 0.99, blue: 1.0, alpha: 1.0),
                primaryTextColor: NSColor(calibratedRed: 0.26, green: 0.25, blue: 0.33, alpha: 1.0),
                secondaryTextColor: NSColor(calibratedRed: 0.48, green: 0.46, blue: 0.55, alpha: 1.0)
            )
        case .mintLight:
            let mintAccent = NSColor(calibratedRed: 0.0, green: 0.58, blue: 0.48, alpha: 1.0)
            let mintSky = NSColor(calibratedRed: 0.13, green: 0.65, blue: 0.88, alpha: 1.0)
            let mintBg = NSColor(calibratedRed: 0.92, green: 0.98, blue: 0.96, alpha: 1.0)
            return FilerThemePalette(
                activeBorderColor: mintAccent,
                inactiveBorderColor: NSColor(calibratedRed: 0.72, green: 0.85, blue: 0.80, alpha: 1.0),
                dropTargetBorderColor: mintSky,
                activeHeaderColor: mintAccent.withAlphaComponent(0.16),
                inactiveHeaderColor: NSColor(calibratedRed: 0.78, green: 0.91, blue: 0.86, alpha: 0.3),
                activePathTextColor: NSColor(calibratedRed: 0.15, green: 0.33, blue: 0.29, alpha: 1.0),
                inactivePathTextColor: NSColor(calibratedRed: 0.25, green: 0.44, blue: 0.40, alpha: 1.0),
                markedColor: mintSky.withAlphaComponent(0.16),
                visualMarkedColor: mintAccent.withAlphaComponent(0.22),
                activePaneAlpha: 1.0,
                inactivePaneAlpha: 0.92,
                sidebarSectionHeaderColor: NSColor(calibratedRed: 0.20, green: 0.45, blue: 0.41, alpha: 1.0),
                sidebarEntryTextColor: NSColor(calibratedRed: 0.12, green: 0.30, blue: 0.27, alpha: 1.0),
                sidebarIconTintColor: mintAccent,
                sidebarShortcutHintColor: mintSky,
                statusBarBackgroundColor: mintBg,
                statusBarTextColor: NSColor(calibratedRed: 0.20, green: 0.45, blue: 0.41, alpha: 1.0),
                filterBarPromptColor: mintAccent,
                filterBarTextColor: NSColor(calibratedRed: 0.12, green: 0.30, blue: 0.27, alpha: 1.0),
                previewBorderColor: NSColor(calibratedRed: 0.55, green: 0.80, blue: 0.74, alpha: 0.9),
                accentColor: mintAccent,
                windowBackgroundColor: mintBg,
                paneBackgroundColor: NSColor(calibratedRed: 0.95, green: 0.995, blue: 0.98, alpha: 1.0),
                tableBackgroundColor: NSColor(calibratedRed: 0.97, green: 1.0, blue: 0.99, alpha: 1.0),
                sidebarBackgroundColor: NSColor(calibratedRed: 0.88, green: 0.97, blue: 0.94, alpha: 1.0),
                filterBarBackgroundColor: NSColor(calibratedRed: 0.86, green: 0.97, blue: 0.93, alpha: 0.86),
                filterBarBorderColor: mintAccent.withAlphaComponent(0.32),
                previewBackgroundColor: NSColor(calibratedRed: 0.98, green: 1.0, blue: 0.99, alpha: 1.0),
                primaryTextColor: NSColor(calibratedRed: 0.10, green: 0.28, blue: 0.25, alpha: 1.0),
                secondaryTextColor: NSColor(calibratedRed: 0.23, green: 0.44, blue: 0.40, alpha: 1.0)
            )
        }
    }
}

extension NSColor {
    func applyingBackgroundOpacity(_ opacity: CGFloat) -> NSColor {
        withAlphaComponent(alphaComponent * max(0, min(opacity, 1)))
    }
}
