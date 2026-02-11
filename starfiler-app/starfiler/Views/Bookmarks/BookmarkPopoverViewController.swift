import AppKit

final class BookmarkPopoverViewController: NSViewController {
    private let groupLabel = NSTextField(labelWithString: "Group")
    private let entryLabel = NSTextField(labelWithString: "Entry")
    private let groupPopup = NSPopUpButton()
    private let entryPopup = NSPopUpButton()
    private let openButton = NSButton(title: "Open", target: nil, action: nil)

    private(set) var groups: [BookmarkGroup]

    var onOpenEntry: ((BookmarkEntry) -> Void)?

    init(groups: [BookmarkGroup]) {
        self.groups = groups
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
        configureView()
        configureLayout()
        reloadGroups()
    }

    func updateGroups(_ groups: [BookmarkGroup]) {
        self.groups = groups
        reloadGroups()
    }

    @objc
    private func groupChanged() {
        reloadEntries()
    }

    @objc
    private func openSelectedEntry() {
        guard
            let groupIndex = selectedGroupIndex,
            let entryIndex = selectedEntryIndex,
            groups.indices.contains(groupIndex),
            groups[groupIndex].entries.indices.contains(entryIndex)
        else {
            return
        }

        onOpenEntry?(groups[groupIndex].entries[entryIndex])
    }

    private var selectedGroupIndex: Int? {
        let index = groupPopup.indexOfSelectedItem
        return index >= 0 ? index : nil
    }

    private var selectedEntryIndex: Int? {
        let index = entryPopup.indexOfSelectedItem
        return index >= 0 ? index : nil
    }

    private func configureView() {
        view.translatesAutoresizingMaskIntoConstraints = false

        [groupLabel, entryLabel, groupPopup, entryPopup, openButton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }

        groupLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        entryLabel.font = .systemFont(ofSize: 12, weight: .semibold)

        groupPopup.target = self
        groupPopup.action = #selector(groupChanged)

        entryPopup.target = self
        entryPopup.action = #selector(openSelectedEntry)

        openButton.target = self
        openButton.action = #selector(openSelectedEntry)
        openButton.bezelStyle = .rounded
    }

    private func configureLayout() {
        NSLayoutConstraint.activate([
            view.widthAnchor.constraint(equalToConstant: 320),
            view.heightAnchor.constraint(equalToConstant: 140),

            groupLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            groupLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            groupLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 12),

            groupPopup.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            groupPopup.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            groupPopup.topAnchor.constraint(equalTo: groupLabel.bottomAnchor, constant: 6),

            entryLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            entryLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            entryLabel.topAnchor.constraint(equalTo: groupPopup.bottomAnchor, constant: 10),

            entryPopup.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            entryPopup.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            entryPopup.topAnchor.constraint(equalTo: entryLabel.bottomAnchor, constant: 6),

            openButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            openButton.topAnchor.constraint(equalTo: entryPopup.bottomAnchor, constant: 10)
        ])
    }

    private func reloadGroups() {
        groupPopup.removeAllItems()
        groupPopup.addItems(withTitles: groups.map(\.name))

        if groupPopup.numberOfItems > 0 {
            groupPopup.selectItem(at: 0)
        }

        reloadEntries()
    }

    private func reloadEntries() {
        entryPopup.removeAllItems()

        guard let groupIndex = selectedGroupIndex, groups.indices.contains(groupIndex) else {
            entryPopup.isEnabled = false
            openButton.isEnabled = false
            return
        }

        let entries = groups[groupIndex].entries
        entryPopup.addItems(withTitles: entries.map(\.displayName))
        entryPopup.isEnabled = !entries.isEmpty
        openButton.isEnabled = !entries.isEmpty

        if !entries.isEmpty {
            entryPopup.selectItem(at: 0)
        }
    }
}
