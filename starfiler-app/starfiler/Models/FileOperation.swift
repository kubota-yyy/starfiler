import Foundation

enum FileOperationType: String, Sendable {
    case copy
    case move
    case trash
    case rename
    case createDirectory
    case batchRename

    var undoActionName: String {
        switch self {
        case .copy:
            return "Undo Copy"
        case .move:
            return "Undo Move"
        case .trash:
            return "Undo Delete"
        case .rename:
            return "Undo Rename"
        case .createDirectory:
            return "Undo Create Folder"
        case .batchRename:
            return "Undo Batch Rename"
        }
    }
}

struct FileLocationChange: Hashable, Sendable {
    let source: URL
    let destination: URL
}

enum FileOperation: Hashable, Sendable {
    case copy(items: [URL], destinationDirectory: URL)
    case move(items: [FileLocationChange])
    case trash(items: [URL])
    case rename(item: URL, newName: String)
    case createDirectory(parentDirectory: URL, name: String)
    case batchRename(items: [FileLocationChange])

    var type: FileOperationType {
        switch self {
        case .copy:
            return .copy
        case .move:
            return .move
        case .trash:
            return .trash
        case .rename:
            return .rename
        case .createDirectory:
            return .createDirectory
        case .batchRename:
            return .batchRename
        }
    }

    var totalUnitCount: Int {
        switch self {
        case .copy(let items, _):
            return items.count
        case .move(let items):
            return items.count
        case .trash(let items):
            return items.count
        case .rename:
            return 1
        case .createDirectory:
            return 1
        case .batchRename(let items):
            return items.count
        }
    }
}

enum FileOperationResult: Hashable, Sendable {
    case copied([FileLocationChange])
    case moved([FileLocationChange])
    case trashed([FileLocationChange])
    case renamed(FileLocationChange)
    case createdDirectory(URL)
    case batchRenamed([FileLocationChange])

    var affectedURLs: [URL] {
        switch self {
        case .copied(let changes):
            return changes.map(\.destination)
        case .moved(let changes):
            return changes.map(\.destination)
        case .trashed(let changes):
            return changes.map(\.destination)
        case .renamed(let change):
            return [change.destination]
        case .createdDirectory(let url):
            return [url]
        case .batchRenamed(let changes):
            return changes.map(\.destination)
        }
    }
}

struct FileOperationRecord: Hashable, Sendable {
    let operation: FileOperation
    let result: FileOperationResult
    let timestamp: Date
    let undoOperation: FileOperation
}

struct FileOperationError: LocalizedError, Hashable, Sendable {
    let message: String

    init(message: String) {
        self.message = message
    }

    init(_ error: any Error) {
        self.message = error.localizedDescription
    }

    var errorDescription: String? {
        message
    }
}

struct FileOperationFailureContext: Hashable, Sendable {
    let operationType: FileOperationType
    let sourceURL: URL
    let destinationURL: URL?
    let message: String
}

enum FileOperationFailureAction: String, Hashable, Sendable {
    case retry
    case skip
    case abort
}

struct FileOperationFailureDecision: Hashable, Sendable {
    let action: FileOperationFailureAction
    let applyToRemaining: Bool
}

enum OperationProgress: Sendable {
    case progress(completed: Int, total: Int, currentFile: URL)
    case completed(record: FileOperationRecord)
    case failed(error: FileOperationError)
    case cancelled
}
