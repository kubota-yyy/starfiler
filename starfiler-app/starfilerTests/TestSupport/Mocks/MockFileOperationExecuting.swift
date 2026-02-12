import Foundation
@testable import Starfiler

final class MockFileOperationExecuting: FileOperationExecuting, @unchecked Sendable {
    // MARK: - execute

    var executeResult: Result<FileOperationRecord, Error> = .success(
        FileOperationRecord(
            operation: .trash(items: []),
            result: .trashed([]),
            timestamp: Date(),
            undoOperation: .trash(items: [])
        )
    )
    private(set) var executeCallCount = 0
    private(set) var executeCapturedOperations: [FileOperation] = []

    func execute(
        _ operation: FileOperation,
        progress: @escaping @Sendable (_ completed: Int, _ total: Int, _ currentFile: URL) -> Void
    ) async throws -> FileOperationRecord {
        executeCallCount += 1
        executeCapturedOperations.append(operation)
        return try executeResult.get()
    }
}
