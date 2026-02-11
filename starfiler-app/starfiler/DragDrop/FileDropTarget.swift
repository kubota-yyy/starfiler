import AppKit

final class FileDropTarget: NSObject {
    private let fileOperationService: any FileOperationExecuting
    private let destinationDirectoryProvider: () -> URL

    var onHighlightChanged: ((Bool) -> Void)?
    var onDropCompleted: ((NSDragOperation, Int) -> Void)?
    var onDropFailed: ((String) -> Void)?

    init(
        fileOperationService: any FileOperationExecuting = FileOperationService(),
        destinationDirectoryProvider: @escaping () -> URL
    ) {
        self.fileOperationService = fileOperationService
        self.destinationDirectoryProvider = destinationDirectoryProvider
    }

    func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard canReadFileURLs(from: sender) else {
            onHighlightChanged?(false)
            return []
        }

        onHighlightChanged?(true)
        return operation(for: sender)
    }

    func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard canReadFileURLs(from: sender) else {
            onHighlightChanged?(false)
            return []
        }

        onHighlightChanged?(true)
        return operation(for: sender)
    }

    func draggingExited(_ sender: NSDraggingInfo?) {
        onHighlightChanged?(false)
    }

    func concludeDragOperation(_ sender: NSDraggingInfo?) {
        onHighlightChanged?(false)
    }

    func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        canReadFileURLs(from: sender)
    }

    func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let droppedURLs = fileURLs(from: sender), !droppedURLs.isEmpty else {
            onHighlightChanged?(false)
            return false
        }

        let resolvedOperation = operation(for: sender)
        guard resolvedOperation == .copy || resolvedOperation == .move else {
            onHighlightChanged?(false)
            return false
        }

        let uniqueURLs = Array(Set(droppedURLs.map(\.standardizedFileURL))).sorted { $0.path < $1.path }

        Task { [weak self] in
            guard let self else {
                return
            }

            let destinationDirectory = await MainActor.run { destinationDirectoryProvider().standardizedFileURL }

            // Skip when all files are already in the destination directory
            let allAlreadyInDestination = uniqueURLs.allSatisfy {
                $0.deletingLastPathComponent().standardizedFileURL == destinationDirectory
            }
            if allAlreadyInDestination {
                await MainActor.run { self.onHighlightChanged?(false) }
                return
            }

            let fileOperation: FileOperation

            if resolvedOperation == .move {
                let changes = uniqueURLs.map { sourceURL in
                    FileLocationChange(
                        source: sourceURL,
                        destination: destinationDirectory
                            .appendingPathComponent(sourceURL.lastPathComponent, isDirectory: sourceURL.hasDirectoryPath)
                            .standardizedFileURL
                    )
                }
                fileOperation = .move(items: changes)
            } else {
                fileOperation = .copy(items: uniqueURLs, destinationDirectory: destinationDirectory)
            }

            do {
                _ = try await self.fileOperationService.execute(fileOperation) { _, _, _ in }

                await MainActor.run {
                    self.onHighlightChanged?(false)
                    self.onDropCompleted?(resolvedOperation, uniqueURLs.count)
                }
            } catch {
                await MainActor.run {
                    self.onHighlightChanged?(false)
                    self.onDropFailed?(error.localizedDescription)
                }
            }
        }

        return true
    }

    private func operation(for sender: NSDraggingInfo) -> NSDragOperation {
        let sourceMask = sender.draggingSourceOperationMask
        let optionPressed = NSApp.currentEvent?.modifierFlags.contains(.option) == true

        if optionPressed, sourceMask.contains(.move) {
            return .move
        }

        if sourceMask.contains(.copy) {
            return .copy
        }

        if sourceMask.contains(.move) {
            return .move
        }

        return []
    }

    private func canReadFileURLs(from sender: NSDraggingInfo) -> Bool {
        fileURLs(from: sender)?.isEmpty == false
    }

    private func fileURLs(from sender: NSDraggingInfo) -> [URL]? {
        sender.draggingPasteboard.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        ) as? [URL]
    }
}
