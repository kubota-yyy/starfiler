import Foundation

struct TaskCenterEntryID: Hashable, Sendable {
    let rawValue: UUID

    init() {
        self.rawValue = UUID()
    }
}

enum TaskCenterEntryStatus: Sendable {
    case running(completed: Int, total: Int, currentFile: URL)
    case completed(record: FileOperationRecord)
    case failed(error: String, detail: TaskCenterErrorDetail)
    case cancelled
}

struct TaskCenterErrorDetail: Hashable, Sendable {
    let operationType: FileOperationType
    let sourceURLs: [URL]
    let destinationURL: URL?
    let errorMessage: String
    let timestamp: Date
    let appVersion: String
    let macOSVersion: String

    var copyableText: String {
        var lines: [String] = []
        lines.append("--- Starfiler Error Report ---")
        lines.append("Timestamp: \(ISO8601DateFormatter().string(from: timestamp))")
        lines.append("App: \(appVersion)")
        lines.append("macOS: \(macOSVersion)")
        lines.append("Operation: \(operationType.rawValue)")
        for url in sourceURLs {
            lines.append("Source: \(url.path)")
        }
        if let dest = destinationURL {
            lines.append("Destination: \(dest.path)")
        }
        lines.append("Error: \(errorMessage)")
        lines.append("--- End Report ---")
        return lines.joined(separator: "\n")
    }
}

struct TaskCenterEntry: Identifiable, Sendable {
    let id: TaskCenterEntryID
    let operation: FileOperation
    let startedAt: Date
    var status: TaskCenterEntryStatus

    var isTerminal: Bool {
        switch status {
        case .running:
            return false
        case .completed, .failed, .cancelled:
            return true
        }
    }

    var displayTitle: String {
        switch operation.type {
        case .copy:
            return "Copy"
        case .move:
            return "Move"
        case .trash:
            return "Delete"
        case .rename:
            return "Rename"
        case .createDirectory:
            return "Create Folder"
        case .batchRename:
            return "Batch Rename"
        }
    }
}
