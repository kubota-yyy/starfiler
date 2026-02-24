import Foundation

actor FileOperationQueue {
    typealias FailureResolver = (_ context: FileOperationFailureContext) async -> FileOperationFailureDecision

    private let executor: any FileOperationExecuting
    private var undoStack: [FileOperationRecord]
    private var tailTask: Task<Void, Never>?
    private var activeOperations: [TaskCenterEntryID: Task<Void, Never>] = [:]

    init(executor: any FileOperationExecuting = FileOperationService()) {
        self.executor = executor
        self.undoStack = []
        self.tailTask = nil
    }

    var canUndo: Bool {
        !undoStack.isEmpty
    }

    func enqueue(
        operation: FileOperation,
        failureResolver: FailureResolver? = nil
    ) -> AsyncStream<OperationProgress> {
        schedule(operation: operation, trackUndo: true, failureResolver: failureResolver)
    }

    func enqueueTracked(
        operation: FileOperation,
        failureResolver: FailureResolver? = nil
    ) -> (entryID: TaskCenterEntryID, stream: AsyncStream<OperationProgress>) {
        let entryID = TaskCenterEntryID()
        let stream = scheduleTracked(
            entryID: entryID,
            operation: operation,
            trackUndo: true,
            failureResolver: failureResolver
        )
        return (entryID, stream)
    }

    func cancelOperation(id: TaskCenterEntryID) {
        activeOperations[id]?.cancel()
        activeOperations.removeValue(forKey: id)
    }

    func undo() -> AsyncStream<OperationProgress>? {
        guard canUndo else {
            return nil
        }

        return AsyncStream { continuation in
            let previousTask = tailTask
            let task = Task {
                _ = await previousTask?.result
                await self.performUndo(into: continuation)
            }
            tailTask = task
        }
    }

    private func schedule(
        operation: FileOperation,
        trackUndo: Bool,
        failureResolver: FailureResolver? = nil
    ) -> AsyncStream<OperationProgress> {
        AsyncStream { continuation in
            let previousTask = tailTask
            let task = Task {
                _ = await previousTask?.result
                await self.execute(
                    operation: operation,
                    trackUndo: trackUndo,
                    failureResolver: failureResolver,
                    into: continuation
                )
            }
            tailTask = task
        }
    }

    private func scheduleTracked(
        entryID: TaskCenterEntryID,
        operation: FileOperation,
        trackUndo: Bool,
        failureResolver: FailureResolver? = nil
    ) -> AsyncStream<OperationProgress> {
        AsyncStream { continuation in
            let previousTask = tailTask
            let task = Task {
                _ = await previousTask?.result
                await self.execute(
                    operation: operation,
                    trackUndo: trackUndo,
                    failureResolver: failureResolver,
                    into: continuation
                )
                await self.removeActiveOperation(id: entryID)
            }
            tailTask = task
            activeOperations[entryID] = task
        }
    }

    private func removeActiveOperation(id: TaskCenterEntryID) {
        activeOperations.removeValue(forKey: id)
    }

    private func performUndo(into continuation: AsyncStream<OperationProgress>.Continuation) async {
        guard !undoStack.isEmpty else {
            continuation.yield(.failed(error: FileOperationError(message: "Nothing to undo.")))
            continuation.finish()
            return
        }

        let record = undoStack.removeLast()
        await execute(
            operation: record.undoOperation,
            trackUndo: false,
            failureResolver: nil,
            into: continuation
        )
    }

    private func execute(
        operation: FileOperation,
        trackUndo: Bool,
        failureResolver: FailureResolver?,
        into continuation: AsyncStream<OperationProgress>.Continuation
    ) async {
        do {
            let record: FileOperationRecord
            if let failureResolver, let interactiveExecutor = executor as? any InteractiveFileOperationExecuting {
                record = try await interactiveExecutor.executeInteractive(
                    operation,
                    progress: { completed, total, currentFile in
                        continuation.yield(.progress(completed: completed, total: total, currentFile: currentFile))
                    },
                    resolveFailure: failureResolver
                )
            } else {
                record = try await executor.execute(operation) { completed, total, currentFile in
                    continuation.yield(.progress(completed: completed, total: total, currentFile: currentFile))
                }
            }

            if trackUndo {
                undoStack.append(record)
            }

            continuation.yield(.completed(record: record))
        } catch is CancellationError {
            continuation.yield(.cancelled)
        } catch {
            continuation.yield(.failed(error: FileOperationError(error)))
        }

        continuation.finish()
    }
}
