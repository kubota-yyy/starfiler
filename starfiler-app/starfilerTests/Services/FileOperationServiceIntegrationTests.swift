import XCTest
@testable import Starfiler

final class FileOperationServiceIntegrationTests: XCTestCase {
    func testCopyOperationCreatesDestinationAndUndoTrash() async throws {
        let workspace = try SandboxFixtureWorkspace()
        let sut = FileOperationService(trashRecycler: StubTrashRecycler())
        let source = workspace.url("left/docs/readme.md")
        let destinationDir = workspace.url("right")

        let record = try await sut.execute(.copy(items: [source], destinationDirectory: destinationDir)) { _, _, _ in }

        guard case .copied(let changes) = record.result else {
            return XCTFail("Expected copied result")
        }

        let copiedURL = try XCTUnwrap(changes.first?.destination)
        XCTAssertTrue(FileManager.default.fileExists(atPath: copiedURL.path))
        XCTAssertEqual(record.undoOperation, .trash(items: [copiedURL]))
    }

    func testMoveOperationMovesFileAndProducesInverseUndo() async throws {
        let workspace = try SandboxFixtureWorkspace()
        let sut = FileOperationService(trashRecycler: StubTrashRecycler())
        let source = workspace.url("rename/old_name.txt")
        let destination = workspace.url("right/moved_name.txt")

        let change = FileLocationChange(source: source, destination: destination)
        let record = try await sut.execute(.move(items: [change])) { _, _, _ in }

        XCTAssertFalse(FileManager.default.fileExists(atPath: source.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: destination.path))

        guard case .move(let undoItems) = record.undoOperation else {
            return XCTFail("Expected move undo")
        }

        XCTAssertEqual(undoItems, [FileLocationChange(source: destination.standardizedFileURL, destination: source.standardizedFileURL)])
    }

    func testRenameOperationRenamesAndBuildsUndo() async throws {
        let workspace = try SandboxFixtureWorkspace()
        let sut = FileOperationService(trashRecycler: StubTrashRecycler())
        let source = workspace.url("rename/old_name.txt")

        let record = try await sut.execute(.rename(item: source, newName: "renamed.txt")) { _, _, _ in }

        let destination = workspace.url("rename/renamed.txt")
        XCTAssertTrue(FileManager.default.fileExists(atPath: destination.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: source.path))

        guard case .rename(let undoItem, let undoName) = record.undoOperation else {
            return XCTFail("Expected rename undo")
        }

        XCTAssertEqual(undoItem, destination.standardizedFileURL)
        XCTAssertEqual(undoName, "old_name.txt")
    }

    func testCreateDirectoryOperationCreatesFolderAndUndoTrash() async throws {
        let workspace = try SandboxFixtureWorkspace()
        let sut = FileOperationService(trashRecycler: StubTrashRecycler())
        let parent = workspace.url("right")

        let record = try await sut.execute(.createDirectory(parentDirectory: parent, name: "new_folder")) { _, _, _ in }

        let createdURL = workspace.url("right/new_folder")
        XCTAssertTrue(FileManager.default.fileExists(atPath: createdURL.path))
        XCTAssertEqual(record.undoOperation, .trash(items: [createdURL.standardizedFileURL]))
    }

    func testBatchRenameHandlesCycle() async throws {
        let workspace = try SandboxFixtureWorkspace()
        let sut = FileOperationService(trashRecycler: StubTrashRecycler())

        let alpha = workspace.url("batch/alpha.txt")
        let beta = workspace.url("batch/beta.txt")

        let changes = [
            FileLocationChange(source: alpha, destination: beta),
            FileLocationChange(source: beta, destination: alpha),
        ]

        _ = try await sut.execute(.batchRename(items: changes)) { _, _, _ in }

        XCTAssertTrue(FileManager.default.fileExists(atPath: alpha.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: beta.path))
    }

    func testTrashOperationUsesInjectedRecyclerAndBuildsUndoMove() async throws {
        let workspace = try SandboxFixtureWorkspace()
        let recycler = StubTrashRecycler()
        let sut = FileOperationService(trashRecycler: recycler)

        let source = workspace.url("delete/remove_me.txt")
        let record = try await sut.execute(.trash(items: [source])) { _, _, _ in }

        guard case .trashed(let changes) = record.result else {
            return XCTFail("Expected trashed result")
        }

        let trashedURL = try XCTUnwrap(changes.first?.destination)
        XCTAssertFalse(FileManager.default.fileExists(atPath: source.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: trashedURL.path))

        guard case .move(let undoMappings) = record.undoOperation else {
            return XCTFail("Expected move undo")
        }

        XCTAssertEqual(undoMappings, [FileLocationChange(source: trashedURL.standardizedFileURL, destination: source.standardizedFileURL)])
    }

    func testExecuteInteractiveCopySkipsFailedItemAndContinues() async throws {
        let workspace = try SandboxFixtureWorkspace()
        let sut = FileOperationService(trashRecycler: StubTrashRecycler())
        let sourceA = workspace.url("left/docs/readme.md")
        let sourceMissing = workspace.url("left/docs/missing.txt")
        let sourceB = workspace.url("left/docs/notes.md")
        let destinationDir = workspace.url("right")
        let decisionCount = AsyncDecisionCounter()

        let record = try await sut.executeInteractive(
            .copy(items: [sourceA, sourceMissing, sourceB], destinationDirectory: destinationDir),
            progress: { _, _, _ in },
            resolveFailure: { _ in
                await decisionCount.increment()
                return FileOperationFailureDecision(action: .skip, applyToRemaining: false)
            }
        )

        guard case .copied(let changes) = record.result else {
            return XCTFail("Expected copied result")
        }

        XCTAssertEqual(changes.count, 2)
        XCTAssertTrue(FileManager.default.fileExists(atPath: destinationDir.appendingPathComponent("readme.md").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: destinationDir.appendingPathComponent("notes.md").path))
        let skipDecisionCount = await decisionCount.value()
        XCTAssertEqual(skipDecisionCount, 1)
    }

