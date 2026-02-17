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
