import AppKit

@MainActor
final class BookmarkSearchPanelController: NSObject, NSTableViewDataSource, NSTableViewDelegate, NSTextFieldDelegate {
    private let viewModel: BookmarkSearchViewModel
    private var panel: NSPanel?
    private let searchField = NSTextField()
    private let tableView = NSTableView()
    private let scrollView = NSScrollView()

    private var currentPalette: FilerThemePalette?

    var onSelectEntry: ((BookmarkSearchViewModel.SearchResult) -> Void)?
    var onDismiss: (() -> Void)?

    init(viewModel: BookmarkSearchViewModel) {
        self.viewModel = viewModel
        super.init()
    }

    func applyTheme(_ theme: FilerTheme) {
        currentPalette = theme.palette
    }

    func showRelativeTo(window: NSWindow) {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
            styleMask: [.titled, .closable, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.becomesKeyOnlyIfNeeded = false

        let contentView = NSVisualEffectView()
        contentView.material = .hudWindow
        contentView.blendingMode = .behindWindow
        contentView.state = .active

        configureSearchField()
        configureTableView()

        contentView.addSubview(searchField)
        contentView.addSubview(scrollView)

        NSLayoutConstraint.activate([
            searchField.topAnchor.constraint(equalTo: contentView.safeAreaLayoutGuide.topAnchor, constant: 8),
            searchField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            searchField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            searchField.heightAnchor.constraint(equalToConstant: 28),

            scrollView.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 8),
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
        ])

        panel.contentView = contentView

        let windowFrame = window.frame
        let panelX = windowFrame.midX - 250
        let panelY = windowFrame.midY - 170 + 100
        panel.setFrameOrigin(NSPoint(x: panelX, y: panelY))

        panel.makeKeyAndOrderFront(nil)
        window.addChildWindow(panel, ordered: .above)
        self.panel = panel

        DispatchQueue.main.async { [weak self] in
            self?.panel?.makeFirstResponder(self?.searchField)
        }

        tableView.reloadData()
        updateSelection()
    }

    func dismiss() {
        panel?.orderOut(nil)
        if let panel, let parent = panel.parent {
            parent.removeChildWindow(panel)
        }
        panel = nil
        onDismiss?()
    }

    // MARK: - Configuration

    private func configureSearchField() {
        searchField.translatesAutoresizingMaskIntoConstraints = false
        searchField.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
        searchField.placeholderString = "Search bookmarks & history..."
        searchField.focusRingType = .none
        searchField.isBezeled = true
        searchField.bezelStyle = .roundedBezel
        searchField.delegate = self

        if let palette = currentPalette {
            searchField.wantsLayer = true
            searchField.layer?.borderColor = palette.starAccentColor.withAlphaComponent(0.4).cgColor
            searchField.layer?.borderWidth = 1
            searchField.layer?.cornerRadius = 6
        }
    }

