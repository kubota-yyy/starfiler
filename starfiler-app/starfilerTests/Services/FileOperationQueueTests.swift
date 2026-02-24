import XCTest
@testable import Starfiler

final class FileOperationQueueTests: XCTestCase {

    // MARK: - Helpers

    private func makeMockExecutor() -> MockFileOperationExecuting {
        MockFileOperationExecuting()
    }

    private func makeSUT(executor: MockFileOperationExecuting? = nil) -> (FileOperationQueue, MockFileOperationExecuting) {
        let mock = executor ?? makeMockExecutor()
        let queue = FileOperationQueue(executor: mock)
        return (queue, mock)
    }

    // MARK: - Tests

    func testEnqueueExecutesOperation() async {
        let (sut, mock) = makeSUT()
        let trashURL = URL(fileURLWithPath: "/tmp/test/file.txt")
        mock.executeResult = .success(
            FileOperationRecord(
                operation: .trash(items: [trashURL]),
                result: .trashed([FileLocationChange(source: trashURL, destination: trashURL)]),
                timestamp: Date(),
                undoOperation: .trash(items: [])
            )
        )

        let stream = await sut.enqueue(operation: .trash(items: [trashURL]))

        var completedRecord: FileOperationRecord?
        for await progress in stream {
            if case .completed(let record) = progress {
                completedRecord = record
            }
        }

        XCTAssertNotNil(completedRecord)
        XCTAssertEqual(mock.executeCallCount, 1)
    }

    func testEnqueueReportsFailure() async {
        let (sut, mock) = makeSUT()
        mock.executeResult = .failure(NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Test failure"]))

        let stream = await sut.enqueue(operation: .trash(items: [URL(fileURLWithPath: "/tmp/file")]))

        var failedMessage: String?
        for await progress in stream {
            if case .failed(let error) = progress {
                failedMessage = error.message
            }
        }

        XCTAssertNotNil(failedMessage)
    }

    func testUndoAfterEnqueue() async {
        let (sut, mock) = makeSUT()
        let trashURL = URL(fileURLWithPath: "/tmp/test/file.txt")
        let undoOperation = FileOperation.trash(items: [])
        mock.executeResult = .success(
            FileOperationRecord(
                operation: .trash(items: [trashURL]),
                result: .trashed([FileLocationChange(source: trashURL, destination: trashURL)]),
                timestamp: Date(),
                undoOperation: undoOperation
            )
        )

        // Enqueue and consume first operation
        let stream = await sut.enqueue(operation: .trash(items: [trashURL]))
        for await _ in stream {}

        XCTAssertEqual(mock.executeCallCount, 1)
        let canUndo = await sut.canUndo
        XCTAssertTrue(canUndo)

        // Perform undo
        let undoStream = await sut.undo()
        XCTAssertNotNil(undoStream)

        if let undoStream {
            for await _ in undoStream {}
        }

        XCTAssertEqual(mock.executeCallCount, 2)
    }

    func testUndoWithNoHistoryReturnsNil() async {
        let (sut, _) = makeSUT()

        let canUndo = await sut.canUndo
        XCTAssertFalse(canUndo)

        let stream = await sut.undo()
        XCTAssertNil(stream)
    }

    func testSequentialEnqueuePreservesOrder() async {
        let (sut, mock) = makeSUT()

        var executedOperations: [FileOperation] = []
        let url1 = URL(fileURLWithPath: "/tmp/file1")
        let url2 = URL(fileURLWithPath: "/tmp/file2")

        mock.executeResult = .success(
            FileOperationRecord(
                operation: .trash(items: [url1]),
                result: .trashed([]),
                timestamp: Date(),
                undoOperation: .trash(items: [])
            )
        )

        let stream1 = await sut.enqueue(operation: .trash(items: [url1]))
        let stream2 = await sut.enqueue(operation: .trash(items: [url2]))

        for await progress in stream1 {
            if case .completed = progress {
                executedOperations.append(.trash(items: [url1]))
            }
        }

        for await progress in stream2 {
            if case .completed = progress {
                executedOperations.append(.trash(items: [url2]))
            }
        }

        XCTAssertEqual(executedOperations.count, 2)
        XCTAssertEqual(mock.executeCallCount, 2)
    }

    func testEnqueueUsesInteractiveExecutorWhenFailureResolverProvided() async {
        let executor = InteractiveMockFileOperationExecuting()
        let sut = FileOperationQueue(executor: executor)
        let source = URL(fileURLWithPath: "/tmp/source.txt")
        executor.executeResult = .success(
            FileOperationRecord(
                operation: .copy(items: [source], destinationDirectory: source.deletingLastPathComponent()),
                result: .copied([]),
                timestamp: Date(),
                undoOperation: .trash(items: [])
            )
        )
        executor.interactiveFailureContext = FileOperationFailureContext(
            operationType: .copy,
            sourceURL: source,
            destinationURL: source.deletingLastPathComponent(),
            message: "mock failure"
        )

        let stream = await sut.enqueue(
            operation: .copy(items: [source], destinationDirectory: source.deletingLastPathComponent()),
            failureResolver: { _ in
                FileOperationFailureDecision(action: .skip, applyToRemaining: false)
            }
        )
        for await _ in stream {}

        XCTAssertEqual(executor.executeInteractiveCallCount, 1)
        XCTAssertEqual(executor.executeCallCount, 0)
        XCTAssertEqual(executor.capturedFailureContexts.count, 1)
    }

    func testEnqueueFallsBackToNonInteractiveExecutor() async {
        let (sut, mock) = makeSUT()
        let source = URL(fileURLWithPath: "/tmp/source.txt")
        let counter = AsyncCounter()

        let stream = await sut.enqueue(
            operation: .trash(items: [source]),
            failureResolver: { _ in
                await counter.increment()
                return FileOperationFailureDecision(action: .skip, applyToRemaining: false)
            }
        )
        for await _ in stream {}

        XCTAssertEqual(mock.executeCallCount, 1)
        let resolverCallCount = await counter.value()
        XCTAssertEqual(resolverCallCount, 0)
    }
}

private final class InteractiveMockFileOperationExecuting: InteractiveFileOperationExecuting, @unchecked Sendable {
    var executeResult: Result<FileOperationRecord, Error> = .success(
        FileOperationRecord(
            operation: .trash(items: []),
            result: .trashed([]),
            timestamp: Date(),
            undoOperation: .trash(items: [])
        )
    )

    var interactiveFailureContext: FileOperationFailureContext?
    private(set) var executeCallCount = 0
    private(set) var executeInteractiveCallCount = 0
    private(set) var capturedFailureContexts: [FileOperationFailureContext] = []

    func execute(
        _ operation: FileOperation,
        progress: @escaping @Sendable (_ completed: Int, _ total: Int, _ currentFile: URL) -> Void
    ) async throws -> FileOperationRecord {
        executeCallCount += 1
        return try executeResult.get()
    }

    func executeInteractive(
        _ operation: FileOperation,
        progress: @escaping @Sendable (_ completed: Int, _ total: Int, _ currentFile: URL) -> Void,
        resolveFailure: @escaping (FileOperationFailureContext) async -> FileOperationFailureDecision
    ) async throws -> FileOperationRecord {
        executeInteractiveCallCount += 1
        if let interactiveFailureContext {
            capturedFailureContexts.append(interactiveFailureContext)
            _ = await resolveFailure(interactiveFailureContext)
        }
        return try executeResult.get()
    }
}

private actor AsyncCounter {
    private var valueStorage = 0

    func increment() {
        valueStorage += 1
    }

    func value() -> Int {
        valueStorage
    }
}
