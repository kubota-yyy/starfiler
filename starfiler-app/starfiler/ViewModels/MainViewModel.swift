import Foundation

enum ClipboardOperation: Sendable {
    case copy
    case cut
}

struct TextInputPrompt {
    let title: String
    let message: String
    let defaultValue: String?
}

enum FileOperationCompletionContext: Sendable {
    case normal
    case undo
}

@MainActor
final class MainViewModel {
    let leftPane: FilePaneViewModel
    let rightPane: FilePaneViewModel
    let previewPane: PreviewViewModel
    let terminalSessionListViewModel: TerminalSessionListViewModel
    let securityScopedBookmarkService: any SecurityScopedBookmarkProviding
    let visitHistoryService: any VisitHistoryProviding
    let pinnedItemsService: any PinnedItemsProviding

    private let fileOperationQueue: FileOperationQueue

    private(set) var activePaneSide: PaneSide
    var previewVisible: Bool
    var sidebarVisible: Bool
    var clipboard: [URL]
    var clipboardOperation: ClipboardOperation?
    var undoManager: UndoManager?
    var requestTextInput: ((TextInputPrompt) -> String?)?
    var lastOperationError: String?
    var onFileOperationCompleted: ((FileOperationRecord, FileOperationCompletionContext) -> Void)?
    var onFileOperationFailed: ((String) -> Void)?

    init(
        fileSystemService: FileSystemProviding = FileSystemService(),
        securityScopedBookmarkService: any SecurityScopedBookmarkProviding = SecurityScopedBookmarkService.shared,
        fileOperationQueue: FileOperationQueue = FileOperationQueue(),
        visitHistoryService: any VisitHistoryProviding,
        pinnedItemsService: any PinnedItemsProviding,
        initialShowHiddenFiles: Bool = false,
        initialSortColumn: AppConfig.SortColumn = .name,
        initialSortAscending: Bool = true,
        initialPreviewVisible: Bool = false,
        initialSidebarVisible: Bool = true,
        initialTerminalPanelVisible: Bool = false,
        initialSpotlightSearchScope: SpotlightSearchScope = .currentDirectory,
        initialLeftPaneDisplayMode: PaneDisplayMode = .browser,
        initialRightPaneDisplayMode: PaneDisplayMode = .browser,
        initialLeftPaneMediaRecursiveEnabled: Bool = false,
        initialRightPaneMediaRecursiveEnabled: Bool = false,
        initialLeftDirectory: URL = UserPaths.homeDirectoryURL,
        initialRightDirectory: URL? = nil
    ) {
        self.securityScopedBookmarkService = securityScopedBookmarkService
        self.fileOperationQueue = fileOperationQueue
        self.visitHistoryService = visitHistoryService
        self.pinnedItemsService = pinnedItemsService

        let normalizedLeftDirectory = initialLeftDirectory.standardizedFileURL
        let normalizedRightDirectory = (initialRightDirectory ?? normalizedLeftDirectory).standardizedFileURL

        self.leftPane = FilePaneViewModel(
            fileSystemService: fileSystemService,
            securityScopedBookmarkService: securityScopedBookmarkService,
            initialSpotlightSearchScope: initialSpotlightSearchScope,
            initialDisplayMode: initialLeftPaneDisplayMode,
            initialMediaRecursiveEnabled: initialLeftPaneMediaRecursiveEnabled,
            initialDirectory: normalizedLeftDirectory
        )

        self.rightPane = FilePaneViewModel(
            fileSystemService: fileSystemService,
            securityScopedBookmarkService: securityScopedBookmarkService,
            initialSpotlightSearchScope: initialSpotlightSearchScope,
            initialDisplayMode: initialRightPaneDisplayMode,
            initialMediaRecursiveEnabled: initialRightPaneMediaRecursiveEnabled,
            initialDirectory: normalizedRightDirectory
        )

        self.terminalSessionListViewModel = TerminalSessionListViewModel(
            initialPanelVisible: initialTerminalPanelVisible
        )

        self.previewPane = PreviewViewModel()
        self.activePaneSide = .left
        self.previewVisible = initialPreviewVisible
        self.sidebarVisible = initialSidebarVisible
        self.clipboard = []
        self.clipboardOperation = nil
        self.undoManager = nil
        self.requestTextInput = nil
        self.lastOperationError = nil
        self.onFileOperationCompleted = nil
        self.onFileOperationFailed = nil

        leftPane.setShowHiddenFiles(initialShowHiddenFiles)
        rightPane.setShowHiddenFiles(initialShowHiddenFiles)

        let sortDescriptor = Self.sortDescriptor(for: initialSortColumn, ascending: initialSortAscending)
        leftPane.setSortDescriptor(sortDescriptor)
        rightPane.setSortDescriptor(sortDescriptor)
        refreshPreviewForActivePane()
    }

