import Foundation
@testable import Starfiler

final class MockDirectoryComparing: DirectoryComparing, @unchecked Sendable {
    // MARK: - compare

    var compareResult: Result<[SyncItem], Error> = .success([])
    private(set) var compareCallCount = 0
    private(set) var compareCapturedArgs: [(
        leftDirectory: URL,
        rightDirectory: URL,
        direction: SyncDirection,
        excludeRules: [SyncExcludeRule]
    )] = []

    func compare(
        leftDirectory: URL,
        rightDirectory: URL,
        direction: SyncDirection,
        excludeRules: [SyncExcludeRule],
        progress: @escaping @Sendable (_ scanned: Int) -> Void
    ) async throws -> [SyncItem] {
        compareCallCount += 1
        compareCapturedArgs.append((leftDirectory, rightDirectory, direction, excludeRules))
        return try compareResult.get()
    }
}
