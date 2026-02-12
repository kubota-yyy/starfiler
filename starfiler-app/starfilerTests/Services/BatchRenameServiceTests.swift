import XCTest
@testable import Starfiler

final class BatchRenameServiceTests: XCTestCase {

    // MARK: - Helpers

    private let service = BatchRenameService()

    private func makeFileItem(
        name: String,
        isDirectory: Bool = false
    ) -> FileItem {
        let url = URL(fileURLWithPath: "/test/\(name)", isDirectory: isDirectory)
        return FileItem(
            url: url,
            name: name,
            isDirectory: isDirectory,
            size: nil,
            dateModified: nil,
            isHidden: false,
            isSymlink: false,
            isPackage: false
        )
    }

    // MARK: - No Rules

    func testNoRulesKeepsOriginalNames() {
        let files = [
            makeFileItem(name: "file1.txt"),
            makeFileItem(name: "file2.txt"),
        ]
        let entries = service.computeNewNames(files: files, rules: [], allDirectoryFiles: files)
        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(entries[0].newName, "file1.txt")
        XCTAssertEqual(entries[1].newName, "file2.txt")
        XCTAssertFalse(entries[0].hasConflict)
        XCTAssertFalse(entries[1].hasConflict)
    }

    func testEmptyFilesReturnsEmpty() {
        let entries = service.computeNewNames(files: [], rules: [], allDirectoryFiles: [])
        XCTAssertTrue(entries.isEmpty)
    }

    // MARK: - Find and Replace

    func testFindReplace() {
        let files = [
            makeFileItem(name: "old_photo.jpg"),
            makeFileItem(name: "old_video.mp4"),
        ]
        let rules: [BatchRenameRule] = [
            .findReplace(find: "old", replace: "new"),
        ]
        let entries = service.computeNewNames(files: files, rules: rules, allDirectoryFiles: files)
        XCTAssertEqual(entries[0].newName, "new_photo.jpg")
        XCTAssertEqual(entries[1].newName, "new_video.mp4")
    }

    func testFindReplaceNoMatch() {
        let files = [makeFileItem(name: "file.txt")]
        let rules: [BatchRenameRule] = [
            .findReplace(find: "xyz", replace: "abc"),
        ]
        let entries = service.computeNewNames(files: files, rules: rules, allDirectoryFiles: files)
        XCTAssertEqual(entries[0].newName, "file.txt")
    }

    // MARK: - Regex Replace

    func testRegexReplace() {
        let files = [
            makeFileItem(name: "IMG_0001.jpg"),
            makeFileItem(name: "IMG_0002.jpg"),
        ]
        let rules: [BatchRenameRule] = [
            .regexReplace(pattern: "IMG_(\\d+)", replacement: "Photo_$1", caseInsensitive: false),
        ]
        let entries = service.computeNewNames(files: files, rules: rules, allDirectoryFiles: files)
        XCTAssertEqual(entries[0].newName, "Photo_0001.jpg")
        XCTAssertEqual(entries[1].newName, "Photo_0002.jpg")
    }

    func testRegexReplaceCaseInsensitive() {
        let files = [makeFileItem(name: "Hello.txt")]
        let rules: [BatchRenameRule] = [
            .regexReplace(pattern: "hello", replacement: "Goodbye", caseInsensitive: true),
        ]
        let entries = service.computeNewNames(files: files, rules: rules, allDirectoryFiles: files)
        XCTAssertEqual(entries[0].newName, "Goodbye.txt")
    }

    func testRegexReplaceInvalidPattern() {
        let files = [makeFileItem(name: "file.txt")]
        let rules: [BatchRenameRule] = [
            .regexReplace(pattern: "[invalid", replacement: "x", caseInsensitive: false),
        ]
        let entries = service.computeNewNames(files: files, rules: rules, allDirectoryFiles: files)
        XCTAssertTrue(entries[0].hasConflict)
        XCTAssertNotNil(entries[0].errorMessage)
        XCTAssertEqual(entries[0].newName, "file.txt")
    }

    // MARK: - Case Conversion

    func testCaseConversionUpper() {
        let files = [makeFileItem(name: "hello world.txt")]
        let rules: [BatchRenameRule] = [
            .caseConversion(.upper),
        ]
        let entries = service.computeNewNames(files: files, rules: rules, allDirectoryFiles: files)
        XCTAssertEqual(entries[0].newName, "HELLO WORLD.txt")
    }

    func testCaseConversionLower() {
        let files = [makeFileItem(name: "HELLO WORLD.txt")]
        let rules: [BatchRenameRule] = [
            .caseConversion(.lower),
        ]
        let entries = service.computeNewNames(files: files, rules: rules, allDirectoryFiles: files)
        XCTAssertEqual(entries[0].newName, "hello world.txt")
    }

    func testCaseConversionTitle() {
        let files = [makeFileItem(name: "hello world.txt")]
        let rules: [BatchRenameRule] = [
            .caseConversion(.title),
        ]
        let entries = service.computeNewNames(files: files, rules: rules, allDirectoryFiles: files)
        XCTAssertEqual(entries[0].newName, "Hello World.txt")
    }

    func testCaseConversionSnakeCase() {
        let files = [makeFileItem(name: "hello world.txt")]
        let rules: [BatchRenameRule] = [
            .caseConversion(.snakeCase),
        ]
        let entries = service.computeNewNames(files: files, rules: rules, allDirectoryFiles: files)
        XCTAssertEqual(entries[0].newName, "hello_world.txt")
    }

    func testCaseConversionCamelCase() {
        let files = [makeFileItem(name: "hello world.txt")]
        let rules: [BatchRenameRule] = [
            .caseConversion(.camelCase),
        ]
        let entries = service.computeNewNames(files: files, rules: rules, allDirectoryFiles: files)
        XCTAssertEqual(entries[0].newName, "helloWorld.txt")
    }

