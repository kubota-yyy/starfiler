import AppKit

final class FilterBarViewController: NSViewController, NSTextFieldDelegate {
    var onTextChanged: ((String) -> Void)?
    var onDidClose: (() -> Void)?

    private let backgroundView = NSVisualEffectView()
    private let promptLabel = NSTextField(labelWithString: "/")
    private let textField = NSTextField()
    private(set) var isVisible = false

    override func loadView() {
        view = NSView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureView()
        configureLayout()
    }

    func show(currentText: String) {
        if textField.stringValue != currentText {
            textField.stringValue = currentText
            onTextChanged?(currentText)
        }

        guard !isVisible else {
            focusInput()
            return
        }

        isVisible = true
        view.isHidden = false
        focusInput()
    }

    func close() {
        guard isVisible else {
            return
        }

        isVisible = false
        view.isHidden = true
        onDidClose?()
    }

    private func configureView() {
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true

        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        backgroundView.material = .hudWindow
        backgroundView.blendingMode = .withinWindow
        backgroundView.state = .active
        backgroundView.wantsLayer = true
        backgroundView.layer?.cornerRadius = 6
        backgroundView.layer?.masksToBounds = true

        promptLabel.translatesAutoresizingMaskIntoConstraints = false
        promptLabel.font = .monospacedSystemFont(ofSize: 13, weight: .semibold)

        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        textField.placeholderString = "Filter files..."
        textField.isBordered = false
        textField.isBezeled = false
        textField.focusRingType = .none
        textField.drawsBackground = false
        textField.delegate = self

        view.addSubview(backgroundView)
        backgroundView.addSubview(promptLabel)
        backgroundView.addSubview(textField)
    }

    private func configureLayout() {
        NSLayoutConstraint.activate([
            backgroundView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backgroundView.topAnchor.constraint(equalTo: view.topAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            view.heightAnchor.constraint(equalToConstant: 34),

            promptLabel.leadingAnchor.constraint(equalTo: backgroundView.leadingAnchor, constant: 10),
            promptLabel.centerYAnchor.constraint(equalTo: backgroundView.centerYAnchor),

            textField.leadingAnchor.constraint(equalTo: promptLabel.trailingAnchor, constant: 8),
            textField.trailingAnchor.constraint(equalTo: backgroundView.trailingAnchor, constant: -10),
            textField.centerYAnchor.constraint(equalTo: backgroundView.centerYAnchor)
        ])
    }

    private func focusInput() {
        DispatchQueue.main.async { [weak self] in
            guard let self else {
                return
            }
            self.view.window?.makeFirstResponder(self.textField)
        }
    }

    func controlTextDidChange(_ obj: Notification) {
        onTextChanged?(textField.stringValue)
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.cancelOperation(_:)) ||
            commandSelector == #selector(NSResponder.insertNewline(_:))
        {
            close()
            return true
        }

        return false
    }
}
