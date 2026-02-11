import AppKit

final class FilterBarViewController: NSViewController, NSTextFieldDelegate {
    enum CloseReason {
        case cancel
        case submit
        case programmatic
    }

    var onTextChanged: ((String) -> Void)?
    var onDidClose: ((CloseReason) -> Void)?

    private let backgroundView = NSVisualEffectView()
    private let promptLabel: NSTextField
    private let textField = NSTextField()
    private(set) var isVisible = false
    private let placeholder: String

    init(prompt: String = "/", placeholder: String = "Filter files...") {
        self.placeholder = placeholder
        self.promptLabel = NSTextField(labelWithString: prompt)
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

    func close(reason: CloseReason = .programmatic) {
        guard isVisible else {
            return
        }

        isVisible = false
        view.isHidden = true
        onDidClose?(reason)
    }

    func applyTheme(_ theme: FilerTheme, backgroundOpacity: CGFloat = 1.0) {
        let palette = theme.palette
        promptLabel.textColor = palette.filterBarPromptColor
        textField.textColor = palette.filterBarTextColor
        backgroundView.layer?.backgroundColor = palette.filterBarBackgroundColor.applyingBackgroundOpacity(backgroundOpacity).cgColor
        backgroundView.layer?.borderColor = palette.filterBarBorderColor.applyingBackgroundOpacity(backgroundOpacity).cgColor
        backgroundView.layer?.borderWidth = 1
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
        textField.placeholderString = placeholder
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
            let reason: CloseReason = commandSelector == #selector(NSResponder.insertNewline(_:))
                ? .submit
                : .cancel
            close(reason: reason)
            return true
        }

        return false
    }
}
