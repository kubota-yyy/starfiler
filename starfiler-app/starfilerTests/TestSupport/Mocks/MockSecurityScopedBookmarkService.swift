import Foundation
@testable import Starfiler

final class MockSecurityScopedBookmarkService: SecurityScopedBookmarkProviding, @unchecked Sendable {
    // MARK: - loadBookmarks

    var loadBookmarksError: Error?
    private(set) var loadBookmarksCallCount = 0

    func loadBookmarks() async throws {
        loadBookmarksCallCount += 1
        if let error = loadBookmarksError {
            throw error
        }
    }

    // MARK: - hasBookmarks

    var hasBookmarksResult: Bool = false
    var hasBookmarksError: Error?
    private(set) var hasBookmarksCallCount = 0

    func hasBookmarks() async throws -> Bool {
        hasBookmarksCallCount += 1
        if let error = hasBookmarksError {
            throw error
        }
        return hasBookmarksResult
    }

    // MARK: - saveBookmark

    var saveBookmarkError: Error?
    private(set) var saveBookmarkCallCount = 0
    private(set) var saveBookmarkCapturedURLs: [URL] = []

    func saveBookmark(for url: URL) async throws {
        saveBookmarkCallCount += 1
        saveBookmarkCapturedURLs.append(url)
        if let error = saveBookmarkError {
            throw error
        }
    }

    // MARK: - resolveBookmark

    var resolveBookmarkResult: URL?
    var resolveBookmarkError: Error?
    private(set) var resolveBookmarkCallCount = 0
    private(set) var resolveBookmarkCapturedURLs: [URL] = []

    func resolveBookmark(for url: URL) async throws -> URL? {
        resolveBookmarkCallCount += 1
        resolveBookmarkCapturedURLs.append(url)
        if let error = resolveBookmarkError {
            throw error
        }
        return resolveBookmarkResult
    }

    // MARK: - startAccessing

    var startAccessingError: Error?
    private(set) var startAccessingCallCount = 0
    private(set) var startAccessingCapturedURLs: [URL] = []

    func startAccessing(_ url: URL) async throws {
        startAccessingCallCount += 1
        startAccessingCapturedURLs.append(url)
        if let error = startAccessingError {
            throw error
        }
    }

    // MARK: - stopAccessing

    private(set) var stopAccessingCallCount = 0
    private(set) var stopAccessingCapturedURLs: [URL] = []

    func stopAccessing(_ url: URL) async {
        stopAccessingCallCount += 1
        stopAccessingCapturedURLs.append(url)
    }
}
