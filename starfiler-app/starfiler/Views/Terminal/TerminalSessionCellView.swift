import AppKit

final class TerminalSessionCellView: NSTableCellView {
    static let identifier = NSUserInterfaceItemIdentifier("TerminalSessionCell")

    private let statusDot = NSView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let closeButton = NSButton()

    var onCloseClicked: (() -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        statusDot.translatesAutoresizingMaskIntoConstraints = false
        statusDot.wantsLayer = true
        statusDot.layer?.cornerRadius = 4

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .systemFont(ofSize: 12, weight: .medium)
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.textColor = .labelColor

        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.bezelStyle = .inline
        closeButton.image = NSImage(systemSymbolName: "xmark", accessibilityDescription: "Close")
        closeButton.imageScaling = .scaleProportionallyDown
        closeButton.isBordered = false
        closeButton.target = self
        closeButton.action = #selector(closeClicked)
        closeButton.setContentHuggingPriority(.required, for: .horizontal)

        addSubview(statusDot)
        addSubview(titleLabel)
        addSubview(closeButton)

        NSLayoutConstraint.activate([
            statusDot.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            statusDot.centerYAnchor.constraint(equalTo: centerYAnchor),
            statusDot.widthAnchor.constraint(equalToConstant: 8),
            statusDot.heightAnchor.constraint(equalToConstant: 8),

            titleLabel.leadingAnchor.constraint(equalTo: statusDot.trailingAnchor, constant: 6),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: closeButton.leadingAnchor, constant: -4),

            closeButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            closeButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: 16),
            closeButton.heightAnchor.constraint(equalToConstant: 16),
        ])
    }

    func configure(with session: TerminalSession, isActive: Bool) {
        titleLabel.stringValue = session.title
        titleLabel.textColor = isActive ? .labelColor : .secondaryLabelColor
        statusDot.layer?.backgroundColor = statusColor(for: session.status).cgColor
    }

    private func statusColor(for status: TerminalSessionStatus) -> NSColor {
        switch status {
        case .launching: return .systemYellow
        case .running: return .systemGreen
        case .waitingForInput: return .systemYellow
        case .completed: return .systemGray
        case .error: return .systemRed
        }
    }

    @objc private func closeClicked() {
        onCloseClicked?()
    }
}
