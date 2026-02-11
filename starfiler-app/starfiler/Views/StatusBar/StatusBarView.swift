import AppKit

final class StatusBarView: NSView {
    private let pathLabel = NSTextField(labelWithString: "")
    private let countLabel = NSTextField(labelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    func update(path: String, itemCount: Int, markedCount: Int) {
        pathLabel.stringValue = path
        countLabel.stringValue = "\(itemCount) items | \(markedCount) marked"
    }

    private func setupView() {
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        pathLabel.translatesAutoresizingMaskIntoConstraints = false
        pathLabel.lineBreakMode = .byTruncatingMiddle

        countLabel.translatesAutoresizingMaskIntoConstraints = false
        countLabel.alignment = .right

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
