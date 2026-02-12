import Foundation
import Observation

@MainActor
@Observable
final class TerminalSessionViewModel {
    private static let waitingForInputDelay: TimeInterval = 3.0

    let sessionId: UUID
    private(set) var status: TerminalSessionStatus = .launching

    var onStatusChanged: ((TerminalSessionStatus) -> Void)?

    private var activityTimer: Timer?

    init(sessionId: UUID) {
        self.sessionId = sessionId
    }

    func outputReceived() {
        if status != .running {
            setStatus(.running)
        }
        resetActivityTimer()
    }

    func processStarted() {
        setStatus(.running)
        resetActivityTimer()
    }

    func processExited(exitCode: Int32) {
        activityTimer?.invalidate()
        activityTimer = nil
        setStatus(exitCode == 0 ? .completed : .error)
    }

    private func setStatus(_ newStatus: TerminalSessionStatus) {
        guard status != newStatus else { return }
        status = newStatus
        onStatusChanged?(newStatus)
    }

    private func resetActivityTimer() {
        activityTimer?.invalidate()
        activityTimer = Timer.scheduledTimer(
            withTimeInterval: Self.waitingForInputDelay,
            repeats: false
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.status == .running else { return }
                self.setStatus(.waitingForInput)
            }
        }
    }

    func invalidateTimer() {
        activityTimer?.invalidate()
        activityTimer = nil
    }
}
