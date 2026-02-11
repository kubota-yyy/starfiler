import Foundation
import Observation

@MainActor
@Observable
final class FilePaneViewModel {
    private(set) var directoryContents: DirectoryContents {
        didSet {
            onItemsChanged?(directoryContents.displayedItems)
        }
    }

    private(set) var paneState: PaneState {
        didSet {
            if oldValue.cursorIndex != paneState.cursorIndex {
                onCursorChanged?(paneState.cursorIndex)
            }
        }
    }

    private(set) var navigationHistory = NavigationHistory()

    var onItemsChanged: (([FileItem]) -> Void)?
    var onCursorChanged: ((Int) -> Void)?

    private let fileSystemService: FileSystemProviding
    private nonisolated(unsafe) var loadTask: Task<Void, Never>?

    init(
        fileSystemService: FileSystemProviding = FileSystemService(),
        initialDirectory: URL = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
    ) {
        self.fileSystemService = fileSystemService
        let normalizedDirectory = initialDirectory.standardizedFileURL
        self.paneState = PaneState(currentDirectory: normalizedDirectory)
        self.directoryContents = DirectoryContents()
        loadDirectory(at: normalizedDirectory, recordHistory: false)
    }

    deinit {
        loadTask?.cancel()
    }

    var selectedItem: FileItem? {
        guard directoryContents.displayedItems.indices.contains(paneState.cursorIndex) else {
            return nil
        }
        return directoryContents.displayedItems[paneState.cursorIndex]
    }

    var canGoBack: Bool {
        !navigationHistory.backStack.isEmpty
    }

    var canGoForward: Bool {
        !navigationHistory.forwardStack.isEmpty
    }

    func navigate(to directory: URL) {
        let destination = directory.standardizedFileURL
        guard destination != paneState.currentDirectory else {
            return
        }

        navigationHistory.push(paneState.currentDirectory)
        loadDirectory(at: destination, recordHistory: false)
    }

    func goBack() {
        guard let destination = navigationHistory.goBack(from: paneState.currentDirectory) else {
            return
        }
        loadDirectory(at: destination, recordHistory: false)
    }

    func goForward() {
        guard let destination = navigationHistory.goForward(from: paneState.currentDirectory) else {
            return
        }
        loadDirectory(at: destination, recordHistory: false)
    }

    func goToParent() {
        let parent = paneState.currentDirectory.deletingLastPathComponent()
        guard parent.path != paneState.currentDirectory.path else {
            return
        }
        navigate(to: parent)
    }

    func enterSelected() {
        guard let item = selectedItem, item.isDirectory, !item.isPackage else {
            return
        }
        navigate(to: item.url)
    }

    func moveCursor(by delta: Int) {
        let itemCount = directoryContents.displayedItems.count
        guard itemCount > 0 else {
            setCursor(index: 0)
            return
        }

        let nextIndex = min(max(0, paneState.cursorIndex + delta), itemCount - 1)
        setCursor(index: nextIndex)
    }

    func setCursor(index: Int) {
        guard !directoryContents.displayedItems.isEmpty else {
            paneState.cursorIndex = 0
            return
        }

        let clampedIndex = min(max(index, 0), directoryContents.displayedItems.count - 1)
        paneState.cursorIndex = clampedIndex
    }

    func setFilterText(_ text: String) {
        var updatedContents = directoryContents
        updatedContents.filterText = text
        updatedContents.recompute()
        directoryContents = updatedContents
        clampCursorIndex()
    }

    func setShowHiddenFiles(_ enabled: Bool) {
        var updatedContents = directoryContents
        updatedContents.showHiddenFiles = enabled
        updatedContents.recompute()
        directoryContents = updatedContents
        clampCursorIndex()
    }

    private func loadDirectory(at directory: URL, recordHistory: Bool) {
        if recordHistory {
            navigationHistory.push(paneState.currentDirectory)
        }

        loadTask?.cancel()
        paneState.currentDirectory = directory

        loadTask = Task { [weak self] in
            guard let self else {
                return
            }

            do {
                let items = try await self.fileSystemService.contentsOfDirectory(at: directory)
                guard !Task.isCancelled else {
                    return
                }

                var updatedContents = self.directoryContents
                updatedContents.allItems = items
                updatedContents.recompute()
                self.directoryContents = updatedContents
                self.clampCursorIndex()
            } catch {
                guard !Task.isCancelled else {
                    return
                }

                var updatedContents = self.directoryContents
                updatedContents.allItems = []
                updatedContents.displayedItems = []
                self.directoryContents = updatedContents
                self.paneState.cursorIndex = 0
            }
        }
    }

    private func clampCursorIndex() {
        let count = directoryContents.displayedItems.count
        guard count > 0 else {
            paneState.cursorIndex = 0
            return
        }
        if paneState.cursorIndex >= count {
            paneState.cursorIndex = count - 1
        }
    }
}
