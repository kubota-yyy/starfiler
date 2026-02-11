import Foundation
import Observation

@MainActor
@Observable
final class MainViewModel {
    let leftPane: FilePaneViewModel
    let rightPane: FilePaneViewModel
    let securityScopedBookmarkService: any SecurityScopedBookmarkProviding

    private(set) var activePaneSide: PaneSide
    var clipboard: [URL]

    init(
        fileSystemService: FileSystemProviding = FileSystemService(),
        securityScopedBookmarkService: any SecurityScopedBookmarkProviding = SecurityScopedBookmarkService.shared,
        initialLeftDirectory: URL = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true),
        initialRightDirectory: URL? = nil
    ) {
        self.securityScopedBookmarkService = securityScopedBookmarkService

        let normalizedLeftDirectory = initialLeftDirectory.standardizedFileURL
        let normalizedRightDirectory = (initialRightDirectory ?? normalizedLeftDirectory).standardizedFileURL

        self.leftPane = FilePaneViewModel(
            fileSystemService: fileSystemService,
            securityScopedBookmarkService: securityScopedBookmarkService,
            initialDirectory: normalizedLeftDirectory
        )

        self.rightPane = FilePaneViewModel(
            fileSystemService: fileSystemService,
            securityScopedBookmarkService: securityScopedBookmarkService,
            initialDirectory: normalizedRightDirectory
        )

        self.activePaneSide = .left
        self.clipboard = []
    }

    var activePane: FilePaneViewModel {
        activePaneSide == .left ? leftPane : rightPane
    }

    var inactivePane: FilePaneViewModel {
        activePaneSide == .left ? rightPane : leftPane
    }

    func setActivePane(_ side: PaneSide) {
        activePaneSide = side
    }

    func switchActivePane() {
        activePaneSide = activePaneSide == .left ? .right : .left
    }
}
