import Foundation
@testable import Starfiler

final class MockDirectoryMonitor: DirectoryMonitoring {
    // MARK: - startMonitoring

    private(set) var startMonitoringCallCount = 0
    private(set) var startMonitoringCapturedURLs: [URL] = []
    private var storedHandler: (() -> Void)?

    func startMonitoring(url: URL, handler: @escaping () -> Void) {
        startMonitoringCallCount += 1
        startMonitoringCapturedURLs.append(url)
        storedHandler = handler
    }

    // MARK: - stopMonitoring

    private(set) var stopMonitoringCallCount = 0

    func stopMonitoring() {
        stopMonitoringCallCount += 1
        storedHandler = nil
    }

    // MARK: - suspend

    private(set) var suspendCallCount = 0

    func suspend() {
        suspendCallCount += 1
    }

    // MARK: - resume

    private(set) var resumeCallCount = 0

    func resume() {
        resumeCallCount += 1
    }

    // MARK: - Test Helpers

    /// Triggers the stored handler to simulate a directory change event.
    func simulateChange() {
        storedHandler?()
    }

    /// Returns whether a handler is currently registered.
    var hasHandler: Bool {
        storedHandler != nil
    }
}
