import AppKit
import ImageIO

final class PreviewPaneViewController: NSViewController {
    private let viewModel: PreviewViewModel

    private let pathBarView = NSView()
    private let pathControl = NSPathControl()
    private let toolbarView = NSView()
    private let previousButton = NSButton()
    private let nextButton = NSButton()
    private let positionLabel = NSTextField(labelWithString: "0 / 0")
    private let zoomOutButton = NSButton()
    private let zoomInButton = NSButton()
    private let zoomSlider = NSSlider(value: 1.0, minValue: 0.05, maxValue: 8.0, target: nil, action: nil)
    private let zoomLabel = NSTextField(labelWithString: "100%")
    private let fitButton = NSButton()
    private let actualSizeButton = NSButton()
    private let recursiveButton = NSButton(checkboxWithTitle: "Recursive", target: nil, action: nil)

    private let contentContainerView = NSView()
    private let scrollView = NSScrollView()
    private let imageView = NSImageView()
    private let emptyStateLabel = NSTextField(labelWithString: "Select an image file")

    private var currentTheme: FilerTheme = .system
    private var backgroundOpacity: CGFloat = 1.0

    private var currentState: PreviewViewModel.State = .default
    private var currentImageURLs: [URL] = []
    private var currentImageURL: URL?
    private var recursiveScanTask: Task<Void, Never>?
    private var imageLoadTask: Task<Void, Never>?
    private let imageCache = NSCache<NSURL, NSImage>()

    var onRecursiveModeChanged: ((Bool) -> Void)?
    var onImageSelectionChanged: ((URL?) -> Void)?
    var onNavigateRequested: ((URL) -> Void)?

    init(viewModel: PreviewViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        recursiveScanTask?.cancel()
        imageLoadTask?.cancel()
    }

    override func loadView() {
        view = NSView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureView()
        configureLayout()
        bindViewModel()
        applyState(viewModel.state)
    }

    func applyTheme(_ theme: FilerTheme, backgroundOpacity: CGFloat = 1.0) {
        currentTheme = theme
        self.backgroundOpacity = backgroundOpacity
        applyCurrentTheme()
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        applyCurrentTheme()
    }

