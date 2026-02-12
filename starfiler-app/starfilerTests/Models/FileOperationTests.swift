import XCTest
@testable import Starfiler

final class FileOperationTests: XCTestCase {

    // MARK: - Helpers

    private let urlA = URL(fileURLWithPath: "/a")
    private let urlB = URL(fileURLWithPath: "/b")
    private let urlC = URL(fileURLWithPath: "/c")
    private let destDir = URL(fileURLWithPath: "/dest")

    // MARK: - FileOperationType

    func testCopyOperationType() {
        let op = FileOperation.copy(items: [urlA, urlB], destinationDirectory: destDir)
        XCTAssertEqual(op.type, .copy)
    }

    func testMoveOperationType() {
        let change = FileLocationChange(source: urlA, destination: urlB)
        let op = FileOperation.move(items: [change])
        XCTAssertEqual(op.type, .move)
    }

    func testTrashOperationType() {
        let op = FileOperation.trash(items: [urlA])
        XCTAssertEqual(op.type, .trash)
    }

    func testRenameOperationType() {
        let op = FileOperation.rename(item: urlA, newName: "new.txt")
        XCTAssertEqual(op.type, .rename)
    }

    func testCreateDirectoryOperationType() {
        let op = FileOperation.createDirectory(parentDirectory: destDir, name: "NewFolder")
        XCTAssertEqual(op.type, .createDirectory)
    }

    func testBatchRenameOperationType() {
        let change = FileLocationChange(source: urlA, destination: urlB)
        let op = FileOperation.batchRename(items: [change])
        XCTAssertEqual(op.type, .batchRename)
    }

    // MARK: - totalUnitCount

    func testCopyTotalUnitCount() {
        let op = FileOperation.copy(items: [urlA, urlB, urlC], destinationDirectory: destDir)
        XCTAssertEqual(op.totalUnitCount, 3)
    }

    func testMoveTotalUnitCount() {
        let changes = [
            FileLocationChange(source: urlA, destination: urlB),
            FileLocationChange(source: urlB, destination: urlC),
        ]
        let op = FileOperation.move(items: changes)
        XCTAssertEqual(op.totalUnitCount, 2)
    }

    func testTrashTotalUnitCount() {
        let op = FileOperation.trash(items: [urlA])
        XCTAssertEqual(op.totalUnitCount, 1)
    }

    func testRenameTotalUnitCount() {
        let op = FileOperation.rename(item: urlA, newName: "new.txt")
        XCTAssertEqual(op.totalUnitCount, 1)
    }

    func testCreateDirectoryTotalUnitCount() {
        let op = FileOperation.createDirectory(parentDirectory: destDir, name: "Folder")
        XCTAssertEqual(op.totalUnitCount, 1)
    }

    func testBatchRenameTotalUnitCount() {
        let changes = [
            FileLocationChange(source: urlA, destination: urlB),
            FileLocationChange(source: urlB, destination: urlC),
            FileLocationChange(source: urlC, destination: urlA),
        ]
        let op = FileOperation.batchRename(items: changes)
        XCTAssertEqual(op.totalUnitCount, 3)
    }

    // MARK: - FileOperationResult.affectedURLs

    func testCopiedAffectedURLs() {
        let changes = [
            FileLocationChange(source: urlA, destination: urlB),
            FileLocationChange(source: urlB, destination: urlC),
        ]
        let result = FileOperationResult.copied(changes)
        XCTAssertEqual(result.affectedURLs, [urlB, urlC])
    }

    func testMovedAffectedURLs() {
        let changes = [FileLocationChange(source: urlA, destination: urlB)]
        let result = FileOperationResult.moved(changes)
        XCTAssertEqual(result.affectedURLs, [urlB])
    }

    func testTrashedAffectedURLs() {
        let change = FileLocationChange(source: urlA, destination: urlC)
        let result = FileOperationResult.trashed([change])
        XCTAssertEqual(result.affectedURLs, [urlC])
    }

    func testRenamedAffectedURLs() {
        let change = FileLocationChange(source: urlA, destination: urlB)
        let result = FileOperationResult.renamed(change)
        XCTAssertEqual(result.affectedURLs, [urlB])
    }

    func testCreatedDirectoryAffectedURLs() {
        let result = FileOperationResult.createdDirectory(destDir)
        XCTAssertEqual(result.affectedURLs, [destDir])
    }

    func testBatchRenamedAffectedURLs() {
        let changes = [
            FileLocationChange(source: urlA, destination: urlB),
            FileLocationChange(source: urlC, destination: destDir),
        ]
        let result = FileOperationResult.batchRenamed(changes)
        XCTAssertEqual(result.affectedURLs, [urlB, destDir])
    }

    // MARK: - FileOperationType.undoActionName

    func testUndoActionNames() {
        XCTAssertEqual(FileOperationType.copy.undoActionName, "Undo Copy")
        XCTAssertEqual(FileOperationType.move.undoActionName, "Undo Move")
        XCTAssertEqual(FileOperationType.trash.undoActionName, "Undo Delete")
        XCTAssertEqual(FileOperationType.rename.undoActionName, "Undo Rename")
        XCTAssertEqual(FileOperationType.createDirectory.undoActionName, "Undo Create Folder")
        XCTAssertEqual(FileOperationType.batchRename.undoActionName, "Undo Batch Rename")
    }

    // MARK: - FileOperationError

    func testFileOperationErrorMessage() {
        let error = FileOperationError(message: "File not found")
        XCTAssertEqual(error.message, "File not found")
        XCTAssertEqual(error.errorDescription, "File not found")
    }
}
