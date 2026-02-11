import Foundation

struct SyncletsConfig: Codable, Sendable {
    var synclets: [Synclet]

    init(synclets: [Synclet] = []) {
        self.synclets = synclets
    }
}