    var activePane: FilePaneViewModel {
        activePaneSide == .left ? leftPane : rightPane
    }

    var inactivePane: FilePaneViewModel {
        activePaneSide == .left ? rightPane : leftPane
    }

    func setActivePane(_ side: PaneSide) {
        activePaneSide = side
        refreshPreviewForActivePane()
    }

    func switchActivePane() {
        activePaneSide = activePaneSide == .left ? .right : .left
        refreshPreviewForActivePane()
    }

    func togglePreviewPane() {
        previewVisible.toggle()
    }

    func toggleSidebar() {
        sidebarVisible.toggle()
    }

    func setSpotlightSearchScope(_ scope: SpotlightSearchScope) {
        leftPane.setSpotlightSearchScope(scope)
        rightPane.setSpotlightSearchScope(scope)
    }

    @discardableResult
    func matchOtherPaneDirectoryToActivePane() -> Bool {
        let destinationDirectory = activePane.paneState.currentDirectory.standardizedFileURL
        let currentInactiveDirectory = inactivePane.paneState.currentDirectory.standardizedFileURL
        guard currentInactiveDirectory != destinationDirectory else {
            return false
        }

        inactivePane.navigate(to: destinationDirectory)
        return true
    }

    @discardableResult
    func moveActivePaneToOtherPaneDirectory() -> Bool {
        let destinationDirectory = inactivePane.paneState.currentDirectory.standardizedFileURL
        let currentActiveDirectory = activePane.paneState.currentDirectory.standardizedFileURL
        guard currentActiveDirectory != destinationDirectory else {
            return false
        }

        activePane.navigate(to: destinationDirectory)
        return true
    }

    @discardableResult
    func syncPanesLeftToRight() -> Bool {
        let leftDir = leftPane.paneState.currentDirectory.standardizedFileURL
        let rightDir = rightPane.paneState.currentDirectory.standardizedFileURL
        guard rightDir != leftDir else { return false }
        rightPane.navigate(to: leftDir)
        return true
    }

    @discardableResult
    func syncPanesRightToLeft() -> Bool {
        let rightDir = rightPane.paneState.currentDirectory.standardizedFileURL
        let leftDir = leftPane.paneState.currentDirectory.standardizedFileURL
        guard leftDir != rightDir else { return false }
        leftPane.navigate(to: rightDir)
        return true
    }

    func togglePinForActivePane() {
        let pane = activePane
        let url: URL
        let isDirectory: Bool
        if let selectedItem = pane.selectedItem {
            url = selectedItem.url.standardizedFileURL
            isDirectory = selectedItem.isDirectory
        } else {
            url = pane.paneState.currentDirectory.standardizedFileURL
            isDirectory = true
        }
        pinnedItemsService.togglePin(for: url, isDirectory: isDirectory)
    }

    func isPinnedActiveItem() -> Bool {
        let pane = activePane
        let path: String
        if let selectedItem = pane.selectedItem {
            path = selectedItem.url.standardizedFileURL.path
        } else {
            path = pane.paneState.currentDirectory.standardizedFileURL.path
        }
        return pinnedItemsService.isPinned(path: path)
    }

    func refreshPreviewForActivePane() {
        let pane = activePane
        previewPane.updateContext(
            selectedItem: pane.selectedItem,
            currentDirectoryURL: pane.paneState.currentDirectory,
            displayedItems: pane.directoryContents.displayedItems
        )
    }

