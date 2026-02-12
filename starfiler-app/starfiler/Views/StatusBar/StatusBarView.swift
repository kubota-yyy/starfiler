import AppKit

final class StatusBarView: NSView {
    private let pathLabel = NSTextField(labelWithString: "")
    private let countLabel = NSTextField(labelWithString: "")
    private var currentTheme: FilerTheme = .system
    private var backgroundOpacity: CGFloat = 1.0
    private var previousMarkedCount: Int = 0
    private var starEffectsEnabled = true
    private var animationEffectSettings = AnimationEffectSettings.allEnabled

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    func update(path: String, itemCount: Int, markedCount: Int) {
        if path.hasPrefix("/") {
            pathLabel.stringValue = ""
        } else {
            pathLabel.stringValue = path
        }

        let oldMarkedCount = previousMarkedCount
        previousMarkedCount = markedCount

        if markedCount > 0 {
            countLabel.stringValue = "\(itemCount) items | \(markedCount) marked"
        } else {
            countLabel.stringValue = "\(itemCount) items"
        }

        if starEffectsEnabled, animationEffectSettings.statusBarCountAnimation {
            countLabel.wantsLayer = true
            let transition = CATransition()
            transition.type = .push
            transition.subtype = .fromTop
            transition.duration = 0.15
            countLabel.layer?.add(transition, forKey: "countChange")

            if markedCount > oldMarkedCount {
                let palette = currentTheme.palette
                let originalColor = countLabel.textColor
                countLabel.textColor = palette.starAccentColor
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                    self?.countLabel.textColor = originalColor
                }
            }
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
        pathLabel.textColor = palette.statusBarTextColor
        countLabel.textColor = palette.statusBarTextColor
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
        let palette = currentTheme.palette
        layer?.backgroundColor = palette.statusBarBackgroundColor.applyingBackgroundOpacity(backgroundOpacity).cgColor
    }

    private func setupView() {
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        layer?.backgroundColor = currentTheme.palette.statusBarBackgroundColor.cgColor

        pathLabel.translatesAutoresizingMaskIntoConstraints = false
        pathLabel.lineBreakMode = .byTruncatingMiddle
        pathLabel.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        pathLabel.textColor = currentTheme.palette.statusBarTextColor

        countLabel.translatesAutoresizingMaskIntoConstraints = false
        countLabel.alignment = .right
        countLabel.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        countLabel.textColor = currentTheme.palette.statusBarTextColor

        addSubview(pathLabel)
        addSubview(countLabel)

        NSLayoutConstraint.activate([
            pathLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            pathLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            pathLabel.trailingAnchor.constraint(lessThanOrEqualTo: countLabel.leadingAnchor, constant: -12),

            countLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            countLabel.centerYAnchor.constraint(equalTo: centerYAnchor),

            heightAnchor.constraint(equalToConstant: 28)
        ])
    }
}
