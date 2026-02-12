import Foundation
@testable import Starfiler

final class MockBatchRenameComputing: BatchRenameComputing, @unchecked Sendable {
    // MARK: - computeNewNames

    var computeNewNamesResult: [BatchRenameEntry] = []
    private(set) var computeNewNamesCallCount = 0
    private(set) var computeNewNamesCapturedArgs: [(
        files: [FileItem],
        rules: [BatchRenameRule],
        allDirectoryFiles: [FileItem]
    )] = []

    func computeNewNames(
        files: [FileItem],
        rules: [BatchRenameRule],
        allDirectoryFiles: [FileItem]
    ) -> [BatchRenameEntry] {
        computeNewNamesCallCount += 1
        computeNewNamesCapturedArgs.append((files, rules, allDirectoryFiles))
        return computeNewNamesResult
    }
}
