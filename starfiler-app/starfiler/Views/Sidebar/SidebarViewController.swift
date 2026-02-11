import AppKit

final class SidebarViewController: NSViewController, NSOutlineViewDataSource, NSOutlineViewDelegate {
    private let viewModel: SidebarViewModel
    private let scrollView = NSScrollView()
    private let outlineView = NSOutlineView()

    var onNavigateRequested: ((URL) -> Void)?

    init(viewModel: SidebarViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = NSView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureOutlineView()
        configureLayout()
        bindViewModel()
    }

    func reloadData() {
        viewModel.reloadSections()
        outlineView.reloadData()
        expandAllSections()
    }

    private func configureOutlineView() {
        outlineView.translatesAutoresizingMaskIntoConstraints = false
        outlineView.delegate = self
        outlineView.dataSource = self
        outlineView.headerView = nil
        outlineView.rowHeight = 24
        outlineView.indentationPerLevel = 14
        outlineView.selectionHighlightStyle = .sourceList
        outlineView.allowsTypeSelect = false
        outlineView.target = self
        outlineView.action = #selector(handleSingleClick(_:))

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("sidebar"))
        column.title = ""
        outlineView.addTableColumn(column)
        outlineView.outlineTableColumn = column

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = outlineView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
    }

    private func configureLayout() {
        view.addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    private func bindViewModel() {
        viewModel.onSectionsChanged = { [weak self] _ in
            self?.outlineView.reloadData()
            self?.expandAllSections()
        }
        expandAllSections()
    }

    private func expandAllSections() {
        for section in viewModel.sections {
            outlineView.expandItem(section.title)
        }
    }

    // MARK: - Actions

    @objc
    private func handleSingleClick(_ sender: Any?) {
        let clickedRow = outlineView.clickedRow
        guard clickedRow >= 0 else {
            return
        }

        let item = outlineView.item(atRow: clickedRow)
        guard let entry = item as? SidebarViewModel.SidebarEntry else {
            return
        }

        guard let url = viewModel.urlForEntry(entry) else {
            return
        }

        onNavigateRequested?(url)
    }

    // MARK: - NSOutlineViewDataSource

    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if item == nil {
            return viewModel.sections.count
        }

        if let sectionTitle = item as? String,
           let section = viewModel.sections.first(where: { $0.title == sectionTitle }) {
            return section.items.count
        }

        return 0
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if item == nil {
            return viewModel.sections[index].title
        }

        if let sectionTitle = item as? String,
           let section = viewModel.sections.first(where: { $0.title == sectionTitle }) {
            return section.items[index]
        }

        return ""
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        item is String
    }

    // MARK: - NSOutlineViewDelegate

    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        if let sectionTitle = item as? String {
            return makeSectionHeaderView(title: sectionTitle)
        }

        if let entry = item as? SidebarViewModel.SidebarEntry {
            return makeEntryView(entry: entry)
        }

        return nil
    }

    func outlineView(_ outlineView: NSOutlineView, isGroupItem item: Any) -> Bool {
        item is String
    }

    func outlineView(_ outlineView: NSOutlineView, shouldSelectItem item: Any) -> Bool {
        item is SidebarViewModel.SidebarEntry
    }

    func outlineView(_ outlineView: NSOutlineView, heightOfRowByItem item: Any) -> CGFloat {
        if item is String {
            return 22
        }
        return 24
    }

    // MARK: - Cell Views

    private func makeSectionHeaderView(title: String) -> NSView {
        let cellIdentifier = NSUserInterfaceItemIdentifier("sectionHeader")
        if let existing = outlineView.makeView(withIdentifier: cellIdentifier, owner: self) as? NSTableCellView {
            existing.textField?.stringValue = title
            return existing
        }

        let cell = NSTableCellView()
        cell.identifier = cellIdentifier

        let textField = NSTextField(labelWithString: title)
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.font = .systemFont(ofSize: 11, weight: .bold)
        textField.textColor = .secondaryLabelColor

        cell.textField = textField
        cell.addSubview(textField)

        NSLayoutConstraint.activate([
            textField.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 2),
            textField.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -4),
            textField.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
        ])

        return cell
    }

    private func makeEntryView(entry: SidebarViewModel.SidebarEntry) -> NSView {
        let cellIdentifier = NSUserInterfaceItemIdentifier("entryCell")
        let cell: NSTableCellView
        let shortcutLabel: NSTextField

        if let existing = outlineView.makeView(withIdentifier: cellIdentifier, owner: self) as? NSTableCellView,
           let existingShortcut = existing.viewWithTag(100) as? NSTextField {
            cell = existing
            shortcutLabel = existingShortcut
        } else {
            cell = NSTableCellView()
            cell.identifier = cellIdentifier

            let imageView = NSImageView()
            imageView.translatesAutoresizingMaskIntoConstraints = false
            imageView.imageScaling = .scaleProportionallyDown

            let textField = NSTextField(labelWithString: "")
            textField.translatesAutoresizingMaskIntoConstraints = false
            textField.lineBreakMode = .byTruncatingTail
            textField.font = .systemFont(ofSize: 13)

            shortcutLabel = NSTextField(labelWithString: "")
            shortcutLabel.translatesAutoresizingMaskIntoConstraints = false
            shortcutLabel.font = .monospacedSystemFont(ofSize: 10, weight: .regular)
            shortcutLabel.textColor = .tertiaryLabelColor
            shortcutLabel.alignment = .right
            shortcutLabel.tag = 100
            shortcutLabel.setContentHuggingPriority(.required, for: .horizontal)
            shortcutLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

            cell.imageView = imageView
            cell.textField = textField
            cell.addSubview(imageView)
            cell.addSubview(textField)
            cell.addSubview(shortcutLabel)

            NSLayoutConstraint.activate([
                imageView.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 2),
                imageView.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
                imageView.widthAnchor.constraint(equalToConstant: 16),
                imageView.heightAnchor.constraint(equalToConstant: 16),

                textField.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 6),
                textField.centerYAnchor.constraint(equalTo: cell.centerYAnchor),

                shortcutLabel.leadingAnchor.constraint(greaterThanOrEqualTo: textField.trailingAnchor, constant: 4),
                shortcutLabel.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -4),
                shortcutLabel.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            ])
        }

        cell.textField?.stringValue = entry.displayName
        cell.imageView?.image = NSImage(systemSymbolName: entry.iconName, accessibilityDescription: nil)
            ?? NSImage(systemSymbolName: "folder", accessibilityDescription: nil)
        cell.imageView?.contentTintColor = .controlAccentColor

        shortcutLabel.stringValue = entry.shortcutHint ?? ""
        shortcutLabel.isHidden = entry.shortcutHint == nil

        return cell
    }
}
