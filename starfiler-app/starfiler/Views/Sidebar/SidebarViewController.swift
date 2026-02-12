import AppKit

final class SidebarViewController: NSViewController, NSOutlineViewDataSource, NSOutlineViewDelegate {
    private let viewModel: SidebarViewModel
    private let windowControlsContainer = NSView()
    private let windowControlsStackView = NSStackView()
    private let scrollView = NSScrollView()
    private let outlineView = NSOutlineView()
    private let recentSeparatorView = NSView()
    private let recentHeaderLabel = NSTextField(labelWithString: "Recent")
    private let recentScrollView = NSScrollView()
    private let recentOutlineView = NSOutlineView()
    private var scrollViewBottomToRecent: NSLayoutConstraint!
    private var scrollViewBottomToView: NSLayoutConstraint!
    private var windowControlsHeightConstraint: NSLayoutConstraint!
    private var recentScrollViewHeightConstraint: NSLayoutConstraint!

    private var regularSections: [SidebarViewModel.SidebarSection] = []
    private var recentSection: SidebarViewModel.SidebarSection?

    private let sectionHeaderHeight: CGFloat = 22
    private let entryRowHeight: CGFloat = 24
    private let windowControlsHeight: CGFloat = 30

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
        configureOutlineViews()
        configureLayout()
        bindViewModel()
    }

    private var currentTheme: FilerTheme = .system

    func reloadData() {
        viewModel.reloadSections()
    }

    func embedWindowControlButtons(_ buttons: [NSButton]) {
        guard !buttons.isEmpty else {
            return
        }

        loadViewIfNeeded()
        windowControlsHeightConstraint.constant = windowControlsHeight

        for existing in windowControlsStackView.arrangedSubviews {
            windowControlsStackView.removeArrangedSubview(existing)
            existing.removeFromSuperview()
        }

        for button in buttons {
            button.removeFromSuperview()
            button.translatesAutoresizingMaskIntoConstraints = false
            button.setContentHuggingPriority(.required, for: .horizontal)
            button.setContentCompressionResistancePriority(.required, for: .horizontal)
            windowControlsStackView.addArrangedSubview(button)
        }
    }

    func applyTheme(_ theme: FilerTheme, backgroundOpacity: CGFloat = 1.0) {
        currentTheme = theme
        let palette = theme.palette
        let backgroundColor = palette.sidebarBackgroundColor.applyingBackgroundOpacity(backgroundOpacity)

        view.wantsLayer = true
        view.layer?.backgroundColor = backgroundColor.cgColor
        windowControlsContainer.wantsLayer = true
        windowControlsContainer.layer?.backgroundColor = backgroundColor.cgColor
        recentSeparatorView.wantsLayer = true
        recentSeparatorView.layer?.backgroundColor = NSColor.separatorColor.withAlphaComponent(0.25).cgColor
        recentHeaderLabel.textColor = palette.sidebarSectionHeaderColor

        outlineView.backgroundColor = backgroundColor
        scrollView.backgroundColor = backgroundColor
        recentOutlineView.backgroundColor = backgroundColor
        recentScrollView.backgroundColor = backgroundColor

        outlineView.reloadData()
        recentOutlineView.reloadData()
    }

    private func configureOutlineViews() {
        configureRegularOutlineView()
        configureRecentOutlineView()
    }

    private func configureRegularOutlineView() {
        outlineView.translatesAutoresizingMaskIntoConstraints = false
        outlineView.delegate = self
        outlineView.dataSource = self
        outlineView.headerView = nil
        outlineView.rowHeight = entryRowHeight
        outlineView.indentationPerLevel = 14
        outlineView.selectionHighlightStyle = .sourceList
        outlineView.allowsTypeSelect = false
        outlineView.usesAlternatingRowBackgroundColors = false
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
        scrollView.drawsBackground = true
    }

    private func configureRecentOutlineView() {
        recentSeparatorView.translatesAutoresizingMaskIntoConstraints = false
        recentSeparatorView.wantsLayer = true

        recentHeaderLabel.translatesAutoresizingMaskIntoConstraints = false
        recentHeaderLabel.font = .systemFont(ofSize: 11, weight: .bold)

        recentOutlineView.translatesAutoresizingMaskIntoConstraints = false
        recentOutlineView.delegate = self
        recentOutlineView.dataSource = self
        recentOutlineView.headerView = nil
        recentOutlineView.rowHeight = entryRowHeight
        recentOutlineView.indentationPerLevel = 0
        recentOutlineView.selectionHighlightStyle = .sourceList
        recentOutlineView.allowsTypeSelect = false
        recentOutlineView.usesAlternatingRowBackgroundColors = false
        recentOutlineView.target = self
        recentOutlineView.action = #selector(handleSingleClick(_:))

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("recentSidebar"))
        column.title = ""
        recentOutlineView.addTableColumn(column)
        recentOutlineView.outlineTableColumn = column

        recentScrollView.translatesAutoresizingMaskIntoConstraints = false
        recentScrollView.documentView = recentOutlineView
        recentScrollView.hasVerticalScroller = true
        recentScrollView.hasHorizontalScroller = false
        recentScrollView.autohidesScrollers = true
        recentScrollView.drawsBackground = true
    }

    private var recentConstraints: [NSLayoutConstraint] = []

    private func configureLayout() {
        windowControlsContainer.translatesAutoresizingMaskIntoConstraints = false
        windowControlsStackView.translatesAutoresizingMaskIntoConstraints = false
        windowControlsStackView.orientation = .horizontal
        windowControlsStackView.alignment = .centerY
        windowControlsStackView.spacing = 8

        windowControlsContainer.addSubview(windowControlsStackView)
        view.addSubview(scrollView)
        view.addSubview(windowControlsContainer)
        view.addSubview(recentSeparatorView)
        view.addSubview(recentHeaderLabel)
        view.addSubview(recentScrollView)

        windowControlsHeightConstraint = windowControlsContainer.heightAnchor.constraint(equalToConstant: 0)
        scrollViewBottomToRecent = scrollView.bottomAnchor.constraint(equalTo: recentSeparatorView.topAnchor)
        scrollViewBottomToView = scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        recentScrollViewHeightConstraint = recentScrollView.heightAnchor.constraint(equalToConstant: 0)
        recentScrollViewHeightConstraint.priority = .defaultHigh

        recentConstraints = [
            recentSeparatorView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            recentSeparatorView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            recentSeparatorView.heightAnchor.constraint(equalToConstant: 1),

            recentHeaderLabel.topAnchor.constraint(equalTo: recentSeparatorView.bottomAnchor, constant: 4),
            recentHeaderLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 2),
            recentHeaderLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -4),

            recentScrollView.topAnchor.constraint(equalTo: recentHeaderLabel.bottomAnchor, constant: 2),
            recentScrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            recentScrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            recentScrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            recentScrollViewHeightConstraint,
        ]

        NSLayoutConstraint.activate([
            windowControlsContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            windowControlsContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            windowControlsContainer.topAnchor.constraint(equalTo: view.topAnchor),
            windowControlsHeightConstraint,

            windowControlsStackView.leadingAnchor.constraint(equalTo: windowControlsContainer.leadingAnchor, constant: 12),
            windowControlsStackView.centerYAnchor.constraint(equalTo: windowControlsContainer.centerYAnchor),

            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: windowControlsContainer.bottomAnchor),
        ])

        setRecentSectionVisible(false)
    }

    private func setRecentSectionVisible(_ visible: Bool) {
        recentSeparatorView.isHidden = !visible
        recentHeaderLabel.isHidden = !visible
        recentScrollView.isHidden = !visible

        if visible {
            scrollViewBottomToView.isActive = false
            NSLayoutConstraint.activate(recentConstraints)
            scrollViewBottomToRecent.isActive = true
        } else {
            scrollViewBottomToRecent.isActive = false
            NSLayoutConstraint.deactivate(recentConstraints)
            scrollViewBottomToView.isActive = true
        }
    }

    private func bindViewModel() {
        viewModel.onSectionsChanged = { [weak self] _ in
            self?.syncSections()
        }
        syncSections()
    }

    private func syncSections() {
        regularSections = viewModel.sections.filter { !isRecentSection($0) }
        recentSection = viewModel.sections.first(where: { isRecentSection($0) })

        outlineView.reloadData()
        expandAllSections()
        recentOutlineView.reloadData()
        updateRecentSectionLayout()
    }

    private func isRecentSection(_ section: SidebarViewModel.SidebarSection) -> Bool {
        if case .recent = section.kind {
            return true
        }
        return false
    }

    private func expandAllSections() {
        for section in regularSections {
            outlineView.expandItem(section.title)
        }
    }

    private func updateRecentSectionLayout() {
        let recentCount = recentSection?.items.count ?? 0
        let hasRecent = recentCount > 0
        setRecentSectionVisible(hasRecent)

        guard hasRecent else {
            return
        }

        let scrollHeight = CGFloat(recentCount) * entryRowHeight
        recentScrollViewHeightConstraint.constant = scrollHeight
        recentScrollView.hasVerticalScroller = false
    }

    // MARK: - Actions

    @objc
    private func handleSingleClick(_ sender: Any?) {
        guard let sourceOutlineView = sender as? NSOutlineView else {
            return
        }

        let clickedRow = sourceOutlineView.clickedRow
        guard clickedRow >= 0 else {
            return
        }

        let item = sourceOutlineView.item(atRow: clickedRow)
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
        if outlineView === recentOutlineView {
            if item == nil {
                return recentSection?.items.count ?? 0
            }
            return 0
        }

        if item == nil {
            return regularSections.count
        }

        if let sectionTitle = item as? String,
           let section = regularSections.first(where: { $0.title == sectionTitle }) {
            return section.items.count
        }

        return 0
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if outlineView === recentOutlineView {
            return recentSection?.items[index] ?? ""
        }

        if item == nil {
            return regularSections[index].title
        }

        if let sectionTitle = item as? String,
           let section = regularSections.first(where: { $0.title == sectionTitle }) {
            return section.items[index]
        }

        return ""
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        if outlineView === recentOutlineView {
            return false
        }
        return item is String
    }

    // MARK: - NSOutlineViewDelegate

    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        if let sectionTitle = item as? String {
            return makeSectionHeaderView(title: sectionTitle, in: outlineView)
        }

        if let entry = item as? SidebarViewModel.SidebarEntry {
            return makeEntryView(entry: entry, in: outlineView)
        }

        return nil
    }

    func outlineView(_ outlineView: NSOutlineView, isGroupItem item: Any) -> Bool {
        if outlineView === recentOutlineView {
            return false
        }
        return item is String
    }

    func outlineView(_ outlineView: NSOutlineView, shouldSelectItem item: Any) -> Bool {
        item is SidebarViewModel.SidebarEntry
    }

    func outlineView(_ outlineView: NSOutlineView, heightOfRowByItem item: Any) -> CGFloat {
        if outlineView === recentOutlineView {
            return entryRowHeight
        }

        if item is String {
            return sectionHeaderHeight
        }
        return entryRowHeight
    }

    // MARK: - Cell Views

    private func makeSectionHeaderView(title: String, in outlineView: NSOutlineView) -> NSView {
        let cellIdentifier = NSUserInterfaceItemIdentifier("sectionHeader")
        let palette = currentTheme.palette
        let isFavorites = title == "Favorites"

        if let existing = outlineView.makeView(withIdentifier: cellIdentifier, owner: self) as? NSTableCellView {
            existing.textField?.stringValue = title
            existing.textField?.textColor = palette.sidebarSectionHeaderColor
            if let starView = existing.viewWithTag(200) as? NSImageView {
                starView.isHidden = !isFavorites
                starView.contentTintColor = palette.starAccentColor
            }
            return existing
        }

        let cell = NSTableCellView()
        cell.identifier = cellIdentifier

        let starImageView = NSImageView()
        starImageView.translatesAutoresizingMaskIntoConstraints = false
        starImageView.image = NSImage(systemSymbolName: "star.fill", accessibilityDescription: nil)
        starImageView.contentTintColor = palette.starAccentColor
        starImageView.tag = 200
        starImageView.isHidden = !isFavorites

        let textField = NSTextField(labelWithString: title)
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.font = .systemFont(ofSize: 11, weight: .bold)
        textField.textColor = palette.sidebarSectionHeaderColor

        cell.textField = textField
        cell.addSubview(starImageView)
        cell.addSubview(textField)

        NSLayoutConstraint.activate([
            starImageView.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 2),
            starImageView.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            starImageView.widthAnchor.constraint(equalToConstant: 12),
            starImageView.heightAnchor.constraint(equalToConstant: 12),

            textField.leadingAnchor.constraint(equalTo: starImageView.trailingAnchor, constant: 4),
            textField.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -4),
            textField.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
        ])

        return cell
    }

    private func makeEntryView(entry: SidebarViewModel.SidebarEntry, in outlineView: NSOutlineView) -> NSView {
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

        let palette = currentTheme.palette
        cell.textField?.stringValue = entry.displayName
        cell.textField?.textColor = palette.sidebarEntryTextColor
        cell.imageView?.image = NSImage(systemSymbolName: entry.iconName, accessibilityDescription: nil)
            ?? NSImage(systemSymbolName: "folder", accessibilityDescription: nil)
        cell.imageView?.contentTintColor = palette.sidebarIconTintColor

        shortcutLabel.stringValue = entry.shortcutHint ?? ""
        shortcutLabel.isHidden = entry.shortcutHint == nil
        shortcutLabel.textColor = palette.sidebarShortcutHintColor

        return cell
    }
}
