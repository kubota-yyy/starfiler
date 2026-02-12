import Foundation
import Observation

@MainActor
@Observable
final class TerminalSessionListViewModel {
    private let service: any TerminalSessionProviding

    private(set) var sessions: [TerminalSession] = []
    var activeSessionId: UUID?
    var terminalPanelVisible: Bool

    var onSessionCreated: ((TerminalSession) -> Void)?
    var onSessionRemoved: ((UUID) -> Void)?
    var onActiveSessionChanged: ((UUID?) -> Void)?
    var onPanelVisibilityChanged: ((Bool) -> Void)?

    init(service: any TerminalSessionProviding = TerminalSessionService(), initialPanelVisible: Bool = false) {
        self.service = service
        self.terminalPanelVisible = initialPanelVisible
    }

    func createSession(command: TerminalSessionCommand, workingDirectory: URL) {
        Task {
            let session = await service.createSession(command: command, workingDirectory: workingDirectory)
            await reloadSessions()
            activeSessionId = session.id
            if !terminalPanelVisible {
                terminalPanelVisible = true
                onPanelVisibilityChanged?(true)
            }
            onSessionCreated?(session)
            onActiveSessionChanged?(session.id)
        }
    }

    func removeSession(id: UUID) {
        Task {
            await service.removeSession(id: id)
            await reloadSessions()
            onSessionRemoved?(id)

            if activeSessionId == id {
                activeSessionId = sessions.last?.id
                onActiveSessionChanged?(activeSessionId)
            }
        }
    }

    func setActiveSession(id: UUID) {
        guard sessions.contains(where: { $0.id == id }) else { return }
        activeSessionId = id
        onActiveSessionChanged?(id)
    }

    func togglePanel() {
        terminalPanelVisible.toggle()
        onPanelVisibilityChanged?(terminalPanelVisible)
    }

    func showPanel() {
        guard !terminalPanelVisible else { return }
        terminalPanelVisible = true
        onPanelVisibilityChanged?(true)
    }

    func hidePanel() {
        guard terminalPanelVisible else { return }
        terminalPanelVisible = false
        onPanelVisibilityChanged?(false)
    }

    func updateSessionStatus(id: UUID, status: TerminalSessionStatus) {
        Task {
            await service.updateStatus(id: id, status: status)
            await reloadSessions()
        }
    }

    func updateSessionExitCode(id: UUID, exitCode: Int32) {
        Task {
            await service.updateExitCode(id: id, exitCode: exitCode)
            await reloadSessions()
        }
    }

    func updateSessionLastActivity(id: UUID) {
        Task {
            await service.updateLastActivity(id: id)
            await reloadSessions()
        }
    }

    func updateSessionTitle(id: UUID, title: String) {
        Task {
            await service.updateTitle(id: id, title: title)
            await reloadSessions()
        }
    }

    private func reloadSessions() async {
        sessions = await service.sessions()
    }
}