    // MARK: - Sequential Numbering

    func testSequentialNumberPrefix() {
        let files = [
            makeFileItem(name: "photo.jpg"),
            makeFileItem(name: "video.mp4"),
        ]
        let rules: [BatchRenameRule] = [
            .sequentialNumber(position: .prefix, start: 1, step: 1, padding: 3),
        ]
        let entries = service.computeNewNames(files: files, rules: rules, allDirectoryFiles: files)
        XCTAssertEqual(entries[0].newName, "001photo.jpg")
        XCTAssertEqual(entries[1].newName, "002video.mp4")
    }

    func testSequentialNumberSuffix() {
        let files = [
            makeFileItem(name: "photo.jpg"),
            makeFileItem(name: "video.mp4"),
        ]
        let rules: [BatchRenameRule] = [
            .sequentialNumber(position: .suffix, start: 10, step: 5, padding: 2),
        ]
        let entries = service.computeNewNames(files: files, rules: rules, allDirectoryFiles: files)
        XCTAssertEqual(entries[0].newName, "photo10.jpg")
        XCTAssertEqual(entries[1].newName, "video15.mp4")
    }

    func testSequentialNumberReplace() {
        let files = [
            makeFileItem(name: "photo.jpg"),
            makeFileItem(name: "video.mp4"),
        ]
        let rules: [BatchRenameRule] = [
            .sequentialNumber(position: .replace, start: 1, step: 1, padding: 4),
        ]
        let entries = service.computeNewNames(files: files, rules: rules, allDirectoryFiles: files)
        XCTAssertEqual(entries[0].newName, "0001.jpg")
        XCTAssertEqual(entries[1].newName, "0002.mp4")
    }

    // MARK: - File Without Extension

    func testFileWithoutExtension() {
        let files = [makeFileItem(name: "Makefile")]
        let rules: [BatchRenameRule] = [
            .caseConversion(.upper),
        ]
        let entries = service.computeNewNames(files: files, rules: rules, allDirectoryFiles: files)
        XCTAssertEqual(entries[0].newName, "MAKEFILE")
    }

    // MARK: - Conflict Detection

    func testDuplicateNamesDetected() {
        let files = [
            makeFileItem(name: "a.txt"),
            makeFileItem(name: "b.txt"),
        ]
        let rules: [BatchRenameRule] = [
            .findReplace(find: "a", replace: "x"),
            .findReplace(find: "b", replace: "x"),
        ]
        // Both become "x.txt" -> should be a conflict
        // But actually rules apply sequentially to the basename.
        // For file "a.txt": basename "a" -> findReplace "a"->"x" -> "x", then findReplace "b"->"x" (no match) -> "x" -> "x.txt"
        // For file "b.txt": basename "b" -> findReplace "a"->"x" (no match) -> "b", then findReplace "b"->"x" -> "x" -> "x.txt"
        let entries = service.computeNewNames(files: files, rules: rules, allDirectoryFiles: files)
        XCTAssertTrue(entries[0].hasConflict)
        XCTAssertTrue(entries[1].hasConflict)
        XCTAssertEqual(entries[0].errorMessage, "Duplicate name in batch")
    }

    func testConflictWithExistingFile() {
        let files = [makeFileItem(name: "a.txt")]
        let existingFile = makeFileItem(name: "b.txt")
        let rules: [BatchRenameRule] = [
            .findReplace(find: "a", replace: "b"),
        ]
        // "a.txt" -> "b.txt" which conflicts with existing "b.txt"
        let entries = service.computeNewNames(
            files: files,
            rules: rules,
            allDirectoryFiles: files + [existingFile]
        )
        XCTAssertTrue(entries[0].hasConflict)
        XCTAssertEqual(entries[0].errorMessage, "Name conflicts with existing file")
    }

    func testNoConflictWhenRenamingToSameName() {
        let files = [makeFileItem(name: "a.txt")]
        let rules: [BatchRenameRule] = [
            .findReplace(find: "xyz", replace: "abc"),
        ]
        // Name stays "a.txt" which is the same as original - no conflict
        let entries = service.computeNewNames(
            files: files,
            rules: rules,
            allDirectoryFiles: files
        )
        XCTAssertFalse(entries[0].hasConflict)
    }

    // MARK: - Multiple Rules Combined

    func testMultipleRulesCombined() {
        let files = [
            makeFileItem(name: "IMG_0001.jpg"),
            makeFileItem(name: "IMG_0002.jpg"),
        ]
        let rules: [BatchRenameRule] = [
            .findReplace(find: "IMG_", replace: "photo_"),
            .caseConversion(.upper),
        ]
        let entries = service.computeNewNames(files: files, rules: rules, allDirectoryFiles: files)
        // IMG_0001 -> photo_0001 -> PHOTO_0001 -> PHOTO_0001.jpg
        XCTAssertEqual(entries[0].newName, "PHOTO_0001.jpg")
        XCTAssertEqual(entries[1].newName, "PHOTO_0002.jpg")
    }

    // MARK: - originalURL / originalName tracking

    func testEntryTracksOriginalValues() {
        let file = makeFileItem(name: "original.txt")
        let rules: [BatchRenameRule] = [
            .findReplace(find: "original", replace: "renamed"),
        ]
        let entries = service.computeNewNames(files: [file], rules: rules, allDirectoryFiles: [file])
        XCTAssertEqual(entries[0].originalURL, file.url)
        XCTAssertEqual(entries[0].originalName, "original.txt")
        XCTAssertEqual(entries[0].newName, "renamed.txt")
    }
}
