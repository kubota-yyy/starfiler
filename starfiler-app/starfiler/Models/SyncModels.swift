import Foundation

// MARK: - Sync Direction

enum SyncDirection: String, Codable, Sendable, CaseIterable {
    case leftToRight
    case rightToLeft
    case bidirectional

    var displayName: String {
        switch self {
        case .leftToRight: return "Left \u{2192} Right"
        case .rightToLeft: return "Left \u{2190} Right"
        case .bidirectional: return "\u{2194} Bidirectional"
        }
    }
}

// MARK: - Sync Item Status

enum SyncItemStatus: String, Codable, Sendable {
    case identical
    case leftOnly
    case rightOnly
    case leftNewer
    case rightNewer
    case conflict
    case excluded

    var displaySymbol: String {
        switch self {
        case .identical: return "="
        case .leftOnly: return "L"
        case .rightOnly: return "R"
        case .leftNewer: return "L>"
        case .rightNewer: return "<R"
        case .conflict: return "!!"
        case .excluded: return "--"
        }
    }
}

// MARK: - Sync Action

enum SyncItemAction: String, Codable, Sendable {
    case skip
    case copyToRight
    case copyToLeft
    case deleteFromLeft
    case deleteFromRight

    var displayArrow: String {
        switch self {
        case .skip: return "=="
        case .copyToRight: return "\u{2192}"
        case .copyToLeft: return "\u{2190}"
        case .deleteFromLeft: return "X\u{2190}"
        case .deleteFromRight: return "\u{2192}X"
        }
    }
}

// MARK: - Sync Item

struct SyncItem: Identifiable, Hashable, Sendable {
    let id: UUID
    let relativePath: String
    let isDirectory: Bool
    let leftURL: URL?
    let rightURL: URL?
    let leftSize: Int64?
    let rightSize: Int64?
    let leftDate: Date?
    let rightDate: Date?
    let status: SyncItemStatus
    var action: SyncItemAction
    var isSelected: Bool

    init(
        relativePath: String,
        isDirectory: Bool,
        leftURL: URL?,
        rightURL: URL?,
        leftSize: Int64?,
        rightSize: Int64?,
        leftDate: Date?,
        rightDate: Date?,
        status: SyncItemStatus,
        action: SyncItemAction
    ) {
        self.id = UUID()
        self.relativePath = relativePath
        self.isDirectory = isDirectory
        self.leftURL = leftURL
        self.rightURL = rightURL
        self.leftSize = leftSize
        self.rightSize = rightSize
        self.leftDate = leftDate
        self.rightDate = rightDate
        self.status = status
        self.action = action
        self.isSelected = action != .skip
    }
}

// MARK: - Exclude Rule

struct SyncExcludeRule: Codable, Hashable, Sendable {
    var pattern: String
    var isEnabled: Bool

    init(pattern: String, isEnabled: Bool = true) {
        self.pattern = pattern
        self.isEnabled = isEnabled
    }

    static let defaults: [SyncExcludeRule] = [
        SyncExcludeRule(pattern: ".DS_Store"),
        SyncExcludeRule(pattern: ".git"),
        SyncExcludeRule(pattern: "*.swp"),
        SyncExcludeRule(pattern: "Thumbs.db"),
    ]
}

// MARK: - Synclet (saved sync configuration)

struct Synclet: Codable, Hashable, Identifiable, Sendable {
    var id: UUID
    var name: String
    var leftPath: String
    var rightPath: String
    var direction: SyncDirection
    var excludeRules: [SyncExcludeRule]
    var createdAt: Date
    var updatedAt: Date

    init(
        name: String,
        leftPath: String,
        rightPath: String,
        direction: SyncDirection = .leftToRight,
        excludeRules: [SyncExcludeRule] = SyncExcludeRule.defaults
    ) {
        self.id = UUID()
        self.name = name
        self.leftPath = leftPath
        self.rightPath = rightPath
        self.direction = direction
        self.excludeRules = excludeRules
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

// MARK: - Sync Phase

enum SyncPhase: Sendable {
    case idle
    case comparing
    case previewReady
    case syncing
    case completed(SyncExecutionResult)
    case error(String)
}

// MARK: - Sync Execution Result

struct SyncExecutionResult: Sendable {
    let copiedCount: Int
    let deletedCount: Int
    let skippedCount: Int
    let errors: [SyncError]
}

// MARK: - Sync Error

struct SyncError: Hashable, Sendable, LocalizedError {
    let relativePath: String
    let message: String

    var errorDescription: String? { "\(relativePath): \(message)" }
}
