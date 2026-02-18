import Foundation

struct KeybindingsConfig: Codable, Sendable {
    static let unboundActionName = "__unbound__"

    var bindings: [String: [String: String]]

    init(bindings: [String: [String: String]] = [:]) {
        self.bindings = bindings
    }

    static func isUnboundActionName(_ actionName: String) -> Bool {
        actionName == unboundActionName
    }
}
