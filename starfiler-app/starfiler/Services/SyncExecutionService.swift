import Foundation

protocol SyncExecuting: Sendable {
    func execute(
        items: [SyncItem],
        leftBase: URL,
        rightBase: URL,
        progress: @escaping @Sendable (_ completed: Int, _ total: Int, _ currentFile: String) -> Void
    ) async throws -> SyncExecutionResult
}

struct SyncExecutionService: SyncExecuting {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func execute(
        items: [SyncItem],
        leftBase: URL,
        rightBase: URL,
        progress: @escaping @Sendable (_ completed: Int, _ total: Int, _ currentFile: String) -> Void
    ) async throws -> SyncExecutionResult {
        let actionableItems = items.filter { $0.isSelected && $0.action != .skip }
        guard !actionableItems.isEmpty else {
            return SyncExecutionResult(copiedCount: 0, deletedCount: 0, skippedCount: items.count, errors: [])
        }

        // Sort: directories first (for mkdir), delete actions last
        let sorted = actionableItems.sorted { a, b in
            let aIsDelete = a.action == .deleteFromLeft || a.action == .deleteFromRight
            let bIsDelete = b.action == .deleteFromLeft || b.action == .deleteFromRight
            if aIsDelete != bIsDelete { return !aIsDelete }
            if a.isDirectory != b.isDirectory { return a.isDirectory }
            return a.relativePath < b.relativePath
        }

        let total = sorted.count
        var copiedCount = 0
        var deletedCount = 0
        var errors: [SyncError] = []

        for (index, item) in sorted.enumerated() {
            try Task.checkCancellation()
            progress(index, total, item.relativePath)

            do {
                switch item.action {
                case .copyToRight:
                    guard let sourceURL = item.leftURL else { continue }
                    let destURL = rightBase.appendingPathComponent(item.relativePath)
                    try copyFile(from: sourceURL, to: destURL, isDirectory: item.isDirectory)
                    copiedCount += 1

                case .copyToLeft:
                    guard let sourceURL = item.rightURL else { continue }
                    let destURL = leftBase.appendingPathComponent(item.relativePath)
                    try copyFile(from: sourceURL, to: destURL, isDirectory: item.isDirectory)
                    copiedCount += 1

                case .deleteFromLeft:
                    guard let url = item.leftURL else { continue }
                    try fileManager.trashItem(at: url, resultingItemURL: nil)
                    deletedCount += 1

                case .deleteFromRight:
                    guard let url = item.rightURL else { continue }
                    try fileManager.trashItem(at: url, resultingItemURL: nil)
                    deletedCount += 1

                case .skip:
                    break
                }
            } catch {
                errors.append(SyncError(relativePath: item.relativePath, message: error.localizedDescription))
            }
        }

        progress(total, total, "")

        let skipped = items.count - copiedCount - deletedCount - errors.count
        return SyncExecutionResult(
            copiedCount: copiedCount,
            deletedCount: deletedCount,
            skippedCount: skipped,
            errors: errors
        )
    }

    private func copyFile(from source: URL, to destination: URL, isDirectory: Bool) throws {
        let destDir = destination.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: destDir.path) {
            try fileManager.createDirectory(at: destDir, withIntermediateDirectories: true)
        }

        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }

        if isDirectory {
            if !fileManager.fileExists(atPath: destination.path) {
                try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)
            }
        } else {
            try fileManager.copyItem(at: source, to: destination)
        }
    }
}

extension SyncExecutionService: @unchecked Sendable {}
