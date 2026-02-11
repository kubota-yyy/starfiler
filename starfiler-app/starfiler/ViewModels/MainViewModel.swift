import Foundation
import Observation

enum ClipboardOperation: Sendable {
    case copy
    case cut
}

struct TextInputPrompt {
    let title: String
    let message: String
    let defaultValue: String?
}

@MainActor
@Observable
final class MainViewModel {
    let leftPane: FilePaneViewModel
    let rightPane: FilePaneViewModel
    let previewPane: PreviewViewModel
    let securityScopedBookmarkService: any SecurityScopedBookmarkProviding

    private let fileOperationQueue: FileOperationQueue

    private(set) var activePaneSide: PaneSide
    var previewVisible: Bool
    var clipboard: [URL]
    var clipboardOperation: ClipboardOperation?
    var undoManager: UndoManager?
    var requestTextInput: ((TextInputPrompt) -> String?)?
    var lastOperationError: String?

    init(
        fileSystemService: FileSystemProviding = FileSystemService(),
        securityScopedBookmarkService: any SecurityScopedBookmarkProviding = SecurityScopedBookmarkService.shared,
        fileOperationQueue: FileOperationQueue = FileOperationQueue(),
        initialShowHiddenFiles: Bool = false,
        initialSortColumn: AppConfig.SortColumn = .name,
        initialSortAscending: Bool = true,
        initialPreviewVisible: Bool = true,
        initialLeftDirectory: URL = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true),
        initialRightDirectory: URL? = nil
    ) {
        self.securityScopedBookmarkService = securityScopedBookmarkService
        self.fileOperationQueue = fileOperationQueue

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

        self.previewPane = PreviewViewModel()
        self.activePaneSide = .left
        self.previewVisible = initialPreviewVisible
        self.clipboard = []
        self.clipboardOperation = nil
        self.undoManager = nil
        self.requestTextInput = nil
        self.lastOperationError = nil

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

    func refreshPreviewForActivePane() {
        previewPane.currentURL = activePane.selectedItem?.url
    }

    func updatePreviewSelection(for side: PaneSide, selectedItem: FileItem?) {
        guard activePaneSide == side else {
            return
        }

        previewPane.currentURL = selectedItem?.url
    }

    func copyMarked() {
        let urls = activePane.markedOrSelectedURLs()
        guard !urls.isEmpty else {
            return
        }

        clipboard = urls.map(\.standardizedFileURL)
        clipboardOperation = .copy
    }

    func cutMarked() {
        let urls = activePane.markedOrSelectedURLs()
        guard !urls.isEmpty else {
            return
        }

        clipboard = urls.map(\.standardizedFileURL)
        clipboardOperation = .cut
    }

    func paste() {
        guard !clipboard.isEmpty, let clipboardOperation else {
            return
        }

        let destinationDirectory = inactivePane.paneState.currentDirectory.standardizedFileURL

        switch clipboardOperation {
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

    func deleteMarked() {
        let urls = activePane.markedOrSelectedURLs()
        guard !urls.isEmpty else {
            return
        }

        execute(operation: .trash(items: urls), registerUndoWithManager: true, clearCutClipboardOnSuccess: false)
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
                clearCutClipboardOnSuccess: clearCutClipboardOnSuccess
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
            clearCutClipboardOnSuccess: false
        )
    }

    private func consume(
        stream: AsyncStream<OperationProgress>,
        registerUndoWithManager: Bool,
        clearCutClipboardOnSuccess: Bool
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
            case .failed(let error):
                lastOperationError = error.message
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
        }
    }
}
