import Foundation

struct BatchRenamePresetsConfig: Codable, Sendable {
    var presets: [BatchRenamePreset]

    init(presets: [BatchRenamePreset] = []) {
        self.presets = presets
    }
}
