import Foundation
import Observation

enum TerminalSessionProviderFilter: String, CaseIterable, Sendable {
    case all
    case claude
    case codex

    var displayName: String {
        switch self {
        case .all: return "All"
        case .claude: return "Claude"
        case .codex: return "Codex"
        }
    }

    var commandFilter: TerminalSessionCommand? {
        switch self {
        case .all: return nil
        case .claude: return .claude
        case .codex: return .codex
        }
    }
}

@MainActor
@Observable
final class TerminalSessionManagerViewModel {
    private static let searchDebounceInterval: TimeInterval = 0.15

    private let service: any TerminalSessionProviding

    private(set) var sessions: [TerminalSession] = []
    private(set) var searchResults: [TerminalSessionSearchResult] = []
    private(set) var runningSessionCount: Int = 0

    var searchQuery: String = "" {
        didSet {
            scheduleSearch()
        }
    }

    var providerFilter: TerminalSessionProviderFilter = .all {
        didSet {
            performSearch()
        }
    }

    var isSearching: Bool {
        !searchQuery.isEmpty
    }

    var onOpenSession: ((UUID) -> Void)?
    var onSessionsChanged: (() -> Void)?

    private var searchDebounceTask: Task<Void, Never>?

    init(service: any TerminalSessionProviding) {
        self.service = service
    }

    func reloadSessions() {
        Task {
            sessions = await service.sessions()
            runningSessionCount = sessions.filter { $0.status.isActive }.count
            if isSearching {
                searchResults = await service.search(
                    query: searchQuery,
                    providerFilter: providerFilter.commandFilter
                )
            }
            onSessionsChanged?()
        }
    }

    func pinSession(id: UUID) {
        Task {
            await service.pin(id: id)
            reloadSessions()
        }
    }

    func unpinSession(id: UUID) {
        Task {
            await service.unpin(id: id)
            reloadSessions()
        }
    }

    func renameSession(id: UUID, title: String) {
        Task {
            await service.rename(id: id, title: title)
            reloadSessions()
        }
    }

    func removeSession(id: UUID) {
        Task {
            await service.removeSession(id: id)
            reloadSessions()
        }
    }

    func openSession(id: UUID) {
        onOpenSession?(id)
    }

    func displayedSessions() -> [TerminalSession] {
        var filtered = sessions
        if let commandFilter = providerFilter.commandFilter {
            filtered = filtered.filter { $0.command == commandFilter }
        }
        return filtered
    }

    private func scheduleSearch() {
        searchDebounceTask?.cancel()
        searchDebounceTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled else { return }
            self?.performSearch()
        }
    }

    private func performSearch() {
        Task {
            if searchQuery.isEmpty {
                searchResults = []
            } else {
                searchResults = await service.search(
                    query: searchQuery,
                    providerFilter: providerFilter.commandFilter
                )
            }
            onSessionsChanged?()
        }
    }
}