    private func configureView() {
        view.wantsLayer = true
        view.layer?.borderWidth = 1
        view.layer?.cornerRadius = 6
        view.layer?.masksToBounds = true

        pathBarView.translatesAutoresizingMaskIntoConstraints = false
        pathBarView.wantsLayer = true

        pathControl.translatesAutoresizingMaskIntoConstraints = false
        pathControl.pathStyle = .standard
        pathControl.controlSize = .small
        pathControl.target = self
        pathControl.action = #selector(handlePathControlClick(_:))

        toolbarView.translatesAutoresizingMaskIntoConstraints = false
        toolbarView.wantsLayer = true

        configureButton(previousButton, systemSymbolName: "chevron.left", action: #selector(handlePreviousImage))
        configureButton(nextButton, systemSymbolName: "chevron.right", action: #selector(handleNextImage))
        configureButton(zoomOutButton, systemSymbolName: "minus.magnifyingglass", action: #selector(handleZoomOut))
        configureButton(zoomInButton, systemSymbolName: "plus.magnifyingglass", action: #selector(handleZoomIn))

        fitButton.translatesAutoresizingMaskIntoConstraints = false
        fitButton.title = "Fit"
        fitButton.bezelStyle = .rounded
        fitButton.target = self
        fitButton.action = #selector(handleFitImage)

        actualSizeButton.translatesAutoresizingMaskIntoConstraints = false
        actualSizeButton.title = "100%"
        actualSizeButton.bezelStyle = .rounded
        actualSizeButton.target = self
        actualSizeButton.action = #selector(handleActualSize)

        zoomSlider.translatesAutoresizingMaskIntoConstraints = false
        zoomSlider.numberOfTickMarks = 0
        zoomSlider.target = self
        zoomSlider.action = #selector(handleZoomSliderChanged(_:))

        positionLabel.translatesAutoresizingMaskIntoConstraints = false
        positionLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        positionLabel.alignment = .center

        zoomLabel.translatesAutoresizingMaskIntoConstraints = false
        zoomLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .semibold)
        zoomLabel.alignment = .right

        recursiveButton.translatesAutoresizingMaskIntoConstraints = false
        recursiveButton.target = self
        recursiveButton.action = #selector(handleRecursiveToggle(_:))

        contentContainerView.translatesAutoresizingMaskIntoConstraints = false
        contentContainerView.wantsLayer = true

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = true
        scrollView.allowsMagnification = true
        scrollView.minMagnification = CGFloat(zoomSlider.minValue)
        scrollView.maxMagnification = CGFloat(zoomSlider.maxValue)

        imageView.imageScaling = .scaleNone
        imageView.frame = NSRect(x: 0, y: 0, width: 1, height: 1)
        scrollView.documentView = imageView

        emptyStateLabel.translatesAutoresizingMaskIntoConstraints = false
        emptyStateLabel.alignment = .center
        emptyStateLabel.font = .systemFont(ofSize: 13, weight: .regular)
        emptyStateLabel.maximumNumberOfLines = 3
    }

    private func configureLayout() {
        view.addSubview(pathBarView)
        view.addSubview(toolbarView)
        view.addSubview(contentContainerView)

        pathBarView.addSubview(pathControl)
        toolbarView.addSubview(previousButton)
        toolbarView.addSubview(nextButton)
        toolbarView.addSubview(positionLabel)
        toolbarView.addSubview(zoomOutButton)
        toolbarView.addSubview(zoomSlider)
        toolbarView.addSubview(zoomInButton)
        toolbarView.addSubview(zoomLabel)
        toolbarView.addSubview(fitButton)
        toolbarView.addSubview(actualSizeButton)
        toolbarView.addSubview(recursiveButton)

        contentContainerView.addSubview(scrollView)
        contentContainerView.addSubview(emptyStateLabel)

        NSLayoutConstraint.activate([
            pathBarView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            pathBarView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            pathBarView.topAnchor.constraint(equalTo: view.topAnchor),
            pathBarView.heightAnchor.constraint(equalToConstant: 30),

            pathControl.leadingAnchor.constraint(equalTo: pathBarView.leadingAnchor, constant: 10),
            pathControl.trailingAnchor.constraint(equalTo: pathBarView.trailingAnchor, constant: -10),
            pathControl.centerYAnchor.constraint(equalTo: pathBarView.centerYAnchor),

            toolbarView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            toolbarView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            toolbarView.topAnchor.constraint(equalTo: pathBarView.bottomAnchor),
            toolbarView.heightAnchor.constraint(equalToConstant: 38),

            contentContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            contentContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            contentContainerView.topAnchor.constraint(equalTo: toolbarView.bottomAnchor),
            contentContainerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            scrollView.leadingAnchor.constraint(equalTo: contentContainerView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: contentContainerView.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: contentContainerView.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: contentContainerView.bottomAnchor),

            emptyStateLabel.leadingAnchor.constraint(equalTo: contentContainerView.leadingAnchor, constant: 18),
            emptyStateLabel.trailingAnchor.constraint(equalTo: contentContainerView.trailingAnchor, constant: -18),
            emptyStateLabel.centerXAnchor.constraint(equalTo: contentContainerView.centerXAnchor),
            emptyStateLabel.centerYAnchor.constraint(equalTo: contentContainerView.centerYAnchor),

            previousButton.leadingAnchor.constraint(equalTo: toolbarView.leadingAnchor, constant: 8),
            previousButton.centerYAnchor.constraint(equalTo: toolbarView.centerYAnchor),
            previousButton.widthAnchor.constraint(equalToConstant: 28),

            nextButton.leadingAnchor.constraint(equalTo: previousButton.trailingAnchor, constant: 4),
            nextButton.centerYAnchor.constraint(equalTo: toolbarView.centerYAnchor),
            nextButton.widthAnchor.constraint(equalToConstant: 28),

            positionLabel.leadingAnchor.constraint(equalTo: nextButton.trailingAnchor, constant: 8),
            positionLabel.centerYAnchor.constraint(equalTo: toolbarView.centerYAnchor),
            positionLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 56),

            zoomOutButton.leadingAnchor.constraint(equalTo: positionLabel.trailingAnchor, constant: 12),
            zoomOutButton.centerYAnchor.constraint(equalTo: toolbarView.centerYAnchor),
            zoomOutButton.widthAnchor.constraint(equalToConstant: 28),

            zoomSlider.leadingAnchor.constraint(equalTo: zoomOutButton.trailingAnchor, constant: 6),
            zoomSlider.centerYAnchor.constraint(equalTo: toolbarView.centerYAnchor),
            zoomSlider.widthAnchor.constraint(equalToConstant: 150),

            zoomInButton.leadingAnchor.constraint(equalTo: zoomSlider.trailingAnchor, constant: 6),
            zoomInButton.centerYAnchor.constraint(equalTo: toolbarView.centerYAnchor),
            zoomInButton.widthAnchor.constraint(equalToConstant: 28),

            zoomLabel.leadingAnchor.constraint(equalTo: zoomInButton.trailingAnchor, constant: 8),
            zoomLabel.centerYAnchor.constraint(equalTo: toolbarView.centerYAnchor),
            zoomLabel.widthAnchor.constraint(equalToConstant: 54),

            fitButton.leadingAnchor.constraint(equalTo: zoomLabel.trailingAnchor, constant: 10),
            fitButton.centerYAnchor.constraint(equalTo: toolbarView.centerYAnchor),

            actualSizeButton.leadingAnchor.constraint(equalTo: fitButton.trailingAnchor, constant: 6),
            actualSizeButton.centerYAnchor.constraint(equalTo: toolbarView.centerYAnchor),

            recursiveButton.leadingAnchor.constraint(equalTo: actualSizeButton.trailingAnchor, constant: 12),
            recursiveButton.centerYAnchor.constraint(equalTo: toolbarView.centerYAnchor),
            recursiveButton.trailingAnchor.constraint(lessThanOrEqualTo: toolbarView.trailingAnchor, constant: -8)
        ])
    }

    private func configureButton(_ button: NSButton, systemSymbolName: String, action: Selector) {
        button.translatesAutoresizingMaskIntoConstraints = false
        button.bezelStyle = .texturedRounded
        button.image = NSImage(systemSymbolName: systemSymbolName, accessibilityDescription: nil)
        button.imagePosition = .imageOnly
        button.target = self
        button.action = action
    }

    private func bindViewModel() {
        viewModel.onStateChanged = { [weak self] state in
            self?.applyState(state)
        }
    }

    private func applyState(_ state: PreviewViewModel.State) {
        let previousState = currentState
        currentState = state
        recursiveButton.state = state.recursiveEnabled ? .on : .off
        updatePathControl(for: state)

        if state.recursiveEnabled {
            let shouldRescan =
                !previousState.recursiveEnabled ||
                previousState.currentDirectoryURL != state.currentDirectoryURL ||
                previousState.showHiddenFiles != state.showHiddenFiles

            if shouldRescan {
                startRecursiveScan(for: state)
            } else {
                applyImageURLs(currentImageURLs, selectedFileURL: state.selectedFileURL)
            }
        } else {
            recursiveScanTask?.cancel()
            applyImageURLs(state.siblingImageURLs, selectedFileURL: state.selectedFileURL)
        }
    }

    private func startRecursiveScan(for state: PreviewViewModel.State) {
        recursiveScanTask?.cancel()

        guard let rootDirectoryURL = state.currentDirectoryURL else {
            applyImageURLs([], selectedFileURL: state.selectedFileURL)
            return
        }

        positionLabel.stringValue = "Scanning..."

        recursiveScanTask = Task { [weak self] in
            let urls = await Self.collectImageURLsRecursively(
                from: rootDirectoryURL,
                includeHiddenFiles: state.showHiddenFiles
            )

            guard !Task.isCancelled else {
                return
            }

            await MainActor.run {
                self?.applyImageURLs(urls, selectedFileURL: state.selectedFileURL)
            }
        }
    }

    private func applyImageURLs(_ urls: [URL], selectedFileURL: URL?) {
        currentImageURLs = urls.map(\.standardizedFileURL)

        let selectedImageURL = selectedFileURL?.standardizedFileURL
        let selectedIsImage = selectedImageURL?.isImageFile ?? false

        if
            let selectedImageURL,
            selectedIsImage,
            let index = currentImageURLs.firstIndex(of: selectedImageURL)
        {
            setCurrentImage(url: currentImageURLs[index], notifySelection: false)
            return
        }

        if selectedFileURL != nil, !selectedIsImage {
            setCurrentImage(url: nil, notifySelection: false, message: "Image-only mode. Select an image file.")
            return
        }

        let fallbackMessage = currentImageURLs.isEmpty ? "No image files found" : "Image-only mode. Select an image file."
        setCurrentImage(url: nil, notifySelection: false, message: fallbackMessage)
    }

    private func setCurrentImage(url: URL?, notifySelection: Bool, message: String = "No image files found") {
        currentImageURL = url?.standardizedFileURL
        updateNavigationState()

        guard let url = currentImageURL else {
            imageLoadTask?.cancel()
            imageView.image = nil
            scrollView.isHidden = true
            emptyStateLabel.stringValue = message
            emptyStateLabel.isHidden = false
            if notifySelection {
                onImageSelectionChanged?(nil)
            }
            return
        }

        loadAndDisplayImage(from: url)
        if notifySelection {
            onImageSelectionChanged?(url)
        }
    }

    private func updateNavigationState() {
        let count = currentImageURLs.count
        let currentIndex = currentImageURL.flatMap { currentImageURLs.firstIndex(of: $0) }

        if let currentIndex {
            positionLabel.stringValue = "\(currentIndex + 1) / \(count)"
        } else {
            positionLabel.stringValue = "0 / \(count)"
        }

        previousButton.isEnabled = (currentIndex ?? 0) > 0
        nextButton.isEnabled = count > 0 && ((currentIndex ?? -1) < count - 1)
        let hasImage = currentImageURL != nil
        zoomOutButton.isEnabled = hasImage
        zoomInButton.isEnabled = hasImage
        zoomSlider.isEnabled = hasImage
        fitButton.isEnabled = hasImage
        actualSizeButton.isEnabled = hasImage
    }

    private func loadAndDisplayImage(from url: URL) {
        imageLoadTask?.cancel()

        if let cached = imageCache.object(forKey: url as NSURL) {
            displayLoadedImage(cached)
            return
        }

        imageLoadTask = Task { [weak self] in
            let loadedImage = await Self.decodeImage(from: url)
            guard !Task.isCancelled else {
                return
            }

            await MainActor.run {
                guard let self, self.currentImageURL == url else {
                    return
                }

                guard let loadedImage else {
                    self.imageView.image = nil
                    self.scrollView.isHidden = true
                    self.emptyStateLabel.stringValue = "Unable to load image"
                    self.emptyStateLabel.isHidden = false
                    return
                }

                self.imageCache.setObject(loadedImage, forKey: url as NSURL)
                self.displayLoadedImage(loadedImage)
            }
        }
    }

    private func displayLoadedImage(_ image: NSImage) {
        imageView.image = image
        imageView.frame = NSRect(origin: .zero, size: image.size)
        scrollView.documentView = imageView
        scrollView.isHidden = false
        emptyStateLabel.isHidden = true
        fitImageToView()
    }

    private func applyCurrentTheme() {
        let palette = currentTheme.palette
        view.layer?.borderColor = palette.previewBorderColor.applyingBackgroundOpacity(backgroundOpacity).cgColor
        view.layer?.backgroundColor = palette.previewBackgroundColor.applyingBackgroundOpacity(backgroundOpacity).cgColor
        pathBarView.layer?.backgroundColor = palette.inactiveHeaderColor.applyingBackgroundOpacity(backgroundOpacity).cgColor
        toolbarView.layer?.backgroundColor = palette.inactiveHeaderColor.applyingBackgroundOpacity(backgroundOpacity).cgColor
        contentContainerView.layer?.backgroundColor = palette.previewBackgroundColor.applyingBackgroundOpacity(backgroundOpacity).cgColor
        scrollView.backgroundColor = palette.previewBackgroundColor.applyingBackgroundOpacity(backgroundOpacity)
        emptyStateLabel.textColor = palette.secondaryTextColor
        positionLabel.textColor = palette.secondaryTextColor
        zoomLabel.textColor = palette.secondaryTextColor
    }

    private func setZoomScale(_ scale: CGFloat) {
        let clamped = min(max(scale, CGFloat(zoomSlider.minValue)), CGFloat(zoomSlider.maxValue))
        scrollView.setMagnification(clamped, centeredAt: NSPoint(x: imageView.bounds.midX, y: imageView.bounds.midY))
        zoomSlider.doubleValue = Double(clamped)
        zoomLabel.stringValue = "\(Int((clamped * 100).rounded()))%"
    }

    private func fitImageToView() {
        guard let image = imageView.image, image.size.width > 0, image.size.height > 0 else {
            return
        }

        let viewportSize = scrollView.contentView.bounds.size
        guard viewportSize.width > 0, viewportSize.height > 0 else {
            return
        }

        let widthScale = viewportSize.width / image.size.width
        let heightScale = viewportSize.height / image.size.height
        let fitScale = min(widthScale, heightScale)
        setZoomScale(fitScale)
    }

    @objc
    private func handlePreviousImage() {
        guard let currentImageURL, let currentIndex = currentImageURLs.firstIndex(of: currentImageURL), currentIndex > 0 else {
            return
        }
        setCurrentImage(url: currentImageURLs[currentIndex - 1], notifySelection: true)
    }

    @objc
    private func handleNextImage() {
        guard let currentImageURL, let currentIndex = currentImageURLs.firstIndex(of: currentImageURL) else {
            return
        }
        let nextIndex = currentIndex + 1
        guard currentImageURLs.indices.contains(nextIndex) else {
            return
        }
        setCurrentImage(url: currentImageURLs[nextIndex], notifySelection: true)
    }

    @objc
    private func handleZoomOut() {
        setZoomScale(scrollView.magnification * 0.85)
    }

    @objc
    private func handleZoomIn() {
        setZoomScale(scrollView.magnification * 1.15)
    }

    @objc
    private func handleZoomSliderChanged(_ sender: NSSlider) {
        setZoomScale(CGFloat(sender.doubleValue))
    }

    @objc
    private func handleFitImage() {
        fitImageToView()
    }

    @objc
    private func handleActualSize() {
        setZoomScale(1.0)
    }

    @objc
    private func handleRecursiveToggle(_ sender: NSButton) {
        let enabled = sender.state == .on
        onRecursiveModeChanged?(enabled)
    }

    @objc
    private func handlePathControlClick(_ sender: NSPathControl) {
        guard let clickedURL = sender.clickedPathItem?.url?.standardizedFileURL else {
            return
        }

        var isDirectory: ObjCBool = false
        let destination: URL
        if FileManager.default.fileExists(atPath: clickedURL.path, isDirectory: &isDirectory), isDirectory.boolValue {
            destination = clickedURL
        } else {
            destination = clickedURL.deletingLastPathComponent().standardizedFileURL
        }

        onNavigateRequested?(destination)
    }

    private func updatePathControl(for state: PreviewViewModel.State) {
        if let selectedFileURL = state.selectedFileURL?.standardizedFileURL {
            pathControl.url = selectedFileURL
            return
        }

        pathControl.url = state.currentDirectoryURL?.standardizedFileURL
    }

    private static func decodeImage(from url: URL) async -> NSImage? {
        await Task.detached(priority: .userInitiated) {
            guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
                return nil
            }
            guard let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
                return nil
            }
            let size = NSSize(width: cgImage.width, height: cgImage.height)
            return NSImage(cgImage: cgImage, size: size)
        }.value
    }

    private static func collectImageURLsRecursively(from rootDirectoryURL: URL, includeHiddenFiles: Bool) async -> [URL] {
        await Task.detached(priority: .userInitiated) {
            let resourceKeys: Set<URLResourceKey> = [.isDirectoryKey, .isPackageKey, .isHiddenKey]
            let options: FileManager.DirectoryEnumerationOptions = includeHiddenFiles ? [.skipsPackageDescendants] : [.skipsHiddenFiles, .skipsPackageDescendants]

            guard let enumerator = FileManager.default.enumerator(
                at: rootDirectoryURL,
                includingPropertiesForKeys: Array(resourceKeys),
                options: options
            ) else {
                return []
            }

            var urls: [URL] = []
            for case let url as URL in enumerator {
                if Task.isCancelled {
                    return []
                }

                let values = try? url.resourceValues(forKeys: resourceKeys)
                let isDirectory = values?.isDirectory ?? false
                if isDirectory {
                    continue
                }

                if url.isImageFile {
                    urls.append(url.standardizedFileURL)
                }
            }

            return urls.sorted {
                $0.path.localizedStandardCompare($1.path) == .orderedAscending
            }
        }.value
    }
}
