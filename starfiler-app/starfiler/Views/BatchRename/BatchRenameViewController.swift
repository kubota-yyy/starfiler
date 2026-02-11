import AppKit

final class BatchRenameViewController: NSViewController {
    private let viewModel: BatchRenameViewModel

    // Rules section
    private let rulesTableView = NSTableView()
    private let addRuleButton = NSPopUpButton(frame: .zero, pullsDown: true)
    private let removeRuleButton = NSButton()
    private let moveUpButton = NSButton()
    private let moveDownButton = NSButton()

    // Rule editor
    private let ruleEditorContainer = NSView()
    private var currentRuleEditorViews: [NSView] = []

    // Preview section
    private let previewTableView = NSTableView()

    // Preset section
    private let presetPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let savePresetButton = NSButton()
    private let deletePresetButton = NSButton()

    // Bottom bar
    private let conflictLabel = NSTextField(labelWithString: "")
    private let cancelButton = NSButton()
    private let applyButton = NSButton()

    init(viewModel: BatchRenameViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 720, height: 600))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupPresetBar()
        setupRulesSection()
        setupRuleEditor()
        setupPreviewSection()
        setupBottomBar()
        setupLayout()
        refreshPresetPopup()
        refreshPreview()
    }

    // MARK: - Setup

    private func setupPresetBar() {
        presetPopup.translatesAutoresizingMaskIntoConstraints = false

        savePresetButton.title = "Save"
        savePresetButton.bezelStyle = .rounded
        savePresetButton.translatesAutoresizingMaskIntoConstraints = false
        savePresetButton.target = self
        savePresetButton.action = #selector(savePresetClicked)

        deletePresetButton.title = "Delete"
        deletePresetButton.bezelStyle = .rounded
        deletePresetButton.translatesAutoresizingMaskIntoConstraints = false
        deletePresetButton.target = self
        deletePresetButton.action = #selector(deletePresetClicked)
    }

    private func setupRulesSection() {
        let nameColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("ruleDescription"))
        nameColumn.title = "Rules"
        nameColumn.minWidth = 200
        rulesTableView.addTableColumn(nameColumn)
        rulesTableView.headerView = NSTableHeaderView()
        rulesTableView.dataSource = self
        rulesTableView.delegate = self
        rulesTableView.translatesAutoresizingMaskIntoConstraints = false
        rulesTableView.allowsMultipleSelection = false
        rulesTableView.target = self
        rulesTableView.action = #selector(rulesTableSelectionChanged)

        addRuleButton.translatesAutoresizingMaskIntoConstraints = false
        addRuleButton.addItem(withTitle: "+ Add Rule")
        addRuleButton.addItem(withTitle: "Regex Replace")
        addRuleButton.addItem(withTitle: "Find & Replace")
        addRuleButton.addItem(withTitle: "Sequential Number")
        addRuleButton.addItem(withTitle: "Date Insertion")
        addRuleButton.addItem(withTitle: "Case Conversion")
        addRuleButton.target = self
        addRuleButton.action = #selector(addRuleSelected(_:))

        removeRuleButton.title = "Remove"
        removeRuleButton.bezelStyle = .rounded
        removeRuleButton.translatesAutoresizingMaskIntoConstraints = false
        removeRuleButton.target = self
        removeRuleButton.action = #selector(removeRuleClicked)

        moveUpButton.title = "\u{25B2}"
        moveUpButton.bezelStyle = .rounded
        moveUpButton.translatesAutoresizingMaskIntoConstraints = false
        moveUpButton.target = self
        moveUpButton.action = #selector(moveRuleUpClicked)

        moveDownButton.title = "\u{25BC}"
        moveDownButton.bezelStyle = .rounded
        moveDownButton.translatesAutoresizingMaskIntoConstraints = false
        moveDownButton.target = self
        moveDownButton.action = #selector(moveRuleDownClicked)
    }

    private func setupRuleEditor() {
        ruleEditorContainer.translatesAutoresizingMaskIntoConstraints = false
        ruleEditorContainer.wantsLayer = true
        ruleEditorContainer.layer?.borderWidth = 0.5
        ruleEditorContainer.layer?.borderColor = NSColor.separatorColor.cgColor
        ruleEditorContainer.layer?.cornerRadius = 4
    }

    private func setupPreviewSection() {
        let originalColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("originalName"))
        originalColumn.title = "Original Name"
        originalColumn.width = 280
        originalColumn.minWidth = 150
        previewTableView.addTableColumn(originalColumn)

        let arrowColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("arrow"))
        arrowColumn.title = ""
        arrowColumn.width = 30
        arrowColumn.minWidth = 30
        arrowColumn.maxWidth = 30
        previewTableView.addTableColumn(arrowColumn)

        let newNameColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("newName"))
        newNameColumn.title = "New Name"
        newNameColumn.width = 280
        newNameColumn.minWidth = 150
        previewTableView.addTableColumn(newNameColumn)

        previewTableView.headerView = NSTableHeaderView()
        previewTableView.dataSource = self
        previewTableView.delegate = self
        previewTableView.translatesAutoresizingMaskIntoConstraints = false
        previewTableView.usesAlternatingRowBackgroundColors = true
    }

    private func setupBottomBar() {
        conflictLabel.translatesAutoresizingMaskIntoConstraints = false
        conflictLabel.font = .systemFont(ofSize: 12)

        cancelButton.title = "Cancel"
        cancelButton.bezelStyle = .rounded
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.target = self
        cancelButton.action = #selector(cancelClicked)
        cancelButton.keyEquivalent = "\u{1B}"

        applyButton.title = "Apply"
        applyButton.bezelStyle = .rounded
        applyButton.translatesAutoresizingMaskIntoConstraints = false
        applyButton.target = self
        applyButton.action = #selector(applyClicked)
        applyButton.keyEquivalent = "\r"
    }

    private func setupLayout() {
        let presetLabel = NSTextField(labelWithString: "Preset:")
        presetLabel.translatesAutoresizingMaskIntoConstraints = false

        let presetBar = NSStackView(views: [presetLabel, presetPopup, savePresetButton, deletePresetButton])
        presetBar.orientation = .horizontal
        presetBar.spacing = 8
        presetBar.translatesAutoresizingMaskIntoConstraints = false

        let rulesScrollView = NSScrollView()
        rulesScrollView.documentView = rulesTableView
        rulesScrollView.hasVerticalScroller = true
        rulesScrollView.translatesAutoresizingMaskIntoConstraints = false
        rulesScrollView.borderType = .bezelBorder

        let rulesButtons = NSStackView(views: [addRuleButton, removeRuleButton, moveUpButton, moveDownButton])
        rulesButtons.orientation = .horizontal
        rulesButtons.spacing = 4
        rulesButtons.translatesAutoresizingMaskIntoConstraints = false

        let previewScrollView = NSScrollView()
        previewScrollView.documentView = previewTableView
        previewScrollView.hasVerticalScroller = true
        previewScrollView.translatesAutoresizingMaskIntoConstraints = false
        previewScrollView.borderType = .bezelBorder

        let previewLabel = NSTextField(labelWithString: "Preview")
        previewLabel.font = .boldSystemFont(ofSize: 12)
        previewLabel.translatesAutoresizingMaskIntoConstraints = false

        let bottomBar = NSStackView(views: [conflictLabel, NSView(), cancelButton, applyButton])
        bottomBar.orientation = .horizontal
        bottomBar.spacing = 8
        bottomBar.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(presetBar)
        view.addSubview(rulesScrollView)
        view.addSubview(rulesButtons)
        view.addSubview(ruleEditorContainer)
        view.addSubview(previewLabel)
        view.addSubview(previewScrollView)
        view.addSubview(bottomBar)

        NSLayoutConstraint.activate([
            presetBar.topAnchor.constraint(equalTo: view.topAnchor, constant: 12),
            presetBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            presetBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),

            rulesScrollView.topAnchor.constraint(equalTo: presetBar.bottomAnchor, constant: 12),
            rulesScrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            rulesScrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            rulesScrollView.heightAnchor.constraint(equalToConstant: 100),

            rulesButtons.topAnchor.constraint(equalTo: rulesScrollView.bottomAnchor, constant: 4),
            rulesButtons.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),

            ruleEditorContainer.topAnchor.constraint(equalTo: rulesButtons.bottomAnchor, constant: 8),
            ruleEditorContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            ruleEditorContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            ruleEditorContainer.heightAnchor.constraint(greaterThanOrEqualToConstant: 44),

            previewLabel.topAnchor.constraint(equalTo: ruleEditorContainer.bottomAnchor, constant: 12),
            previewLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),

            previewScrollView.topAnchor.constraint(equalTo: previewLabel.bottomAnchor, constant: 4),
            previewScrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            previewScrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),

            bottomBar.topAnchor.constraint(equalTo: previewScrollView.bottomAnchor, constant: 12),
            bottomBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            bottomBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            bottomBar.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -12),
        ])
    }

    // MARK: - Refresh

    private func refreshPreview() {
        viewModel.recomputePreview()
        previewTableView.reloadData()
        rulesTableView.reloadData()
        updateBottomBar()
    }

    private func updateBottomBar() {
        let conflicts = viewModel.conflictCount
        let changes = viewModel.changedCount
        if conflicts > 0 {
            conflictLabel.stringValue = "Conflicts: \(conflicts)"
            conflictLabel.textColor = .systemRed
        } else {
            conflictLabel.stringValue = "\(changes) file(s) will be renamed"
            conflictLabel.textColor = .secondaryLabelColor
        }
        applyButton.title = "Apply (\(changes) files)"
        applyButton.isEnabled = viewModel.canApply
    }

    private func refreshPresetPopup() {
        presetPopup.removeAllItems()
        if viewModel.presets.isEmpty {
            presetPopup.addItem(withTitle: "(No presets)")
        } else {
            for preset in viewModel.presets {
                presetPopup.addItem(withTitle: preset.name)
            }
        }
    }

    private func refreshRuleEditor() {
        for v in currentRuleEditorViews {
            v.removeFromSuperview()
        }
        currentRuleEditorViews.removeAll()

        guard let index = viewModel.selectedRuleIndex,
              viewModel.rules.indices.contains(index) else {
            let placeholder = NSTextField(labelWithString: "Select a rule to edit")
            placeholder.textColor = .secondaryLabelColor
            placeholder.translatesAutoresizingMaskIntoConstraints = false
            ruleEditorContainer.addSubview(placeholder)
            NSLayoutConstraint.activate([
                placeholder.centerXAnchor.constraint(equalTo: ruleEditorContainer.centerXAnchor),
                placeholder.centerYAnchor.constraint(equalTo: ruleEditorContainer.centerYAnchor),
            ])
            currentRuleEditorViews = [placeholder]
            return
        }

        let rule = viewModel.rules[index]
        let editorView = buildRuleEditorView(for: rule, at: index)
        editorView.translatesAutoresizingMaskIntoConstraints = false
        ruleEditorContainer.addSubview(editorView)
        NSLayoutConstraint.activate([
            editorView.topAnchor.constraint(equalTo: ruleEditorContainer.topAnchor, constant: 8),
            editorView.leadingAnchor.constraint(equalTo: ruleEditorContainer.leadingAnchor, constant: 8),
            editorView.trailingAnchor.constraint(equalTo: ruleEditorContainer.trailingAnchor, constant: -8),
            editorView.bottomAnchor.constraint(lessThanOrEqualTo: ruleEditorContainer.bottomAnchor, constant: -8),
        ])
        currentRuleEditorViews = [editorView]
    }

    private func buildRuleEditorView(for rule: BatchRenameRule, at index: Int) -> NSView {
        let container = NSView()

        switch rule {
        case .regexReplace(let pattern, let replacement, let caseInsensitive):
            let patternLabel = NSTextField(labelWithString: "Pattern:")
            let patternField = NSTextField(string: pattern)
            patternField.placeholderString = "Regular expression"
            let replLabel = NSTextField(labelWithString: "Replace:")
            let replField = NSTextField(string: replacement)
            replField.placeholderString = "Replacement"
            let caseCheck = NSButton(checkboxWithTitle: "Case Insensitive", target: nil, action: nil)
            caseCheck.state = caseInsensitive ? .on : .off

            let ruleIndex = index
            let update = { [weak self] in
                guard let self else { return }
                let updated = BatchRenameRule.regexReplace(
                    pattern: patternField.stringValue,
                    replacement: replField.stringValue,
                    caseInsensitive: caseCheck.state == .on
                )
                self.viewModel.updateRule(at: ruleIndex, with: updated)
                self.refreshPreview()
            }

            patternField.target = self
            patternField.delegate = self
            patternField.tag = ruleIndex
            replField.target = self
            replField.delegate = self
            replField.tag = ruleIndex
            caseCheck.target = self
            caseCheck.action = #selector(ruleEditorCheckboxChanged(_:))
            caseCheck.tag = ruleIndex

            for v in [patternLabel, patternField, replLabel, replField, caseCheck] as [NSView] {
                v.translatesAutoresizingMaskIntoConstraints = false
                container.addSubview(v)
            }

            NSLayoutConstraint.activate([
                patternLabel.topAnchor.constraint(equalTo: container.topAnchor),
                patternLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                patternLabel.widthAnchor.constraint(equalToConstant: 60),
                patternField.centerYAnchor.constraint(equalTo: patternLabel.centerYAnchor),
                patternField.leadingAnchor.constraint(equalTo: patternLabel.trailingAnchor, constant: 4),
                patternField.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                replLabel.topAnchor.constraint(equalTo: patternLabel.bottomAnchor, constant: 4),
                replLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                replLabel.widthAnchor.constraint(equalToConstant: 60),
                replField.centerYAnchor.constraint(equalTo: replLabel.centerYAnchor),
                replField.leadingAnchor.constraint(equalTo: replLabel.trailingAnchor, constant: 4),
                replField.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                caseCheck.topAnchor.constraint(equalTo: replLabel.bottomAnchor, constant: 4),
                caseCheck.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                caseCheck.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            ])

            // Store closure for retrieval
            objc_setAssociatedObject(container, &AssociatedKeys.updateClosure, update as () -> Void, .OBJC_ASSOCIATION_RETAIN)

        case .findReplace(let find, let replace):
            let findLabel = NSTextField(labelWithString: "Find:")
            let findField = NSTextField(string: find)
            findField.placeholderString = "Text to find"
            let replLabel = NSTextField(labelWithString: "Replace:")
            let replField = NSTextField(string: replace)
            replField.placeholderString = "Replacement"

            let ruleIndex = index
            let update = { [weak self] in
                guard let self else { return }
                let updated = BatchRenameRule.findReplace(
                    find: findField.stringValue,
                    replace: replField.stringValue
                )
                self.viewModel.updateRule(at: ruleIndex, with: updated)
                self.refreshPreview()
            }

            findField.delegate = self
            findField.tag = ruleIndex
            replField.delegate = self
            replField.tag = ruleIndex

            for v in [findLabel, findField, replLabel, replField] as [NSView] {
                v.translatesAutoresizingMaskIntoConstraints = false
                container.addSubview(v)
            }

            NSLayoutConstraint.activate([
                findLabel.topAnchor.constraint(equalTo: container.topAnchor),
                findLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                findLabel.widthAnchor.constraint(equalToConstant: 60),
                findField.centerYAnchor.constraint(equalTo: findLabel.centerYAnchor),
                findField.leadingAnchor.constraint(equalTo: findLabel.trailingAnchor, constant: 4),
                findField.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                replLabel.topAnchor.constraint(equalTo: findLabel.bottomAnchor, constant: 4),
                replLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                replLabel.widthAnchor.constraint(equalToConstant: 60),
                replField.centerYAnchor.constraint(equalTo: replLabel.centerYAnchor),
                replField.leadingAnchor.constraint(equalTo: replLabel.trailingAnchor, constant: 4),
                replField.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                replLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            ])

            objc_setAssociatedObject(container, &AssociatedKeys.updateClosure, update as () -> Void, .OBJC_ASSOCIATION_RETAIN)

        case .sequentialNumber(let position, let start, let step, let padding):
            let posLabel = NSTextField(labelWithString: "Position:")
            let posPopup = NSPopUpButton(frame: .zero, pullsDown: false)
            posPopup.addItems(withTitles: ["Prefix", "Suffix", "Replace"])
            posPopup.selectItem(at: positionIndex(position))
            let startLabel = NSTextField(labelWithString: "Start:")
            let startField = NSTextField(string: "\(start)")
            let stepLabel = NSTextField(labelWithString: "Step:")
            let stepField = NSTextField(string: "\(step)")
            let padLabel = NSTextField(labelWithString: "Padding:")
            let padField = NSTextField(string: "\(padding)")

            let ruleIndex = index
            let update = { [weak self] in
                guard let self else { return }
                let pos = self.positionFromIndex(posPopup.indexOfSelectedItem)
                let updated = BatchRenameRule.sequentialNumber(
                    position: pos,
                    start: Int(startField.stringValue) ?? start,
                    step: Int(stepField.stringValue) ?? step,
                    padding: Int(padField.stringValue) ?? padding
                )
                self.viewModel.updateRule(at: ruleIndex, with: updated)
                self.refreshPreview()
            }

            for field in [startField, stepField, padField] {
                field.delegate = self
                field.tag = ruleIndex
            }
            posPopup.target = self
            posPopup.action = #selector(ruleEditorPopupChanged(_:))
            posPopup.tag = ruleIndex

            let row1 = NSStackView(views: [posLabel, posPopup, startLabel, startField, stepLabel, stepField, padLabel, padField])
            row1.orientation = .horizontal
            row1.spacing = 4
            row1.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(row1)
            NSLayoutConstraint.activate([
                row1.topAnchor.constraint(equalTo: container.topAnchor),
                row1.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                row1.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor),
                row1.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            ])

            objc_setAssociatedObject(container, &AssociatedKeys.updateClosure, update as () -> Void, .OBJC_ASSOCIATION_RETAIN)

        case .dateInsertion(let position, let format, let source):
            let posLabel = NSTextField(labelWithString: "Position:")
            let posPopup = NSPopUpButton(frame: .zero, pullsDown: false)
            posPopup.addItems(withTitles: ["Prefix", "Suffix", "Replace"])
            posPopup.selectItem(at: positionIndex(position))
            let fmtLabel = NSTextField(labelWithString: "Format:")
            let fmtField = NSTextField(string: format)
            fmtField.placeholderString = "yyyy-MM-dd"
            let srcLabel = NSTextField(labelWithString: "Source:")
            let srcPopup = NSPopUpButton(frame: .zero, pullsDown: false)
            srcPopup.addItems(withTitles: ["File Modified", "Current Date"])
            srcPopup.selectItem(at: source == .fileModified ? 0 : 1)

            let ruleIndex = index
            let update = { [weak self] in
                guard let self else { return }
                let pos = self.positionFromIndex(posPopup.indexOfSelectedItem)
                let src: BatchRenameRule.DateSource = srcPopup.indexOfSelectedItem == 0 ? .fileModified : .currentDate
                let updated = BatchRenameRule.dateInsertion(
                    position: pos,
                    format: fmtField.stringValue.isEmpty ? "yyyy-MM-dd" : fmtField.stringValue,
                    source: src
                )
                self.viewModel.updateRule(at: ruleIndex, with: updated)
                self.refreshPreview()
            }

            fmtField.delegate = self
            fmtField.tag = ruleIndex
            posPopup.target = self
            posPopup.action = #selector(ruleEditorPopupChanged(_:))
            posPopup.tag = ruleIndex
            srcPopup.target = self
            srcPopup.action = #selector(ruleEditorPopupChanged(_:))
            srcPopup.tag = ruleIndex

            let row = NSStackView(views: [posLabel, posPopup, fmtLabel, fmtField, srcLabel, srcPopup])
            row.orientation = .horizontal
            row.spacing = 4
            row.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(row)
            NSLayoutConstraint.activate([
                row.topAnchor.constraint(equalTo: container.topAnchor),
                row.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                row.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor),
                row.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            ])

            objc_setAssociatedObject(container, &AssociatedKeys.updateClosure, update as () -> Void, .OBJC_ASSOCIATION_RETAIN)

        case .caseConversion(let type):
            let typeLabel = NSTextField(labelWithString: "Type:")
            let typePopup = NSPopUpButton(frame: .zero, pullsDown: false)
            typePopup.addItems(withTitles: ["UPPER", "lower", "Title", "camelCase", "snake_case"])
            typePopup.selectItem(at: caseTypeIndex(type))

            let ruleIndex = index
            let update = { [weak self] in
                guard let self else { return }
                let caseType = self.caseTypeFromIndex(typePopup.indexOfSelectedItem)
                let updated = BatchRenameRule.caseConversion(caseType)
                self.viewModel.updateRule(at: ruleIndex, with: updated)
                self.refreshPreview()
            }

            typePopup.target = self
            typePopup.action = #selector(ruleEditorPopupChanged(_:))
            typePopup.tag = ruleIndex

            let row = NSStackView(views: [typeLabel, typePopup])
            row.orientation = .horizontal
            row.spacing = 4
            row.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(row)
            NSLayoutConstraint.activate([
                row.topAnchor.constraint(equalTo: container.topAnchor),
                row.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                row.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            ])

            objc_setAssociatedObject(container, &AssociatedKeys.updateClosure, update as () -> Void, .OBJC_ASSOCIATION_RETAIN)
        }

        return container
    }

    // MARK: - Actions

    @objc private func addRuleSelected(_ sender: NSPopUpButton) {
        let index = sender.indexOfSelectedItem
        guard index > 0 else { return }

        let rule: BatchRenameRule
        switch index {
        case 1: rule = .regexReplace(pattern: "", replacement: "", caseInsensitive: false)
        case 2: rule = .findReplace(find: "", replace: "")
        case 3: rule = .sequentialNumber(position: .prefix, start: 1, step: 1, padding: 3)
        case 4: rule = .dateInsertion(position: .prefix, format: "yyyy-MM-dd", source: .fileModified)
        case 5: rule = .caseConversion(.lower)
        default: return
        }

        viewModel.addRule(rule)
        refreshPreview()
        rulesTableView.selectRowIndexes(IndexSet(integer: viewModel.rules.count - 1), byExtendingSelection: false)
        refreshRuleEditor()
        sender.selectItem(at: 0)
    }

    @objc private func removeRuleClicked() {
        guard let index = viewModel.selectedRuleIndex else { return }
        viewModel.removeRule(at: index)
        refreshPreview()
        refreshRuleEditor()
    }

    @objc private func moveRuleUpClicked() {
        guard let index = viewModel.selectedRuleIndex else { return }
        viewModel.moveRuleUp(at: index)
        refreshPreview()
        if let newIndex = viewModel.selectedRuleIndex {
            rulesTableView.selectRowIndexes(IndexSet(integer: newIndex), byExtendingSelection: false)
        }
    }

    @objc private func moveRuleDownClicked() {
        guard let index = viewModel.selectedRuleIndex else { return }
        viewModel.moveRuleDown(at: index)
        refreshPreview()
        if let newIndex = viewModel.selectedRuleIndex {
            rulesTableView.selectRowIndexes(IndexSet(integer: newIndex), byExtendingSelection: false)
        }
    }

    @objc private func rulesTableSelectionChanged() {
        let row = rulesTableView.selectedRow
        viewModel.selectedRuleIndex = row >= 0 ? row : nil
        refreshRuleEditor()
    }

    @objc private func ruleEditorCheckboxChanged(_ sender: NSButton) {
        triggerRuleEditorUpdate()
    }

    @objc private func ruleEditorPopupChanged(_ sender: NSPopUpButton) {
        triggerRuleEditorUpdate()
    }

    private func triggerRuleEditorUpdate() {
        guard let container = currentRuleEditorViews.first,
              let update = objc_getAssociatedObject(container, &AssociatedKeys.updateClosure) as? () -> Void else {
            return
        }
        update()
    }

    @objc private func savePresetClicked() {
        let alert = NSAlert()
        alert.messageText = "Save Preset"
        alert.informativeText = "Enter a name for this preset."
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")

        let field = NSTextField(string: "")
        field.frame = NSRect(x: 0, y: 0, width: 300, height: 24)
        field.placeholderString = "Preset name"
        alert.accessoryView = field

        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let name = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }

        viewModel.saveCurrentRulesAsPreset(name: name)
        refreshPresetPopup()
    }

    @objc private func deletePresetClicked() {
        let index = presetPopup.indexOfSelectedItem
        guard index >= 0, index < viewModel.presets.count else { return }
        viewModel.deletePreset(at: index)
        refreshPresetPopup()
    }

    @objc private func cancelClicked() {
        viewModel.cancel()
    }

    @objc private func applyClicked() {
        viewModel.apply()
    }

    // MARK: - Helpers

    private func positionIndex(_ position: BatchRenameRule.InsertPosition) -> Int {
        switch position {
        case .prefix: return 0
        case .suffix: return 1
        case .replace: return 2
        }
    }

    private func positionFromIndex(_ index: Int) -> BatchRenameRule.InsertPosition {
        switch index {
        case 0: return .prefix
        case 1: return .suffix
        default: return .replace
        }
    }

    private func caseTypeIndex(_ type: BatchRenameRule.CaseConversionType) -> Int {
        switch type {
        case .upper: return 0
        case .lower: return 1
        case .title: return 2
        case .camelCase: return 3
        case .snakeCase: return 4
        }
    }

    private func caseTypeFromIndex(_ index: Int) -> BatchRenameRule.CaseConversionType {
        switch index {
        case 0: return .upper
        case 1: return .lower
        case 2: return .title
        case 3: return .camelCase
        default: return .snakeCase
        }
    }
}

