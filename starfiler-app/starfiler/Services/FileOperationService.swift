import AppKit
import Foundation

protocol FileOperationExecuting: Sendable {
    func execute(
        _ operation: FileOperation,
        progress: @escaping @Sendable (_ completed: Int, _ total: Int, _ currentFile: URL) -> Void
    ) async throws -> FileOperationRecord
}

enum FileOperationServiceError: LocalizedError, Sendable {
    case noItems
    case invalidName
    case destinationAlreadyExists(URL)
    case recycleDestinationNotFound(URL)

    var errorDescription: String? {
        switch self {
        case .noItems:
            return "No files were selected for this operation."
        case .invalidName:
            return "The provided name is invalid."
        case .destinationAlreadyExists(let url):
            return "A file already exists at \(url.path)."
        case .recycleDestinationNotFound(let url):
            return "Failed to resolve recycle destination for \(url.path)."
        }
    }
}

struct FileOperationService: FileOperationExecuting {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func execute(
        _ operation: FileOperation,
        progress: @escaping @Sendable (_ completed: Int, _ total: Int, _ currentFile: URL) -> Void
    ) async throws -> FileOperationRecord {
        switch operation {
        case .copy(let items, let destinationDirectory):
            return try executeCopy(items: items, destinationDirectory: destinationDirectory, progress: progress)
        case .move(let items):
            return try executeMove(items: items, progress: progress)
        case .trash(let items):
            return try await executeTrash(items: items, progress: progress)
        case .rename(let item, let newName):
            return try executeRename(item: item, newName: newName, progress: progress)
        case .createDirectory(let parentDirectory, let name):
            return try executeCreateDirectory(parentDirectory: parentDirectory, name: name, progress: progress)
        case .batchRename(let items):
            return try executeBatchRename(items: items, progress: progress)
        }
    }

    private func executeCopy(
        items: [URL],
        destinationDirectory: URL,
        progress: @escaping @Sendable (_ completed: Int, _ total: Int, _ currentFile: URL) -> Void
    ) throws -> FileOperationRecord {
        guard !items.isEmpty else {
            throw FileOperationServiceError.noItems
        }

        let normalizedDirectory = destinationDirectory.standardizedFileURL
        var changes: [FileLocationChange] = []
        changes.reserveCapacity(items.count)

        for (index, source) in items.enumerated() {
            let normalizedSource = source.standardizedFileURL
            let destination = uniqueDestinationURL(for: normalizedSource, destinationDirectory: normalizedDirectory)
            try fileManager.copyItem(at: normalizedSource, to: destination)

            changes.append(FileLocationChange(source: normalizedSource, destination: destination))
            progress(index + 1, items.count, normalizedSource)
        }

        let undo = FileOperation.trash(items: changes.map(\.destination))

        return FileOperationRecord(
            operation: .copy(items: items, destinationDirectory: normalizedDirectory),
            result: .copied(changes),
            timestamp: Date(),
            undoOperation: undo
        )
    }

    private func executeMove(
        items: [FileLocationChange],
        progress: @escaping @Sendable (_ completed: Int, _ total: Int, _ currentFile: URL) -> Void
    ) throws -> FileOperationRecord {
        guard !items.isEmpty else {
            throw FileOperationServiceError.noItems
        }

        var movedChanges: [FileLocationChange] = []
        movedChanges.reserveCapacity(items.count)

        for (index, item) in items.enumerated() {
            let source = item.source.standardizedFileURL
            let requestedDestination = item.destination.standardizedFileURL

            if source == requestedDestination {
                progress(index + 1, items.count, source)
                continue
            }

            let resolvedDestination = uniqueDestinationURL(for: requestedDestination)
            try fileManager.moveItem(at: source, to: resolvedDestination)

            movedChanges.append(FileLocationChange(source: source, destination: resolvedDestination))
            progress(index + 1, items.count, source)
        }

        let undoMappings = movedChanges.map {
            FileLocationChange(source: $0.destination, destination: $0.source)
        }

        return FileOperationRecord(
            operation: .move(items: items),
            result: .moved(movedChanges),
            timestamp: Date(),
            undoOperation: .move(items: undoMappings)
        )
    }

