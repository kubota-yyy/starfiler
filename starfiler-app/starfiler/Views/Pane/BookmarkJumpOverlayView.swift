import AppKit

final class BookmarkJumpOverlayView: NSView {
    private let titleLabel = NSTextField(labelWithString: "")
    private let candidatesLabel = NSTextField(wrappingLabelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configureView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureView()
    }

    func update(with hint: BookmarkJumpHint) {
        titleLabel.stringValue = hint.title
        candidatesLabel.stringValue = hint.candidates
            .map { "[\($0.key)] \($0.label)" }
            .joined(separator: "\n")
    }

    func applyPalette(_ palette: FilerThemePalette, backgroundOpacity: CGFloat) {
        _ = backgroundOpacity
        layer?.backgroundColor = palette.windowBackgroundColor.cgColor
        layer?.borderColor = palette.starAccentColor.withAlphaComponent(0.5).cgColor
        titleLabel.textColor = palette.primaryTextColor
        candidatesLabel.textColor = palette.secondaryTextColor
    }

    private func configureView() {
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        layer?.cornerRadius = 8
        layer?.borderWidth = 1
        layer?.masksToBounds = true

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .systemFont(ofSize: 12, weight: .semibold)

        candidatesLabel.translatesAutoresizingMaskIntoConstraints = false
        candidatesLabel.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        candidatesLabel.maximumNumberOfLines = 12
        candidatesLabel.lineBreakMode = .byTruncatingMiddle

        addSubview(titleLabel)
        addSubview(candidatesLabel)

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 10),

            candidatesLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            candidatesLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            candidatesLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 6),
            candidatesLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10),
        ])
    }
}