    func testExecuteInteractiveCopyRetriesFailedItem() async throws {
        let workspace = try SandboxFixtureWorkspace()
        let sut = FileOperationService(trashRecycler: StubTrashRecycler())
        let missingSource = workspace.url("left/docs/retry_me.txt")
        let destinationDir = workspace.url("right")
        let fileManager = FileManager.default
        let retryState = RetryDecisionState()

        let record = try await sut.executeInteractive(
            .copy(items: [missingSource], destinationDirectory: destinationDir),
            progress: { _, _, _ in },
            resolveFailure: { _ in
                if await retryState.consumeFirstFailure() {
                    let payload = Data("retry".utf8)
                    fileManager.createFile(atPath: missingSource.path, contents: payload)
                    return FileOperationFailureDecision(action: .retry, applyToRemaining: false)
                }
                return FileOperationFailureDecision(action: .skip, applyToRemaining: false)
            }
        )

        guard case .copied(let changes) = record.result else {
            return XCTFail("Expected copied result")
        }

        XCTAssertEqual(changes.count, 1)
        XCTAssertTrue(FileManager.default.fileExists(atPath: destinationDir.appendingPathComponent("retry_me.txt").path))
    }

    func testExecuteInteractiveCopyAbortStopsRemainingItems() async throws {
        let workspace = try SandboxFixtureWorkspace()
        let sut = FileOperationService(trashRecycler: StubTrashRecycler())
        let sourceA = workspace.url("left/docs/readme.md")
        let sourceMissing = workspace.url("left/docs/abort.txt")
        let sourceB = workspace.url("left/docs/notes.md")
        let destinationDir = workspace.url("right")
        let decisionCount = AsyncDecisionCounter()

        let record = try await sut.executeInteractive(
            .copy(items: [sourceA, sourceMissing, sourceB], destinationDirectory: destinationDir),
            progress: { _, _, _ in },
            resolveFailure: { _ in
                await decisionCount.increment()
                return FileOperationFailureDecision(action: .abort, applyToRemaining: false)
            }
        )

        guard case .copied(let changes) = record.result else {
            return XCTFail("Expected copied result")
        }

        XCTAssertEqual(changes.count, 1)
        XCTAssertTrue(FileManager.default.fileExists(atPath: destinationDir.appendingPathComponent("readme.md").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: destinationDir.appendingPathComponent("notes.md").path))
        let abortDecisionCount = await decisionCount.value()
        XCTAssertEqual(abortDecisionCount, 1)
    }

    func testExecuteInteractiveCopyApplySkipToRemainingFailures() async throws {
        let workspace = try SandboxFixtureWorkspace()
        let sut = FileOperationService(trashRecycler: StubTrashRecycler())
        let sourceMissingA = workspace.url("left/docs/skip_a.txt")
        let sourceMissingB = workspace.url("left/docs/skip_b.txt")
        let sourceExisting = workspace.url("left/docs/readme.md")
        let destinationDir = workspace.url("right")
        let decisionCount = AsyncDecisionCounter()

        let record = try await sut.executeInteractive(
            .copy(items: [sourceMissingA, sourceMissingB, sourceExisting], destinationDirectory: destinationDir),
            progress: { _, _, _ in },
            resolveFailure: { _ in
                await decisionCount.increment()
                return FileOperationFailureDecision(action: .skip, applyToRemaining: true)
            }
        )

        guard case .copied(let changes) = record.result else {
            return XCTFail("Expected copied result")
        }

        XCTAssertEqual(changes.count, 1)
        XCTAssertTrue(FileManager.default.fileExists(atPath: destinationDir.appendingPathComponent("readme.md").path))
        let applyDecisionCount = await decisionCount.value()
        XCTAssertEqual(applyDecisionCount, 1)
    }
}

private actor StubTrashRecycler: TrashRecycling {
    private let fileManager = FileManager.default

    func recycle(_ url: URL) async throws -> URL {
        let source = url.standardizedFileURL
        let trashDirectory = source.deletingLastPathComponent().appendingPathComponent(".trash", isDirectory: true)
        if !fileManager.fileExists(atPath: trashDirectory.path) {
            try fileManager.createDirectory(at: trashDirectory, withIntermediateDirectories: true)
        }

        let destination = trashDirectory.appendingPathComponent(source.lastPathComponent, isDirectory: source.hasDirectoryPath)
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        try fileManager.moveItem(at: source, to: destination)
        return destination.standardizedFileURL
    }
}

private actor AsyncDecisionCounter {
    private var storage = 0

    func increment() {
        storage += 1
    }

    func value() -> Int {
        storage
    }
}

private actor RetryDecisionState {
    private var isFirstFailure = true

    func consumeFirstFailure() -> Bool {
        if isFirstFailure {
            isFirstFailure = false
            return true
        }
        return false
    }
}
