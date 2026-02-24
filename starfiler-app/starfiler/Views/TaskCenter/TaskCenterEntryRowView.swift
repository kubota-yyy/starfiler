import AppKit

final class TaskCenterEntryRowView: NSTableCellView {
    private let iconView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let detailLabel = NSTextField(labelWithString: "")
    private let progressBar = NSProgressIndicator()
    private let actionButton = NSButton()
    private let secondaryButton = NSButton()
    private let errorDetailLabel = NSTextField(wrappingLabelWithString: "")
    private let timestampLabel = NSTextField(labelWithString: "")

    var onCancel: (() -> Void)?
    var onRetry: (() -> Void)?
    var onCopyErrorDetail: (() -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupSubviews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with entry: TaskCenterEntry) {
        titleLabel.stringValue = entry.displayTitle
        iconView.image = iconImage(for: entry)
        iconView.contentTintColor = iconColor(for: entry)
        timestampLabel.stringValue = Self.timeFormatter.string(from: entry.startedAt)

        switch entry.status {
        case .running(let completed, let total, let currentFile):
            configureRunning(completed: completed, total: total, currentFile: currentFile)
        case .completed(let record):
            configureCompleted(record: record)
        case .failed(let error, _):
            configureFailed(error: error)
        case .cancelled:
            configureCancelled()
        }
    }

    private func configureRunning(completed: Int, total: Int, currentFile: URL) {
        detailLabel.stringValue = "\(completed)/\(total) — \(currentFile.lastPathComponent)"
        detailLabel.isHidden = false
        progressBar.isHidden = false
        progressBar.isIndeterminate = false
        progressBar.maxValue = Double(total)
        progressBar.doubleValue = Double(completed)
        actionButton.title = "Cancel"
        actionButton.isHidden = false
        actionButton.action = #selector(cancelAction)
        secondaryButton.isHidden = true
        errorDetailLabel.isHidden = true
        timestampLabel.isHidden = true
    }

    private func configureCompleted(record: FileOperationRecord) {
        let count = record.result.affectedURLs.count
        detailLabel.stringValue = "\(count) \(count == 1 ? "item" : "items")"
        detailLabel.isHidden = false
        progressBar.isHidden = true
        actionButton.isHidden = true
        secondaryButton.isHidden = true
        errorDetailLabel.isHidden = true
        timestampLabel.isHidden = false
    }

    private func configureFailed(error: String) {
        detailLabel.stringValue = error
        detailLabel.isHidden = false
        detailLabel.textColor = .systemRed
        progressBar.isHidden = true
        actionButton.title = "Retry"
        actionButton.isHidden = false
        actionButton.action = #selector(retryAction)
        secondaryButton.title = "Copy Details"
        secondaryButton.isHidden = false
        secondaryButton.action = #selector(copyDetailAction)
        errorDetailLabel.isHidden = true
        timestampLabel.isHidden = false
    }

    private func configureCancelled() {
        detailLabel.stringValue = "Cancelled"
        detailLabel.isHidden = false
        detailLabel.textColor = .secondaryLabelColor
        progressBar.isHidden = true
        actionButton.isHidden = true
        secondaryButton.isHidden = true
        errorDetailLabel.isHidden = true
        timestampLabel.isHidden = false
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        onCancel = nil
        onRetry = nil
        onCopyErrorDetail = nil
        detailLabel.textColor = .secondaryLabelColor
    }

    private func setupSubviews() {
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.imageScaling = .scaleProportionallyDown

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .systemFont(ofSize: 12, weight: .medium)
        titleLabel.lineBreakMode = .byTruncatingTail

        detailLabel.translatesAutoresizingMaskIntoConstraints = false
        detailLabel.font = .systemFont(ofSize: 11)
        detailLabel.textColor = .secondaryLabelColor
        detailLabel.lineBreakMode = .byTruncatingMiddle

        progressBar.translatesAutoresizingMaskIntoConstraints = false
        progressBar.style = .bar
        progressBar.controlSize = .small
        progressBar.isHidden = true

        actionButton.translatesAutoresizingMaskIntoConstraints = false
        actionButton.bezelStyle = .inline
        actionButton.controlSize = .small
        actionButton.font = .systemFont(ofSize: 11)
        actionButton.target = self
        actionButton.isHidden = true

        secondaryButton.translatesAutoresizingMaskIntoConstraints = false
        secondaryButton.bezelStyle = .inline
        secondaryButton.controlSize = .small
        secondaryButton.font = .systemFont(ofSize: 11)
        secondaryButton.target = self
        secondaryButton.isHidden = true

        errorDetailLabel.translatesAutoresizingMaskIntoConstraints = false
        errorDetailLabel.font = .monospacedSystemFont(ofSize: 10, weight: .regular)
        errorDetailLabel.textColor = .secondaryLabelColor
        errorDetailLabel.isHidden = true

        timestampLabel.translatesAutoresizingMaskIntoConstraints = false
        timestampLabel.font = .monospacedSystemFont(ofSize: 10, weight: .regular)
        timestampLabel.textColor = .tertiaryLabelColor
        timestampLabel.alignment = .right
        timestampLabel.isHidden = true

        let textStack = NSStackView(views: [titleLabel, detailLabel, progressBar])
        textStack.translatesAutoresizingMaskIntoConstraints = false
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 2

        let buttonStack = NSStackView(views: [actionButton, secondaryButton])
        buttonStack.translatesAutoresizingMaskIntoConstraints = false
        buttonStack.orientation = .horizontal
        buttonStack.spacing = 4

        addSubview(iconView)
        addSubview(textStack)
        addSubview(buttonStack)
        addSubview(timestampLabel)

        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 16),
            iconView.heightAnchor.constraint(equalToConstant: 16),

            textStack.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 8),
            textStack.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            textStack.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -6),
            textStack.trailingAnchor.constraint(lessThanOrEqualTo: buttonStack.leadingAnchor, constant: -8),

            progressBar.widthAnchor.constraint(equalTo: textStack.widthAnchor),

            buttonStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            buttonStack.centerYAnchor.constraint(equalTo: centerYAnchor),

            timestampLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            timestampLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6)
        ])
    }

    private func iconImage(for entry: TaskCenterEntry) -> NSImage? {
        let name: String
        switch entry.status {
        case .running:
            switch entry.operation.type {
            case .copy: name = "doc.on.doc"
            case .move: name = "arrow.right.doc.on.clipboard"
            case .trash: name = "trash"
            case .rename: name = "pencil"
            case .createDirectory: name = "folder.badge.plus"
            case .batchRename: name = "pencil.and.list.clipboard"
            }
        case .completed:
            name = "checkmark.circle.fill"
        case .failed:
            name = "exclamationmark.triangle.fill"
        case .cancelled:
            name = "xmark.circle"
        }
        return NSImage(systemSymbolName: name, accessibilityDescription: nil)
    }

    private func iconColor(for entry: TaskCenterEntry) -> NSColor {
        switch entry.status {
        case .running: return .controlAccentColor
        case .completed: return .systemGreen
        case .failed: return .systemRed
        case .cancelled: return .secondaryLabelColor
        }
    }

    @objc private func cancelAction() {
        onCancel?()
    }

    @objc private func retryAction() {
        onRetry?()
    }

    @objc private func copyDetailAction() {
        onCopyErrorDetail?()
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()
}
