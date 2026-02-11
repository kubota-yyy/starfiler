import Foundation
import Observation

@MainActor
@Observable
final class FilePaneViewModel {
    private static let defaultPageStep = 10

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
            if oldValue.markedIndices != paneState.markedIndices {
                onMarkedIndicesChanged?(paneState.markedIndices)
            }
        }
    }

    private(set) var navigationHistory = NavigationHistory()

    var onItemsChanged: (([FileItem]) -> Void)?
    var onCursorChanged: ((Int) -> Void)?
    var onMarkedIndicesChanged: ((IndexSet) -> Void)?

    private let fileSystemService: FileSystemProviding
    private let securityScopedBookmarkService: any SecurityScopedBookmarkProviding
    private nonisolated(unsafe) var loadTask: Task<Void, Never>?

    init(
        fileSystemService: FileSystemProviding = FileSystemService(),
        securityScopedBookmarkService: any SecurityScopedBookmarkProviding = SecurityScopedBookmarkService.shared,
        initialDirectory: URL = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
    ) {
        self.fileSystemService = fileSystemService
        self.securityScopedBookmarkService = securityScopedBookmarkService
        let normalizedDirectory = initialDirectory.standardizedFileURL
        self.paneState = PaneState(currentDirectory: normalizedDirectory)
        self.directoryContents = DirectoryContents()
        loadDirectory(at: normalizedDirectory, previousDirectory: nil)
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

    var isVisualMode: Bool {
        paneState.visualAnchorIndex != nil
    }

    var markedCount: Int {
        paneState.markedIndices.count
    }

    func markedOrSelectedURLs() -> [URL] {
        if !paneState.markedIndices.isEmpty {
            return paneState.markedIndices.compactMap { index in
                guard directoryContents.displayedItems.indices.contains(index) else {
                    return nil
                }
                return directoryContents.displayedItems[index].url
            }
        }

        guard let selectedItem else {
            return []
        }

        return [selectedItem.url]
    }

    func navigate(to directory: URL) {
        let destination = directory.standardizedFileURL
        guard destination != paneState.currentDirectory else {
            return
        }

        let currentDirectory = paneState.currentDirectory
        navigationHistory.push(currentDirectory)
        loadDirectory(at: destination, previousDirectory: currentDirectory)
    }

    func goBack() {
        let currentDirectory = paneState.currentDirectory
        guard let destination = navigationHistory.goBack(from: currentDirectory) else {
            return
        }
        loadDirectory(at: destination, previousDirectory: currentDirectory)
    }

    func goForward() {
        let currentDirectory = paneState.currentDirectory
        guard let destination = navigationHistory.goForward(from: currentDirectory) else {
            return
        }
        loadDirectory(at: destination, previousDirectory: currentDirectory)
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
        updateVisualSelectionForCurrentCursorIfNeeded()
    }

    func moveCursorUp() {
        moveCursor(by: -1)
    }

    func moveCursorDown() {
        moveCursor(by: 1)
    }

    func moveCursorToTop() {
        setCursor(index: 0)
    }

    func moveCursorToBottom() {
        let lastIndex = max(directoryContents.displayedItems.count - 1, 0)
        setCursor(index: lastIndex)
    }

    func moveCursorPageUp(pageStep: Int? = nil) {
        let resolvedPageStep = max(1, pageStep ?? Self.defaultPageStep)
        moveCursor(by: -resolvedPageStep)
    }

    func moveCursorPageDown(pageStep: Int? = nil) {
        let resolvedPageStep = max(1, pageStep ?? Self.defaultPageStep)
        moveCursor(by: resolvedPageStep)
    }

    func toggleMark() {
        guard directoryContents.displayedItems.indices.contains(paneState.cursorIndex) else {
            return
        }

        if paneState.markedIndices.contains(paneState.cursorIndex) {
            paneState.markedIndices.remove(paneState.cursorIndex)
        } else {
            paneState.markedIndices.insert(paneState.cursorIndex)
        }
    }

    func markAll() {
        let count = directoryContents.displayedItems.count
        guard count > 0 else {
            paneState.markedIndices.removeAll()
            return
        }

        paneState.markedIndices = IndexSet(integersIn: 0 ..< count)
    }

    func clearMarks() {
        paneState.markedIndices.removeAll()
    }

    func enterVisualMode() {
        guard !directoryContents.displayedItems.isEmpty else {
            paneState.visualAnchorIndex = nil
            paneState.markedIndices.removeAll()
            return
        }

        paneState.visualAnchorIndex = paneState.cursorIndex
        updateVisualSelectionForCurrentCursorIfNeeded()
    }

    func exitVisualMode() {
        paneState.visualAnchorIndex = nil
    }

    func setVisualSelection(anchorIndex: Int, currentIndex: Int) {
        paneState.visualAnchorIndex = anchorIndex
        setCursor(index: currentIndex)
    }

    func toggleMarkAtCursor() {
        toggleMark()
    }

    func markAllDisplayedItems() {
        markAll()
    }

    func clearAllMarks() {
        clearMarks()
    }

    func setFilterText(_ text: String) {
        var updatedContents = directoryContents
        updatedContents.filterText = text
        updatedContents.recompute()
        directoryContents = updatedContents
        clampCursorIndex()
        clampMarkedIndices()
        clampVisualAnchorIndex()
        updateVisualSelectionForCurrentCursorIfNeeded()
    }

    func clearFilter() {
        setFilterText("")
    }

    func setShowHiddenFiles(_ enabled: Bool) {
        var updatedContents = directoryContents
        updatedContents.showHiddenFiles = enabled
        updatedContents.recompute()
        directoryContents = updatedContents
        clampCursorIndex()
        clampMarkedIndices()
        clampVisualAnchorIndex()
        updateVisualSelectionForCurrentCursorIfNeeded()
    }

    func toggleHiddenFiles() {
        setShowHiddenFiles(!directoryContents.showHiddenFiles)
    }

    func sortByName() {
        applySortDescriptor(.name(ascending: true))
    }

    func sortBySize() {
        applySortDescriptor(.size(ascending: true))
    }

    func sortByDate() {
        applySortDescriptor(.dateModified(ascending: true))
    }

    func reverseSortOrder() {
        let nextSortDescriptor: DirectoryContents.SortDescriptor

        switch directoryContents.sortDescriptor {
        case .name(let ascending):
            nextSortDescriptor = .name(ascending: !ascending)
        case .size(let ascending):
            nextSortDescriptor = .size(ascending: !ascending)
        case .dateModified(let ascending):
            nextSortDescriptor = .dateModified(ascending: !ascending)
        }

        applySortDescriptor(nextSortDescriptor)
    }

    func refreshCurrentDirectory() {
        let currentDirectory = paneState.currentDirectory

        loadTask?.cancel()
        loadTask = Task { [weak self] in
            guard let self else {
                return
            }

            do {
                let items = try await self.fileSystemService.contentsOfDirectory(at: currentDirectory)
                guard !Task.isCancelled else {
                    return
                }

                var updatedContents = self.directoryContents
                updatedContents.allItems = items
                updatedContents.recompute()
                self.directoryContents = updatedContents
                self.clampCursorIndex()
                self.clampMarkedIndices()
                self.clampVisualAnchorIndex()
                self.updateVisualSelectionForCurrentCursorIfNeeded()
            } catch {
                // Keep the latest successfully loaded view when refresh fails.
            }
        }
    }

    func copySelection() {
        // Phase 5+ implementation point.
    }

    func pasteClipboard() {
        // Phase 5+ implementation point.
    }

    func moveSelection() {
        // Phase 5+ implementation point.
    }

    func deleteSelection() {
        // Phase 5+ implementation point.
    }

    func renameSelection() {
        // Phase 5+ implementation point.
    }

    func createDirectory() {
        // Phase 5+ implementation point.
    }

    func togglePreview() {
        // Phase 7 implementation point.
    }

    func openBookmarks() {
        // Phase 9 implementation point.
    }

    func addBookmark() {
        // Phase 9 implementation point.
    }

    func undoLastAction() {
        // Phase 5+ implementation point.
    }

    private func loadDirectory(at directory: URL, previousDirectory: URL?) {
        loadTask?.cancel()

        loadTask = Task { [weak self] in
            guard let self else {
                return
            }

            var didAcquireDestinationScope = false

            do {
                try await self.securityScopedBookmarkService.startAccessing(directory)
                didAcquireDestinationScope = true

                let items = try await self.fileSystemService.contentsOfDirectory(at: directory)
                guard !Task.isCancelled else {
                    if didAcquireDestinationScope {
                        await self.securityScopedBookmarkService.stopAccessing(directory)
                    }
                    return
                }

                if let previousDirectory, previousDirectory != directory {
                    await self.securityScopedBookmarkService.stopAccessing(previousDirectory)
                }

                self.paneState.currentDirectory = directory
                self.paneState.markedIndices.removeAll()
                self.paneState.visualAnchorIndex = nil

                var updatedContents = self.directoryContents
                updatedContents.allItems = items
                updatedContents.recompute()
                self.directoryContents = updatedContents
                self.clampCursorIndex()
                self.clampMarkedIndices()
                self.clampVisualAnchorIndex()
            } catch {
                if didAcquireDestinationScope {
                    await self.securityScopedBookmarkService.stopAccessing(directory)
                }
            }
        }
    }

    private func applySortDescriptor(_ sortDescriptor: DirectoryContents.SortDescriptor) {
        var updatedContents = directoryContents
        updatedContents.sortDescriptor = sortDescriptor
        updatedContents.recompute()
        directoryContents = updatedContents
        clampCursorIndex()
        clampMarkedIndices()
        clampVisualAnchorIndex()
        updateVisualSelectionForCurrentCursorIfNeeded()
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

    private func clampMarkedIndices() {
        let count = directoryContents.displayedItems.count
        guard count > 0 else {
            paneState.markedIndices.removeAll()
            return
        }

        var clamped = IndexSet()
        for index in paneState.markedIndices where index >= 0 && index < count {
            clamped.insert(index)
        }
        paneState.markedIndices = clamped
    }

    private func clampVisualAnchorIndex() {
        guard let visualAnchorIndex = paneState.visualAnchorIndex else {
            return
        }

        let count = directoryContents.displayedItems.count
        guard count > 0 else {
            paneState.visualAnchorIndex = nil
            return
        }

        paneState.visualAnchorIndex = min(max(visualAnchorIndex, 0), count - 1)
    }

    private func updateVisualSelectionForCurrentCursorIfNeeded() {
        guard let visualAnchorIndex = paneState.visualAnchorIndex else {
            return
        }

        let count = directoryContents.displayedItems.count
        guard count > 0 else {
            paneState.markedIndices.removeAll()
            return
        }

        let clampedAnchor = min(max(visualAnchorIndex, 0), count - 1)
        let clampedCurrent = min(max(paneState.cursorIndex, 0), count - 1)

        let lowerBound = min(clampedAnchor, clampedCurrent)
        let upperBound = max(clampedAnchor, clampedCurrent)
        paneState.markedIndices = IndexSet(integersIn: lowerBound ..< (upperBound + 1))
    }
}
