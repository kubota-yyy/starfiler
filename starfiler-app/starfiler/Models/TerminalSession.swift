import Foundation

enum TerminalSessionStatus: String, Sendable, Codable {
    case launching
    case running
    case waitingForInput
    case completed
    case error
    case stopped

    var isActive: Bool {
        switch self {
        case .launching, .running, .waitingForInput:
            return true
        case .completed, .error, .stopped:
            return false
        }
    }
}

enum TerminalSessionCommand: String, Sendable, Codable {
    case claude
    case codex

    var displayName: String {
        switch self {
        case .claude: return "Claude Code"
        case .codex: return "Codex CLI"
        }
    }

    var executableName: String {
        switch self {
        case .claude: return "claude"
        case .codex: return "codex"
        }
    }
}

struct TerminalSession: Identifiable, Sendable {
    let id: UUID
    var title: String
    var status: TerminalSessionStatus
    let workingDirectory: URL
    let command: TerminalSessionCommand
    var exitCode: Int32?
    let createdAt: Date
    var lastActivityAt: Date
    var isPinned: Bool
    var lastOpenedAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        title: String? = nil,
        command: TerminalSessionCommand,
        workingDirectory: URL,
        isPinned: Bool = false
    ) {
        self.id = id
        self.title = title ?? command.displayName
        self.status = .launching
        self.command = command
        self.workingDirectory = workingDirectory
        self.exitCode = nil
        let now = Date()
        self.createdAt = now
        self.lastActivityAt = now
        self.isPinned = isPinned
        self.lastOpenedAt = now
        self.updatedAt = now
    }
}
