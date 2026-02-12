import Foundation
@testable import Starfiler

@MainActor
final class MockSpotlightSearchService: SpotlightSearching {
    // MARK: - search

    var searchResults: [FileItem] = []
    private(set) var searchCallCount = 0
    private(set) var searchCapturedArgs: [(query: String, scope: SpotlightSearchScope, currentDirectory: URL)] = []

    func search(
        query: String,
        scope: SpotlightSearchScope,
        currentDirectory: URL
    ) -> AsyncStream<[FileItem]> {
        searchCallCount += 1
        searchCapturedArgs.append((query, scope, currentDirectory))

        let results = searchResults
        return AsyncStream { continuation in
            continuation.yield(results)
            continuation.finish()
        }
    }

    // MARK: - cancel

    private(set) var cancelCallCount = 0

    func cancel() {
        cancelCallCount += 1
    }
}
