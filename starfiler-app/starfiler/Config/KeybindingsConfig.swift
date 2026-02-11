import Foundation

struct KeybindingsConfig: Codable, Sendable {
    var bindings: [String: [String: String]]

    init(bindings: [String: [String: String]] = [:]) {
        self.bindings = bindings
    }
}