    func updatePreviewSelection(for side: PaneSide) {
        guard activePaneSide == side else {
            return
        }
        refreshPreviewForActivePane()
    }

    func copyMarked() {
        let normalizedURLs = copyMarkedToClipboard()
        guard !normalizedURLs.isEmpty else {
            return
        }

        let destinationDirectory = inactivePane.paneState.currentDirectory.standardizedFileURL
        execute(
            operation: .copy(items: normalizedURLs, destinationDirectory: destinationDirectory),
            registerUndoWithManager: true,
            clearCutClipboardOnSuccess: false
        )
    }

    func cutMarked() {
        _ = cutMarkedToClipboard()
    }

    func paste() {
        let destinationDirectory = inactivePane.paneState.currentDirectory.standardizedFileURL
        paste(to: destinationDirectory)
    }

    @discardableResult
    func copyMarkedToClipboard() -> [URL] {
        stageClipboard(operation: .copy)
    }

    @discardableResult
    func cutMarkedToClipboard() -> [URL] {
        stageClipboard(operation: .cut)
    }

    func replaceClipboard(urls: [URL], operation: ClipboardOperation) {
        let normalizedURLs = urls.map(\.standardizedFileURL)
        guard !normalizedURLs.isEmpty else {
            clipboard.removeAll()
            clipboardOperation = nil
            return
        }

        clipboard = normalizedURLs
        clipboardOperation = operation
    }

    func pasteToActivePane() {
        let destinationDirectory = activePane.paneState.currentDirectory.standardizedFileURL
        paste(to: destinationDirectory)
    }

    func pasteToActivePaneAsMove() {
        let destinationDirectory = activePane.paneState.currentDirectory.standardizedFileURL
        paste(to: destinationDirectory, forceMoveFromCopy: true)
    }

    private func paste(to destinationDirectory: URL, forceMoveFromCopy: Bool = false) {
        guard !clipboard.isEmpty, let clipboardOperation else {
            return
        }

        let effectiveOperation: ClipboardOperation
        if forceMoveFromCopy, clipboardOperation == .copy {
            effectiveOperation = .cut
        } else {
            effectiveOperation = clipboardOperation
        }

        switch effectiveOperation {
        case .copy:
            execute(
                operation: .copy(items: clipboard, destinationDirectory: destinationDirectory),
                registerUndoWithManager: true,
                clearCutClipboardOnSuccess: false
            )
        case .cut:
            let items = clipboard.map { source in
                FileLocationChange(
                    source: source.standardizedFileURL,
                    destination: destinationDirectory
                        .appendingPathComponent(source.lastPathComponent, isDirectory: source.hasDirectoryPath)
                        .standardizedFileURL
                )
            }

            execute(
                operation: .move(items: items),
                registerUndoWithManager: true,
                clearCutClipboardOnSuccess: true
            )
        }
    }

    private func stageClipboard(operation: ClipboardOperation) -> [URL] {
        let urls = activePane.markedOrSelectedURLs()
        guard !urls.isEmpty else {
            return []
        }

        let normalizedURLs = urls.map(\.standardizedFileURL)
        clipboard = normalizedURLs
        clipboardOperation = operation
        return normalizedURLs
    }

    func deleteMarked() {
        delete(urls: activePane.markedOrSelectedURLs())
    }

    func delete(urls: [URL]) {
        let normalizedURLs = urls.map(\.standardizedFileURL)
        var seen: Set<URL> = []
        let uniqueURLs = normalizedURLs.filter { seen.insert($0).inserted }

        guard !uniqueURLs.isEmpty else {
            return
        }

        execute(operation: .trash(items: uniqueURLs), registerUndoWithManager: true, clearCutClipboardOnSuccess: false)
    }

    func rename() {
        guard let item = activePane.selectedItem else {
            return
        }

        let prompt = TextInputPrompt(
            title: "Rename",
            message: "Rename \(item.name)",
            defaultValue: item.name
        )

        guard
            let newName = requestTextInput?(prompt)?.trimmingCharacters(in: .whitespacesAndNewlines),
            !newName.isEmpty
        else {
            return
        }

        execute(
            operation: .rename(item: item.url, newName: newName),
            registerUndoWithManager: true,
            clearCutClipboardOnSuccess: false
        )
    }

