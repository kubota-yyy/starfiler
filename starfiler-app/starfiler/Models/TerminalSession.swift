import Foundation

enum TerminalSessionStatus: String, Sendable {
    case launching
    case running
    case waitingForInput
    case completed
    case error
}

enum TerminalSessionCommand: String, Sendable {
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

    init(
        id: UUID = UUID(),
        title: String? = nil,
        command: TerminalSessionCommand,
        workingDirectory: URL
    ) {
        self.id = id
        self.title = title ?? command.displayName
        self.status = .launching
        self.command = command
        self.workingDirectory = workingDirectory
        self.exitCode = nil
        self.createdAt = Date()
        self.lastActivityAt = Date()
    }
}
