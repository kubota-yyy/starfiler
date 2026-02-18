import XCTest
@testable import Starfiler

final class SecurityScopedBookmarkServiceIntegrationTests: XCTestCase {
    private struct BookmarkStorePayload: Codable {
        var version: Int
        var bookmarks: [BookmarkRecordPayload]
    }

    private struct BookmarkRecordPayload: Codable {
        var id: UUID
        var selectedPath: String
        var resolvedPath: String
        var bookmarkData: Data
        var createdAt: Date
        var updatedAt: Date
    }

    func testSaveLoadAndResolveBookmarkWithCustomStoreURL() async throws {
        let workspace = try SandboxFixtureWorkspace()
        let storeURL = workspace.url("config/SecurityScopedBookmarks.json")
        let bookmarkedRoot = workspace.url("left")
        let descendant = workspace.url("left/docs/readme.md")

        let service = SecurityScopedBookmarkService(
            bundleIdentifier: "com.nilone.starfiler.tests",
            bookmarkStoreURL: storeURL
        )

        try await service.loadBookmarks()
        let hasBookmarksBeforeSave = try await service.hasBookmarks()
        XCTAssertFalse(hasBookmarksBeforeSave)

        try await service.saveBookmark(for: bookmarkedRoot)
        let hasBookmarksAfterSave = try await service.hasBookmarks()
        XCTAssertTrue(hasBookmarksAfterSave)

        let resolved = try await service.resolveBookmark(for: descendant)
        XCTAssertEqual(resolved, bookmarkedRoot.standardizedFileURL)

        let reloadedService = SecurityScopedBookmarkService(
            bundleIdentifier: "com.nilone.starfiler.tests",
            bookmarkStoreURL: storeURL
        )
        try await reloadedService.loadBookmarks()
        let hasBookmarksAfterReload = try await reloadedService.hasBookmarks()
        XCTAssertTrue(hasBookmarksAfterReload)
    }

    func testStartAndStopAccessingForDescendantPath() async throws {
        let workspace = try SandboxFixtureWorkspace()
        let storeURL = workspace.url("config/SecurityScopedBookmarks.json")
        let bookmarkedRoot = workspace.url("left")
        let descendant = workspace.url("left/docs")

        let service = SecurityScopedBookmarkService(
            bundleIdentifier: "com.nilone.starfiler.tests",
            bookmarkStoreURL: storeURL
        )

        try await service.loadBookmarks()
        try await service.saveBookmark(for: bookmarkedRoot)

        try await service.startAccessing(descendant)
        try await service.startAccessing(descendant)

        await service.stopAccessing(descendant)
        await service.stopAccessing(descendant)
    }

    func testResolveBookmarkThrowsWhenSymlinkEscapesAuthorizedScope() async throws {
        let workspace = try SandboxFixtureWorkspace()
        let storeURL = workspace.url("config/SecurityScopedBookmarks.json")
        let bookmarkedRoot = workspace.url("left")
        let escapedPath = workspace.url("left/link_to_right_target.txt")

        let service = SecurityScopedBookmarkService(
            bundleIdentifier: "com.nilone.starfiler.tests",
            bookmarkStoreURL: storeURL
        )

        try await service.loadBookmarks()
        try await service.saveBookmark(for: bookmarkedRoot)

        do {
            _ = try await service.resolveBookmark(for: escapedPath)
            XCTFail("Expected symlink escape error")
        } catch let error as SecurityScopedBookmarkError {
            guard case .symlinkEscapesAuthorizedScope = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testStartAccessingThrowsBookmarkNotFoundForUnknownPath() async throws {
        let workspace = try SandboxFixtureWorkspace()
        let storeURL = workspace.url("config/SecurityScopedBookmarks.json")
        let unknownPath = workspace.url("outside/not-authorized")

        let service = SecurityScopedBookmarkService(
            bundleIdentifier: "com.nilone.starfiler.tests",
            bookmarkStoreURL: storeURL
        )

        try await service.loadBookmarks()

        do {
            try await service.startAccessing(unknownPath)
            XCTFail("Expected bookmark not found")
        } catch let error as SecurityScopedBookmarkError {
            guard case .bookmarkNotFound = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testResolveBookmarkSupportsLegacyUnicodeNormalizedStorePaths() async throws {
        let workspace = try SandboxFixtureWorkspace()
        let fileManager = FileManager.default
        let storeURL = workspace.url("config/SecurityScopedBookmarks.json")

        let parentURL = workspace.url("unicode")
        try fileManager.createDirectory(at: parentURL, withIntermediateDirectories: true)

        let composedName = makeComposedDakutenName()
        let decomposedName = makeDecomposedDakutenName()
        XCTAssertNotEqual(Array(composedName.unicodeScalars), Array(decomposedName.unicodeScalars))

        let decomposedDirectoryURL = parentURL.appendingPathComponent(decomposedName, isDirectory: true)
        try fileManager.createDirectory(at: decomposedDirectoryURL, withIntermediateDirectories: true)
        let childURL = decomposedDirectoryURL.appendingPathComponent("child.txt")
        try Data("ok".utf8).write(to: childURL, options: .atomic)

        let initialService = SecurityScopedBookmarkService(
            bundleIdentifier: "com.nilone.starfiler.tests",
            bookmarkStoreURL: storeURL
        )
        try await initialService.loadBookmarks()
        try await initialService.saveBookmark(for: decomposedDirectoryURL)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        var payload = try decoder.decode(BookmarkStorePayload.self, from: Data(contentsOf: storeURL))
        XCTAssertEqual(payload.bookmarks.count, 1)

        payload.bookmarks[0].selectedPath = payload.bookmarks[0].selectedPath
            .replacingOccurrences(of: decomposedName, with: composedName)
        payload.bookmarks[0].resolvedPath = payload.bookmarks[0].resolvedPath
            .replacingOccurrences(of: decomposedName, with: composedName)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(payload).write(to: storeURL, options: .atomic)

        let reloadedService = SecurityScopedBookmarkService(
            bundleIdentifier: "com.nilone.starfiler.tests",
            bookmarkStoreURL: storeURL
        )
        try await reloadedService.loadBookmarks()

        let resolved = try await reloadedService.resolveBookmark(for: childURL)
        XCTAssertEqual(resolved, decomposedDirectoryURL.standardizedFileURL)
    }

    private func makeComposedDakutenName() -> String {
        String(UnicodeScalar(0x30C0)!) + String(UnicodeScalar(0x30A4)!) + String(UnicodeScalar(0x30E4)!)
    }

    private func makeDecomposedDakutenName() -> String {
        String(UnicodeScalar(0x30BF)!) + String(UnicodeScalar(0x3099)!) + String(UnicodeScalar(0x30A4)!) + String(UnicodeScalar(0x30E4)!)
    }
}
