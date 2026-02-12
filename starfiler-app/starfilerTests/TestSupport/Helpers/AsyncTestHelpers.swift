import Foundation
import XCTest

extension XCTestCase {
    /// Polls a condition at the given interval until it returns `true` or the timeout expires.
    ///
    /// Usage:
    /// ```swift
    /// await waitForCondition(timeout: 2.0, description: "Items loaded") {
    ///     viewModel.items.count == 3
    /// }
    /// ```
    @MainActor
    func waitForCondition(
        timeout: TimeInterval = 5.0,
        pollInterval: TimeInterval = 0.01,
        description: String = "Condition to be met",
        file: StaticString = #filePath,
        line: UInt = #line,
        condition: @escaping () -> Bool
    ) async {
        let deadline = Date().addingTimeInterval(timeout)

        while !condition() {
            if Date() >= deadline {
                XCTFail("Timed out waiting for: \(description)", file: file, line: line)
                return
            }
            try? await Task.sleep(nanoseconds: UInt64(pollInterval * 1_000_000_000))
        }
    }
}
