import Foundation

struct BatchRenameEntry: Hashable, Sendable {
    let originalURL: URL
    let originalName: String
    let newName: String
    let hasConflict: Bool
    let errorMessage: String?
}
