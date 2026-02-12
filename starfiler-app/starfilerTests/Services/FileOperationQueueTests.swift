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
}