    func createDirectory() {
        let prompt = TextInputPrompt(
            title: "Create Directory",
            message: "New directory name",
            defaultValue: "New Folder"
        )

        guard
            let name = requestTextInput?(prompt)?.trimmingCharacters(in: .whitespacesAndNewlines),
            !name.isEmpty
        else {
            return
        }

        execute(
            operation: .createDirectory(parentDirectory: activePane.paneState.currentDirectory, name: name),
            registerUndoWithManager: true,
            clearCutClipboardOnSuccess: false
        )
    }

    func executeBatchRename(renames: [FileLocationChange]) {
        guard !renames.isEmpty else { return }
        execute(
            operation: .batchRename(items: renames),
            registerUndoWithManager: true,
            clearCutClipboardOnSuccess: false
        )
    }

    func undo() {
        if let undoManager, undoManager.canUndo {
            undoManager.undo()
            return
        }

        Task { [weak self] in
            await self?.runQueueUndo(registerUndoWithManager: false)
        }
    }

    private func execute(
        operation: FileOperation,
        registerUndoWithManager: Bool,
        clearCutClipboardOnSuccess: Bool
    ) {
        Task { [weak self] in
            guard let self else {
                return
            }

            self.suspendDirectoryMonitoring()
            defer {
                self.resumeDirectoryMonitoring()
            }

            let stream = await self.fileOperationQueue.enqueue(operation: operation)
            await self.consume(
                stream: stream,
                registerUndoWithManager: registerUndoWithManager,
                clearCutClipboardOnSuccess: clearCutClipboardOnSuccess,
                completionContext: .normal
            )
        }
    }

    private func runQueueUndo(registerUndoWithManager: Bool) async {
        guard let stream = await fileOperationQueue.undo() else {
            return
        }

        suspendDirectoryMonitoring()
        defer {
            resumeDirectoryMonitoring()
        }

        await consume(
            stream: stream,
            registerUndoWithManager: registerUndoWithManager,
            clearCutClipboardOnSuccess: false,
            completionContext: .undo
        )
    }

    private func consume(
        stream: AsyncStream<OperationProgress>,
        registerUndoWithManager: Bool,
        clearCutClipboardOnSuccess: Bool,
        completionContext: FileOperationCompletionContext
    ) async {
        for await progress in stream {
            switch progress {
            case .progress:
                break
            case .completed(let record):
                lastOperationError = nil

                if registerUndoWithManager {
                    registerUndo(for: record)
                }

                if clearCutClipboardOnSuccess {
                    clipboard.removeAll()
                    clipboardOperation = nil
                }

                refreshPanesAfterFileOperation()
                onFileOperationCompleted?(record, completionContext)
            case .failed(let error):
                lastOperationError = error.message
                onFileOperationFailed?(error.message)
            }
        }
    }

    private func registerUndo(for record: FileOperationRecord) {
        guard let undoManager else {
            return
        }

        undoManager.registerUndo(withTarget: self) { target in
            target.performUndoFromUndoManager()
        }
        undoManager.setActionName(record.operation.type.undoActionName)
    }

    private func performUndoFromUndoManager() {
        Task { [weak self] in
            await self?.runQueueUndo(registerUndoWithManager: false)
        }
    }

    private func refreshPanesAfterFileOperation() {
        leftPane.refreshCurrentDirectory()
        rightPane.refreshCurrentDirectory()
    }

    private func suspendDirectoryMonitoring() {
        leftPane.suspendDirectoryMonitoring()
        rightPane.suspendDirectoryMonitoring()
    }

    private func resumeDirectoryMonitoring() {
        leftPane.resumeDirectoryMonitoring()
        rightPane.resumeDirectoryMonitoring()
    }

    private static func sortDescriptor(
        for column: AppConfig.SortColumn,
        ascending: Bool
    ) -> DirectoryContents.SortDescriptor {
        switch column {
        case .name:
            return .name(ascending: ascending)
        case .size:
            return .size(ascending: ascending)
        case .date:
            return .date(ascending: ascending)
        case .selection:
            return .selection(ascending: ascending)
        }
    }
}