    private func executeTrash(
        items: [URL],
        progress: @escaping @Sendable (_ completed: Int, _ total: Int, _ currentFile: URL) -> Void
    ) async throws -> FileOperationRecord {
        guard !items.isEmpty else {
            throw FileOperationServiceError.noItems
        }

        var trashedChanges: [FileLocationChange] = []
        trashedChanges.reserveCapacity(items.count)

        for (index, source) in items.enumerated() {
            let normalizedSource = source.standardizedFileURL
            let recycledURL = try await recycle(url: normalizedSource)

            trashedChanges.append(FileLocationChange(source: normalizedSource, destination: recycledURL))
            progress(index + 1, items.count, normalizedSource)
        }

        let undoMappings = trashedChanges.map {
            FileLocationChange(source: $0.destination, destination: $0.source)
        }

        return FileOperationRecord(
            operation: .trash(items: items),
            result: .trashed(trashedChanges),
            timestamp: Date(),
            undoOperation: .move(items: undoMappings)
        )
    }

    private func executeRename(
        item: URL,
        newName: String,
        progress: @escaping @Sendable (_ completed: Int, _ total: Int, _ currentFile: URL) -> Void
    ) throws -> FileOperationRecord {
        let normalizedItem = item.standardizedFileURL
        let trimmedName = newName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedName.isEmpty else {
            throw FileOperationServiceError.invalidName
        }

        let destination = normalizedItem
            .deletingLastPathComponent()
            .appendingPathComponent(trimmedName, isDirectory: normalizedItem.hasDirectoryPath)
            .standardizedFileURL

        guard destination != normalizedItem else {
            progress(1, 1, normalizedItem)
            return FileOperationRecord(
                operation: .rename(item: normalizedItem, newName: trimmedName),
                result: .renamed(FileLocationChange(source: normalizedItem, destination: normalizedItem)),
                timestamp: Date(),
                undoOperation: .rename(item: normalizedItem, newName: normalizedItem.lastPathComponent)
            )
        }

        if fileManager.fileExists(atPath: destination.path) {
            throw FileOperationServiceError.destinationAlreadyExists(destination)
        }

        try fileManager.moveItem(at: normalizedItem, to: destination)
        progress(1, 1, normalizedItem)

        return FileOperationRecord(
            operation: .rename(item: normalizedItem, newName: trimmedName),
            result: .renamed(FileLocationChange(source: normalizedItem, destination: destination)),
            timestamp: Date(),
            undoOperation: .rename(item: destination, newName: normalizedItem.lastPathComponent)
        )
    }

    private func executeCreateDirectory(
        parentDirectory: URL,
        name: String,
        progress: @escaping @Sendable (_ completed: Int, _ total: Int, _ currentFile: URL) -> Void
    ) throws -> FileOperationRecord {
        let normalizedParent = parentDirectory.standardizedFileURL
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedName.isEmpty else {
            throw FileOperationServiceError.invalidName
        }

        let directoryURL = normalizedParent
            .appendingPathComponent(trimmedName, isDirectory: true)
            .standardizedFileURL

        guard !fileManager.fileExists(atPath: directoryURL.path) else {
            throw FileOperationServiceError.destinationAlreadyExists(directoryURL)
        }

        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: false)
        progress(1, 1, directoryURL)

