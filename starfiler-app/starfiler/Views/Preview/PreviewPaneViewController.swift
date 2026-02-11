import AppKit
import QuickLookUI

final class PreviewPaneViewController: NSViewController {
    private let viewModel: PreviewViewModel
    private var previewView: QLPreviewView!
    private let emptyStateLabel = NSTextField(labelWithString: "No file selected")

    init(viewModel: PreviewViewModel) {
        self.viewModel = viewModel
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
        bindViewModel()
        applyPreviewURL(viewModel.currentURL)
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        view.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.6).cgColor
    }

    private func configureView() {
        view.wantsLayer = true
        view.layer?.borderWidth = 1
        view.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.6).cgColor

        previewView = QLPreviewView(frame: .zero, style: .normal) ?? QLPreviewView()
        previewView.translatesAutoresizingMaskIntoConstraints = false
        previewView.autostarts = true

        emptyStateLabel.translatesAutoresizingMaskIntoConstraints = false
        emptyStateLabel.alignment = .center
        emptyStateLabel.textColor = .secondaryLabelColor
        emptyStateLabel.font = .systemFont(ofSize: 13, weight: .regular)
    }

    private func configureLayout() {
        view.addSubview(previewView)
        view.addSubview(emptyStateLabel)

        NSLayoutConstraint.activate([
            previewView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            previewView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            previewView.topAnchor.constraint(equalTo: view.topAnchor),
            previewView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            emptyStateLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyStateLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    private func bindViewModel() {
        viewModel.onCurrentURLChanged = { [weak self] url in
            self?.applyPreviewURL(url)
        }
    }

    private func applyPreviewURL(_ url: URL?) {
        if let url {
            previewView.previewItem = url as NSURL
            previewView.isHidden = false
            emptyStateLabel.isHidden = true
        } else {
            previewView.previewItem = nil
            previewView.isHidden = true
            emptyStateLabel.isHidden = false
        }
    }
}
