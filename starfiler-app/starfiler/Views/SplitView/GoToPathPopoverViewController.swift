import AppKit

final class GoToPathPopoverViewController: NSViewController, NSTextFieldDelegate {
    private let accentColor: NSColor
    private let onSubmit: (String) -> Void
    private let onCancel: () -> Void

    private let iconView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let pathField = NSTextField(string: "")
    private let hintLabel = NSTextField(labelWithString: "Enter: Go   Esc: Cancel")
    private let errorLabel = NSTextField(labelWithString: "")

    init(
        currentPath: String,
        accentColor: NSColor,
        onSubmit: @escaping (String) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.accentColor = accentColor
        self.onSubmit = onSubmit
        self.onCancel = onCancel
        super.init(nibName: nil, bundle: nil)

        titleLabel.stringValue = "Go to File or Folder"
        pathField.placeholderString = currentPath
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        let rootView = NSView(frame: NSRect(x: 0, y: 0, width: 430, height: 112))
        rootView.translatesAutoresizingMaskIntoConstraints = false

        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.image = NSImage(systemSymbolName: "scope", accessibilityDescription: nil)
        iconView.contentTintColor = accentColor

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        titleLabel.textColor = accentColor

        pathField.translatesAutoresizingMaskIntoConstraints = false
        pathField.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        pathField.delegate = self
        pathField.focusRingType = .default

        hintLabel.translatesAutoresizingMaskIntoConstraints = false
        hintLabel.font = .systemFont(ofSize: 11, weight: .regular)
        hintLabel.textColor = .secondaryLabelColor

        errorLabel.translatesAutoresizingMaskIntoConstraints = false
        errorLabel.font = .systemFont(ofSize: 11, weight: .medium)
        errorLabel.textColor = .systemRed
        errorLabel.isHidden = true

        rootView.addSubview(iconView)
        rootView.addSubview(titleLabel)
        rootView.addSubview(pathField)
        rootView.addSubview(hintLabel)
        rootView.addSubview(errorLabel)

        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: rootView.leadingAnchor, constant: 12),
            iconView.topAnchor.constraint(equalTo: rootView.topAnchor, constant: 12),
            iconView.widthAnchor.constraint(equalToConstant: 14),
            iconView.heightAnchor.constraint(equalToConstant: 14),

            titleLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 6),
            titleLabel.centerYAnchor.constraint(equalTo: iconView.centerYAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: rootView.trailingAnchor, constant: -12),

            pathField.leadingAnchor.constraint(equalTo: rootView.leadingAnchor, constant: 12),
            pathField.trailingAnchor.constraint(equalTo: rootView.trailingAnchor, constant: -12),
            pathField.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),

            hintLabel.leadingAnchor.constraint(equalTo: rootView.leadingAnchor, constant: 12),
            hintLabel.topAnchor.constraint(equalTo: pathField.bottomAnchor, constant: 8),

            errorLabel.leadingAnchor.constraint(equalTo: hintLabel.trailingAnchor, constant: 12),
            errorLabel.centerYAnchor.constraint(equalTo: hintLabel.centerYAnchor),
            errorLabel.trailingAnchor.constraint(lessThanOrEqualTo: rootView.trailingAnchor, constant: -12)
        ])

        view = rootView
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        focusInputField()
    }

    func focusInputField() {
        view.window?.makeFirstResponder(pathField)
        pathField.selectText(nil)
    }

    func showValidationError(_ message: String) {
        errorLabel.stringValue = message
        errorLabel.isHidden = false
        NSSound.beep()
        focusInputField()
    }

    func controlTextDidChange(_ obj: Notification) {
        if !errorLabel.isHidden {
            errorLabel.isHidden = true
        }
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            onSubmit(pathField.stringValue)
            return true
        }

        if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
            onCancel()
            return true
        }

        return false
    }
}