    private func configureTableView() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.headerView = nil
        tableView.rowHeight = 44
        tableView.intercellSpacing = NSSize(width: 0, height: 1)
        tableView.selectionHighlightStyle = .regular
        tableView.allowsTypeSelect = false
        tableView.usesAutomaticRowHeights = false

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("result"))
        column.title = ""
        tableView.addTableColumn(column)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
    }

    // MARK: - NSTableViewDataSource

    func numberOfRows(in tableView: NSTableView) -> Int {
        viewModel.results.count
    }

    // MARK: - NSTableViewDelegate

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard viewModel.results.indices.contains(row) else {
            return nil
        }

        let result = viewModel.results[row]

        let cellIdentifier = NSUserInterfaceItemIdentifier("searchResultCell")
        let cell: NSView

        if let existing = tableView.makeView(withIdentifier: cellIdentifier, owner: self) {
            cell = existing
            if let groupLabel = cell.viewWithTag(1) as? NSTextField {
                groupLabel.stringValue = result.groupName
            }
            if let nameLabel = cell.viewWithTag(2) as? NSTextField {
                nameLabel.stringValue = result.displayName
            }
            if let pathLabel = cell.viewWithTag(3) as? NSTextField {
                pathLabel.stringValue = result.path
            }
            if let hintLabel = cell.viewWithTag(4) as? NSTextField {
                hintLabel.stringValue = result.shortcutHint ?? ""
                hintLabel.isHidden = result.shortcutHint == nil
            }
        } else {
            cell = makeResultCellView(result: result)
            cell.identifier = cellIdentifier
        }

        return cell
    }

    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        true
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        // Selection changed by mouse
    }

    // MARK: - NSTextFieldDelegate

    func controlTextDidChange(_ obj: Notification) {
        viewModel.updateQuery(searchField.stringValue)
        tableView.reloadData()
        updateSelection()
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.moveUp(_:)) {
            viewModel.moveSelectionUp()
            updateSelection()
            return true
        }
        if commandSelector == #selector(NSResponder.moveDown(_:)) {
            viewModel.moveSelectionDown()
            updateSelection()
            return true
        }
        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            if let entry = viewModel.selectedEntry {
                dismiss()
                onSelectEntry?(entry)
            }
            return true
        }
        if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
            dismiss()
            return true
        }
        return false
    }

    // MARK: - Helpers

    private func updateSelection() {
        guard !viewModel.results.isEmpty else {
            tableView.deselectAll(nil)
            return
        }
        let index = viewModel.selectedIndex
        tableView.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
        tableView.scrollRowToVisible(index)
    }

    private func makeResultCellView(result: BookmarkSearchViewModel.SearchResult) -> NSView {
        let container = NSView()

        let groupLabel = NSTextField(labelWithString: result.groupName)
        groupLabel.translatesAutoresizingMaskIntoConstraints = false
        groupLabel.font = .systemFont(ofSize: 10, weight: .medium)
        groupLabel.textColor = .secondaryLabelColor
        groupLabel.alignment = .right
        groupLabel.lineBreakMode = .byTruncatingTail
        groupLabel.tag = 1

        let nameLabel = NSTextField(labelWithString: result.displayName)
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.font = .systemFont(ofSize: 13, weight: .regular)
        nameLabel.lineBreakMode = .byTruncatingTail
        nameLabel.tag = 2

        let pathLabel = NSTextField(labelWithString: result.path)
        pathLabel.translatesAutoresizingMaskIntoConstraints = false
        pathLabel.font = .systemFont(ofSize: 10)
        pathLabel.textColor = .tertiaryLabelColor
        pathLabel.lineBreakMode = .byTruncatingMiddle
        pathLabel.tag = 3

        let hintLabel = NSTextField(labelWithString: result.shortcutHint ?? "")
        hintLabel.translatesAutoresizingMaskIntoConstraints = false
        hintLabel.font = .monospacedSystemFont(ofSize: 10, weight: .regular)
        hintLabel.textColor = .tertiaryLabelColor
        hintLabel.alignment = .right
        hintLabel.tag = 4
        hintLabel.isHidden = result.shortcutHint == nil
        hintLabel.setContentHuggingPriority(.required, for: .horizontal)
        hintLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        container.addSubview(groupLabel)
        container.addSubview(nameLabel)
        container.addSubview(pathLabel)
        container.addSubview(hintLabel)

        NSLayoutConstraint.activate([
            groupLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 8),
            groupLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            groupLabel.widthAnchor.constraint(equalToConstant: 52),

            nameLabel.leadingAnchor.constraint(equalTo: groupLabel.trailingAnchor, constant: 8),
            nameLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 6),
            nameLabel.trailingAnchor.constraint(equalTo: hintLabel.leadingAnchor, constant: -4),

            pathLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            pathLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 2),
            pathLabel.trailingAnchor.constraint(equalTo: hintLabel.leadingAnchor, constant: -4),

            hintLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -8),
            hintLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
        ])

        return container
    }
}
