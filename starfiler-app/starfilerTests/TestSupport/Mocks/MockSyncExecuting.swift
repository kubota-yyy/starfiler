import Foundation
@testable import Starfiler

final class MockSyncExecuting: SyncExecuting, @unchecked Sendable {
    // MARK: - execute

    var executeResult: Result<SyncExecutionResult, Error> = .success(
        SyncExecutionResult(copiedCount: 0, deletedCount: 0, skippedCount: 0, errors: [])
    )
    private(set) var executeCallCount = 0
    private(set) var executeCapturedArgs: [(
        items: [SyncItem],
        leftBase: URL,
        rightBase: URL
    )] = []

    func execute(
        items: [SyncItem],
        leftBase: URL,
        rightBase: URL,
        progress: @escaping @Sendable (_ completed: Int, _ total: Int, _ currentFile: String) -> Void
    ) async throws -> SyncExecutionResult {
        executeCallCount += 1
        executeCapturedArgs.append((items, leftBase, rightBase))
        return try executeResult.get()
    }
}