        return FileOperationRecord(
            operation: .createDirectory(parentDirectory: normalizedParent, name: trimmedName),
            result: .createdDirectory(directoryURL),
            timestamp: Date(),
            undoOperation: .trash(items: [directoryURL])
        )
    }

    private func executeBatchRename(
        items: [FileLocationChange],
        progress: @escaping @Sendable (_ completed: Int, _ total: Int, _ currentFile: URL) -> Void
    ) throws -> FileOperationRecord {
        guard !items.isEmpty else {
            throw FileOperationServiceError.noItems
        }

        var completedChanges: [FileLocationChange] = []
        completedChanges.reserveCapacity(items.count)

        // Detect rename chains/cycles and use temp names to avoid conflicts.
        // Build a set of destinations that are also sources in this batch.
        let sourceSet = Set(items.map { $0.source.standardizedFileURL })
        let destSet = Set(items.map { $0.destination.standardizedFileURL })
        let conflicting = sourceSet.intersection(destSet)

        // Phase 1: Move conflicting sources to temp names
        var tempMappings: [URL: URL] = [:]
        if !conflicting.isEmpty {
            for item in items {
                let source = item.source.standardizedFileURL
                if conflicting.contains(source) && source != item.destination.standardizedFileURL {
                    let tempName = ".starfiler_tmp_\(UUID().uuidString)_\(source.lastPathComponent)"
                    let tempURL = source.deletingLastPathComponent()
                        .appendingPathComponent(tempName)
                        .standardizedFileURL
                    try fileManager.moveItem(at: source, to: tempURL)
                    tempMappings[source] = tempURL
                }
            }
        }

        // Phase 2: Execute renames (using temp paths where needed)
        for (index, item) in items.enumerated() {
            let source = item.source.standardizedFileURL
            let destination = item.destination.standardizedFileURL

            guard source != destination else {
                progress(index + 1, items.count, source)
                continue
            }

            let actualSource = tempMappings[source] ?? source

            try fileManager.moveItem(at: actualSource, to: destination)
            completedChanges.append(FileLocationChange(source: source, destination: destination))
            progress(index + 1, items.count, source)
        }

        let undoItems = completedChanges.map {
            FileLocationChange(source: $0.destination, destination: $0.source)
        }

        return FileOperationRecord(
            operation: .batchRename(items: items),
            result: .batchRenamed(completedChanges),
            timestamp: Date(),
            undoOperation: .batchRename(items: undoItems)
        )
    }

    private func recycle(url: URL) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            NSWorkspace.shared.recycle([url]) { recycledBySource, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                if let recycledURL = recycledBySource[url] ?? recycledBySource.values.first {
                    continuation.resume(returning: recycledURL)
                    return
                }

                continuation.resume(throwing: FileOperationServiceError.recycleDestinationNotFound(url))
            }
        }
    }

    private func uniqueDestinationURL(for source: URL, destinationDirectory: URL) -> URL {
        let proposed = destinationDirectory
            .appendingPathComponent(source.lastPathComponent, isDirectory: source.hasDirectoryPath)
            .standardizedFileURL
        return uniqueDestinationURL(for: proposed)
    }

    private func uniqueDestinationURL(for proposed: URL) -> URL {
        if !fileManager.fileExists(atPath: proposed.path) {
            return proposed
        }

        let directory = proposed.deletingLastPathComponent()
        let `extension` = proposed.pathExtension
        let baseName = proposed.deletingPathExtension().lastPathComponent

        var candidateIndex = 1

        while true {
            let suffix = candidateIndex == 1 ? " copy" : " copy \(candidateIndex)"
            let candidateName = baseName + suffix
            let candidateURL: URL

            if `extension`.isEmpty {
                candidateURL = directory.appendingPathComponent(candidateName, isDirectory: proposed.hasDirectoryPath)
            } else {
                candidateURL = directory
                    .appendingPathComponent(candidateName)
                    .appendingPathExtension(`extension`)
            }

            if !fileManager.fileExists(atPath: candidateURL.path) {
                return candidateURL.standardizedFileURL
            }

            candidateIndex += 1
        }
    }
}

extension FileOperationService: @unchecked Sendable {}
