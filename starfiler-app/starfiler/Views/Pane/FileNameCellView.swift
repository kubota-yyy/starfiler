import AppKit

final class FileNameCellView: NSTableCellView {
    private let iconView = NSImageView()
    private let markStarView = NSImageView()
    private let nameLabel = NSTextField(labelWithString: "")
    private var iconWidthConstraint: NSLayoutConstraint?
    private var iconHeightConstraint: NSLayoutConstraint?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configureView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureView()
    }

    func setName(_ text: String, textColor: NSColor) {
        nameLabel.stringValue = text
        nameLabel.textColor = textColor
    }

    func setIcon(_ image: NSImage?, size: CGFloat) {
        iconView.image = image

        let clamped = min(max(size, 12), 40)
        iconWidthConstraint?.constant = clamped
        iconHeightConstraint?.constant = clamped
    }

    func setMarkStar(visible: Bool, color: NSColor) {
        markStarView.isHidden = !visible
        markStarView.contentTintColor = color
    }

    private func configureView() {
        identifier = NSUserInterfaceItemIdentifier("nameCell")

        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.imageScaling = .scaleProportionallyUpOrDown

        markStarView.translatesAutoresizingMaskIntoConstraints = false
        markStarView.image = NSImage(systemSymbolName: "star.fill", accessibilityDescription: "Marked")
        markStarView.imageScaling = .scaleProportionallyDown
        markStarView.isHidden = true

        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.lineBreakMode = .byTruncatingMiddle

        textField = nameLabel
        imageView = iconView

        addSubview(iconView)
        addSubview(markStarView)
        addSubview(nameLabel)

        let iconWidthConstraint = iconView.widthAnchor.constraint(equalToConstant: 16)
        let iconHeightConstraint = iconView.heightAnchor.constraint(equalToConstant: 16)
        self.iconWidthConstraint = iconWidthConstraint
        self.iconHeightConstraint = iconHeightConstraint

        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconWidthConstraint,
            iconHeightConstraint,

            markStarView.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 3),
            markStarView.centerYAnchor.constraint(equalTo: centerYAnchor),
            markStarView.widthAnchor.constraint(equalToConstant: 12),
            markStarView.heightAnchor.constraint(equalToConstant: 12),

            nameLabel.leadingAnchor.constraint(equalTo: markStarView.trailingAnchor, constant: 3),
            nameLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            nameLabel.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }
}
