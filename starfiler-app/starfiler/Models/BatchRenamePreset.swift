import Foundation

struct BatchRenamePreset: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    var name: String
    var rules: [BatchRenameRule]
    var createdAt: Date

    init(name: String, rules: [BatchRenameRule]) {
        self.id = UUID()
        self.name = name
        self.rules = rules
        self.createdAt = Date()
    }
}
