import AppKit

final class AdvancedSettingsViewController: NSViewController {
    private let configManager: ConfigManager

    private let titleLabel = NSTextField(labelWithString: "Advanced")
    private let descriptionLabel = NSTextField(
        wrappingLabelWithString: "Utilities for inspecting internal app configuration paths."
    )
    private let favoritesPathTitleLabel = NSTextField(labelWithString: "Favorites File")
    private let favoritesPathLabel = NSTextField(labelWithString: "")
    private let copyFavoritesPathButton = NSButton(title: "Copy Favorites File Path", target: nil, action: nil)
    private let copyStatusLabel = NSTextField(labelWithString: "")

    init(configManager: ConfigManager = ConfigManager()) {
        self.configManager = configManager
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
        configureUI()
        configureLayout()
        updateFavoritesPath()
    }

    private func configureUI() {
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .systemFont(ofSize: 14, weight: .semibold)

        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        descriptionLabel.font = .systemFont(ofSize: 12)
        descriptionLabel.textColor = .secondaryLabelColor
        descriptionLabel.maximumNumberOfLines = 2
        descriptionLabel.lineBreakMode = .byWordWrapping

        favoritesPathTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        favoritesPathTitleLabel.font = .systemFont(ofSize: 13, weight: .semibold)

        favoritesPathLabel.translatesAutoresizingMaskIntoConstraints = false
        favoritesPathLabel.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        favoritesPathLabel.lineBreakMode = .byTruncatingMiddle
        favoritesPathLabel.isSelectable = true

        copyFavoritesPathButton.translatesAutoresizingMaskIntoConstraints = false
        copyFavoritesPathButton.bezelStyle = .rounded
        copyFavoritesPathButton.target = self
        copyFavoritesPathButton.action = #selector(copyFavoritesPath(_:))

        copyStatusLabel.translatesAutoresizingMaskIntoConstraints = false
        copyStatusLabel.font = .systemFont(ofSize: 12)
        copyStatusLabel.textColor = .secondaryLabelColor
    }

    private func configureLayout() {
        view.addSubview(titleLabel)
        view.addSubview(descriptionLabel)
        view.addSubview(favoritesPathTitleLabel)
        view.addSubview(favoritesPathLabel)
        view.addSubview(copyFavoritesPathButton)
        view.addSubview(copyStatusLabel)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),

            descriptionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            descriptionLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            descriptionLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            favoritesPathTitleLabel.topAnchor.constraint(equalTo: descriptionLabel.bottomAnchor, constant: 20),
            favoritesPathTitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),

            favoritesPathLabel.topAnchor.constraint(equalTo: favoritesPathTitleLabel.bottomAnchor, constant: 8),
            favoritesPathLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            favoritesPathLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            copyFavoritesPathButton.topAnchor.constraint(equalTo: favoritesPathLabel.bottomAnchor, constant: 12),
            copyFavoritesPathButton.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),

            copyStatusLabel.centerYAnchor.constraint(equalTo: copyFavoritesPathButton.centerYAnchor),
            copyStatusLabel.leadingAnchor.constraint(equalTo: copyFavoritesPathButton.trailingAnchor, constant: 10),
            copyStatusLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -20),
        ])
    }

    private func updateFavoritesPath() {
        favoritesPathLabel.stringValue = configManager.bookmarksConfigURL.path
    }

    @objc
    private func copyFavoritesPath(_ sender: NSButton) {
        let path = configManager.bookmarksConfigURL.path
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(path, forType: .string)
        copyStatusLabel.stringValue = "Copied"
    }
}
