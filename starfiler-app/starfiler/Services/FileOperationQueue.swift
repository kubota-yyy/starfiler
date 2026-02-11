import Foundation

actor FileOperationQueue {
    private let executor: any FileOperationExecuting
    private var undoStack: [FileOperationRecord]
    private var tailTask: Task<Void, Never>?

    init(executor: any FileOperationExecuting = FileOperationService()) {
        self.executor = executor
        self.undoStack = []
        self.tailTask = nil
    }

    var canUndo: Bool {
        !undoStack.isEmpty
    }

    func enqueue(operation: FileOperation) -> AsyncStream<OperationProgress> {
        schedule(operation: operation, trackUndo: true)
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

    private func schedule(operation: FileOperation, trackUndo: Bool) -> AsyncStream<OperationProgress> {
        AsyncStream { continuation in
            let previousTask = tailTask
            let task = Task {
                _ = await previousTask?.result
                await self.execute(operation: operation, trackUndo: trackUndo, into: continuation)
            }
            tailTask = task
        }
    }

    private func performUndo(into continuation: AsyncStream<OperationProgress>.Continuation) async {
        guard !undoStack.isEmpty else {
            continuation.yield(.failed(error: FileOperationError(message: "Nothing to undo.")))
            continuation.finish()
            return
        }

        let record = undoStack.removeLast()
        await execute(operation: record.undoOperation, trackUndo: false, into: continuation)
    }

    private func execute(
        operation: FileOperation,
        trackUndo: Bool,
        into continuation: AsyncStream<OperationProgress>.Continuation
    ) async {
        do {
            let record = try await executor.execute(operation) { completed, total, currentFile in
                continuation.yield(.progress(completed: completed, total: total, currentFile: currentFile))
            }

            if trackUndo {
                undoStack.append(record)
            }

            continuation.yield(.completed(record: record))
        } catch {
            continuation.yield(.failed(error: FileOperationError(error)))
        }

        continuation.finish()
    }
}
