import AppKit

final class StatusBarView: NSView {
    private let primaryLabel = NSTextField(labelWithString: "")
    private let secondaryLabel = NSTextField(labelWithString: "")
    private let taskCenterButton: NSButton = {
        let button = NSButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.bezelStyle = .inline
        button.isBordered = false
        button.imagePosition = .imageOnly
        button.image = NSImage(systemSymbolName: "square.stack.3d.up", accessibilityDescription: "Task Center")
        button.imageScaling = .scaleProportionallyDown
        button.contentTintColor = .secondaryLabelColor
        button.toolTip = "Task Center"
        return button
    }()
    private var currentTheme: FilerTheme = .system
    private var backgroundOpacity: CGFloat = 1.0
    private var previousMarkedCount: Int = 0
    private var previousSecondaryText: String = ""
    private var starEffectsEnabled = true
    private var animationEffectSettings = AnimationEffectSettings.allEnabled

    var onTaskCenterButtonClicked: (() -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    func update(primaryText: String, secondaryText: String) {
        primaryLabel.stringValue = primaryText
        updateSecondaryText(secondaryText, accentuate: false)
    }

    func update(primaryText: String, itemCount: Int, markedCount: Int) {
        primaryLabel.stringValue = primaryText
        let oldMarkedCount = previousMarkedCount
        previousMarkedCount = markedCount

        let secondaryText: String
        if markedCount > 0 {
            secondaryText = "\(itemCount) items | \(markedCount) marked"
        } else {
            secondaryText = "\(itemCount) items"
        }

        updateSecondaryText(secondaryText, accentuate: markedCount > oldMarkedCount)
    }

    func updateTaskCenterIndicator(activeCount: Int, hasFailedEntries: Bool) {
        if activeCount > 0 {
            taskCenterButton.image = NSImage(
                systemSymbolName: "arrow.triangle.2.circlepath",
                accessibilityDescription: "Task Center - \(activeCount) active"
            )
            taskCenterButton.contentTintColor = .controlAccentColor
        } else if hasFailedEntries {
            taskCenterButton.image = NSImage(
                systemSymbolName: "exclamationmark.triangle.fill",
                accessibilityDescription: "Task Center - has failures"
            )
            taskCenterButton.contentTintColor = .systemYellow
        } else {
            taskCenterButton.image = NSImage(
                systemSymbolName: "square.stack.3d.up",
                accessibilityDescription: "Task Center"
            )
            taskCenterButton.contentTintColor = .secondaryLabelColor
        }
    }

    func setStarEffectsEnabled(_ enabled: Bool) {
        starEffectsEnabled = enabled
    }

    func setAnimationEffectSettings(_ settings: AnimationEffectSettings) {
        animationEffectSettings = settings
    }

    func applyTheme(_ theme: FilerTheme, backgroundOpacity: CGFloat = 1.0) {
        currentTheme = theme
        self.backgroundOpacity = backgroundOpacity
        let palette = theme.palette
        layer?.backgroundColor = palette.statusBarBackgroundColor.applyingBackgroundOpacity(backgroundOpacity).cgColor
        primaryLabel.textColor = palette.statusBarTextColor
        secondaryLabel.textColor = palette.statusBarTextColor
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
        let palette = currentTheme.palette
        layer?.backgroundColor = palette.statusBarBackgroundColor.applyingBackgroundOpacity(backgroundOpacity).cgColor
    }

    var taskCenterButtonView: NSView {
        taskCenterButton
    }

    private func setupView() {
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        layer?.backgroundColor = currentTheme.palette.statusBarBackgroundColor.cgColor

        primaryLabel.translatesAutoresizingMaskIntoConstraints = false
        primaryLabel.lineBreakMode = .byTruncatingMiddle
        primaryLabel.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        primaryLabel.textColor = currentTheme.palette.statusBarTextColor

        secondaryLabel.translatesAutoresizingMaskIntoConstraints = false
        secondaryLabel.alignment = .right
        secondaryLabel.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        secondaryLabel.textColor = currentTheme.palette.statusBarTextColor

        taskCenterButton.target = self
        taskCenterButton.action = #selector(taskCenterButtonAction)

        addSubview(primaryLabel)
        addSubview(taskCenterButton)
        addSubview(secondaryLabel)

        NSLayoutConstraint.activate([
            primaryLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            primaryLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            primaryLabel.trailingAnchor.constraint(lessThanOrEqualTo: taskCenterButton.leadingAnchor, constant: -8),

            taskCenterButton.trailingAnchor.constraint(equalTo: secondaryLabel.leadingAnchor, constant: -6),
            taskCenterButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            taskCenterButton.widthAnchor.constraint(equalToConstant: 20),
            taskCenterButton.heightAnchor.constraint(equalToConstant: 20),

            secondaryLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            secondaryLabel.centerYAnchor.constraint(equalTo: centerYAnchor),

            heightAnchor.constraint(equalToConstant: 28)
        ])
    }

    @objc private func taskCenterButtonAction() {
        onTaskCenterButtonClicked?()
    }

    private func updateSecondaryText(_ text: String, accentuate: Bool) {
        let hasChanged = previousSecondaryText != text
        previousSecondaryText = text
        secondaryLabel.stringValue = text

        guard hasChanged,
              starEffectsEnabled,
              animationEffectSettings.statusBarCountAnimation else {
            return
        }

        secondaryLabel.wantsLayer = true
        let transition = CATransition()
        transition.type = .push
        transition.subtype = .fromTop
        transition.duration = 0.15
        secondaryLabel.layer?.add(transition, forKey: "statusSecondaryChange")

        guard accentuate else {
            return
        }

        secondaryLabel.textColor = currentTheme.palette.starAccentColor
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(300))
            guard let self else {
                return
            }
            self.secondaryLabel.textColor = self.currentTheme.palette.statusBarTextColor
        }
    }
}