// MARK: - NSTableViewDataSource & NSTableViewDelegate

extension BatchRenameViewController: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int {
        if tableView === rulesTableView {
            return viewModel.rules.count
        } else {
            return viewModel.previewEntries.count
        }
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let identifier = tableColumn?.identifier ?? NSUserInterfaceItemIdentifier("cell")

        if tableView === rulesTableView {
            let cellView = tableView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView
                ?? makeTextCellView(identifier: identifier)
            cellView.textField?.stringValue = viewModel.rules[row].displayDescription
            return cellView
        }

        guard row < viewModel.previewEntries.count else { return nil }
        let entry = viewModel.previewEntries[row]

        let cellView = tableView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView
            ?? makeTextCellView(identifier: identifier)

        switch identifier.rawValue {
        case "originalName":
            cellView.textField?.stringValue = entry.originalName
            cellView.textField?.textColor = .labelColor
        case "arrow":
            cellView.textField?.stringValue = entry.originalName != entry.newName ? "\u{2192}" : "="
            cellView.textField?.alignment = .center
            cellView.textField?.textColor = .secondaryLabelColor
        case "newName":
            cellView.textField?.stringValue = entry.newName
            if entry.hasConflict {
                cellView.textField?.textColor = .systemRed
            } else if entry.originalName != entry.newName {
                cellView.textField?.textColor = .systemBlue
            } else {
                cellView.textField?.textColor = .secondaryLabelColor
            }
        default:
            break
        }

        return cellView
    }

    private func makeTextCellView(identifier: NSUserInterfaceItemIdentifier) -> NSTableCellView {
        let cellView = NSTableCellView()
        cellView.identifier = identifier
        let textField = NSTextField(labelWithString: "")
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.lineBreakMode = .byTruncatingTail
        cellView.addSubview(textField)
        cellView.textField = textField
        NSLayoutConstraint.activate([
            textField.leadingAnchor.constraint(equalTo: cellView.leadingAnchor, constant: 4),
            textField.trailingAnchor.constraint(equalTo: cellView.trailingAnchor, constant: -4),
            textField.centerYAnchor.constraint(equalTo: cellView.centerYAnchor),
        ])
        return cellView
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        22
    }
}

// MARK: - NSTextFieldDelegate

extension BatchRenameViewController: NSTextFieldDelegate {
    func controlTextDidEndEditing(_ obj: Notification) {
        triggerRuleEditorUpdate()
    }
}

// MARK: - Associated Keys

private enum AssociatedKeys {
    static var updateClosure = 0
}
