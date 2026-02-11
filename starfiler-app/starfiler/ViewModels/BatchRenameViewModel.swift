import Foundation
import Observation

@MainActor
@Observable
final class BatchRenameViewModel {
    let sourceFiles: [FileItem]
    let allDirectoryFiles: [FileItem]

    var rules: [BatchRenameRule] {
        didSet { recomputePreview() }
    }

    var selectedRuleIndex: Int?

    private(set) var previewEntries: [BatchRenameEntry]
    private(set) var hasConflicts: Bool
    private(set) var errorMessage: String?

    private(set) var presets: [BatchRenamePreset]

    var canApply: Bool {
        !previewEntries.isEmpty
            && !hasConflicts
            && previewEntries.contains(where: { $0.originalName != $0.newName })
    }

    var changedCount: Int {
        previewEntries.filter { $0.originalName != $0.newName && !$0.hasConflict }.count
    }

    var conflictCount: Int {
        previewEntries.filter(\.hasConflict).count
    }

    private let renameService: any BatchRenameComputing
    private let configManager: ConfigManager

    var onApplyRequested: (([FileLocationChange]) -> Void)?
    var onDismissRequested: (() -> Void)?

    init(
        sourceFiles: [FileItem],
        allDirectoryFiles: [FileItem],
        configManager: ConfigManager,
        renameService: any BatchRenameComputing = BatchRenameService()
    ) {
        self.sourceFiles = sourceFiles
        self.allDirectoryFiles = allDirectoryFiles
        self.configManager = configManager
        self.renameService = renameService
        self.rules = []
        self.selectedRuleIndex = nil
        self.previewEntries = []
        self.hasConflicts = false
        self.errorMessage = nil
        self.presets = configManager.loadBatchRenamePresetsConfig().presets
    }

    // MARK: - Rule Management

    func addRule(_ rule: BatchRenameRule) {
        rules.append(rule)
        selectedRuleIndex = rules.count - 1
    }

    func removeRule(at index: Int) {
        guard rules.indices.contains(index) else { return }
        rules.remove(at: index)
        if let selected = selectedRuleIndex {
            if selected >= rules.count {
                selectedRuleIndex = rules.isEmpty ? nil : rules.count - 1
            } else if selected > index {
                selectedRuleIndex = selected - 1
            }
        }
    }

    func moveRuleUp(at index: Int) {
        guard index > 0, rules.indices.contains(index) else { return }
        rules.swapAt(index, index - 1)
        if selectedRuleIndex == index {
            selectedRuleIndex = index - 1
        } else if selectedRuleIndex == index - 1 {
            selectedRuleIndex = index
        }
    }

    func moveRuleDown(at index: Int) {
        guard index < rules.count - 1, rules.indices.contains(index) else { return }
        rules.swapAt(index, index + 1)
        if selectedRuleIndex == index {
            selectedRuleIndex = index + 1
        } else if selectedRuleIndex == index + 1 {
            selectedRuleIndex = index
        }
    }

    func updateRule(at index: Int, with rule: BatchRenameRule) {
        guard rules.indices.contains(index) else { return }
        rules[index] = rule
    }

    // MARK: - Preview

    func recomputePreview() {
        guard !rules.isEmpty else {
            previewEntries = sourceFiles.map {
                BatchRenameEntry(
                    originalURL: $0.url,
                    originalName: $0.name,
                    newName: $0.name,
                    hasConflict: false,
                    errorMessage: nil
                )
            }
            hasConflicts = false
            errorMessage = nil
            return
        }

        let entries = renameService.computeNewNames(
            files: sourceFiles,
            rules: rules,
            allDirectoryFiles: allDirectoryFiles
        )

        previewEntries = entries
        hasConflicts = entries.contains(where: \.hasConflict)
        errorMessage = entries.compactMap(\.errorMessage).first
    }

    // MARK: - Preset Management

    func saveCurrentRulesAsPreset(name: String) {
        guard !rules.isEmpty, !name.isEmpty else { return }
        let preset = BatchRenamePreset(name: name, rules: rules)
        presets.append(preset)
        persistPresets()
    }

    func applyPreset(at index: Int) {
        guard presets.indices.contains(index) else { return }
        rules = presets[index].rules
        selectedRuleIndex = rules.isEmpty ? nil : 0
    }

    func deletePreset(at index: Int) {
        guard presets.indices.contains(index) else { return }
        presets.remove(at: index)
        persistPresets()
    }

    private func persistPresets() {
        let config = BatchRenamePresetsConfig(presets: presets)
        try? configManager.saveBatchRenamePresetsConfig(config)
    }

    // MARK: - Actions

    func apply() {
        let changes = previewEntries
            .filter { $0.originalName != $0.newName && !$0.hasConflict }
            .map { entry in
                let destination = entry.originalURL
                    .deletingLastPathComponent()
                    .appendingPathComponent(entry.newName)
                return FileLocationChange(source: entry.originalURL, destination: destination)
            }

        guard !changes.isEmpty else { return }
        onApplyRequested?(changes)
    }

    func cancel() {
        onDismissRequested?()
    }
}
