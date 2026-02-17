import XCTest
@testable import Starfiler

final class SecurityScopedBookmarkServiceIntegrationTests: XCTestCase {
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
}
