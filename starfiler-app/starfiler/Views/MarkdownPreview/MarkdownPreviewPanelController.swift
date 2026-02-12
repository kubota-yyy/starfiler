import AppKit
import WebKit

private final class MarkdownPreviewContentView: NSVisualEffectView {
    var onEscapePressed: (() -> Void)?

    override func cancelOperation(_ sender: Any?) {
        onEscapePressed?()
    }

    override var acceptsFirstResponder: Bool {
        true
    }
}

private final class MarkdownWebViewDelegate: NSObject, WKNavigationDelegate {
    var onPageLoaded: (() -> Void)?

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        onPageLoaded?()
    }
}

final class MarkdownPreviewPanelController {
    private var panel: NSPanel?
    private var webView: WKWebView?
    private var webViewDelegate: MarkdownWebViewDelegate?
    var onDismiss: (() -> Void)?

    func showRelativeTo(window: NSWindow, fileURL: URL, palette: FilerThemePalette) {
        dismiss()

        let markdownText: String
        do {
            markdownText = try String(contentsOf: fileURL, encoding: .utf8)
        } catch {
            markdownText = "Failed to read file: \(error.localizedDescription)"
        }

        let windowFrame = window.frame

        let panel = NSPanel(
            contentRect: windowFrame,
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.title = fileURL.lastPathComponent
        panel.isMovableByWindowBackground = true
        panel.becomesKeyOnlyIfNeeded = false
        panel.animationBehavior = .utilityWindow
        panel.minSize = NSSize(width: 600, height: 400)

        let contentView = MarkdownPreviewContentView()
        contentView.material = .hudWindow
        contentView.blendingMode = .behindWindow
        contentView.state = .active
        contentView.onEscapePressed = { [weak self] in
            self?.dismiss()
        }
        panel.contentView = contentView

        let contentSize = panel.contentRect(forFrameRect: panel.frame).size
        let halfWidth = contentSize.width / 2

        let splitView = NSSplitView(frame: NSRect(origin: .zero, size: contentSize))
        splitView.autoresizingMask = [.width, .height]
        splitView.isVertical = true
        splitView.dividerStyle = .thin

        let rawTextScrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: halfWidth, height: contentSize.height))
        rawTextScrollView.hasVerticalScroller = true
        rawTextScrollView.hasHorizontalScroller = false
        rawTextScrollView.autohidesScrollers = true
        rawTextScrollView.drawsBackground = true
        rawTextScrollView.backgroundColor = palette.previewBackgroundColor

        let rawTextView = NSTextView(frame: NSRect(x: 0, y: 0, width: halfWidth, height: contentSize.height))
        rawTextView.isEditable = false
        rawTextView.isSelectable = true
        rawTextView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        rawTextView.textColor = palette.primaryTextColor
        rawTextView.backgroundColor = palette.previewBackgroundColor
        rawTextView.textContainerInset = NSSize(width: 12, height: 12)
        rawTextView.isVerticallyResizable = true
        rawTextView.isHorizontallyResizable = false
        rawTextView.autoresizingMask = [.width]
        rawTextView.textContainer?.widthTracksTextView = true
        rawTextView.string = markdownText
        rawTextScrollView.documentView = rawTextView

        let webView = WKWebView(frame: NSRect(x: halfWidth, y: 0, width: halfWidth, height: contentSize.height))
        self.webView = webView

        let delegate = MarkdownWebViewDelegate()
        delegate.onPageLoaded = { [weak self] in
            self?.injectMarkdown(markdownText)
        }
        webView.navigationDelegate = delegate
        self.webViewDelegate = delegate

        splitView.addArrangedSubview(rawTextScrollView)
        splitView.addArrangedSubview(webView)
        contentView.addSubview(splitView)

        splitView.setPosition(halfWidth, ofDividerAt: 0)

        loadHTMLTemplate(into: webView)

        window.addChildWindow(panel, ordered: .above)
        panel.makeKeyAndOrderFront(nil)
        contentView.window?.makeFirstResponder(contentView)
        self.panel = panel
    }

    func dismiss() {
        panel?.orderOut(nil)
        if let panel, let parent = panel.parent {
            parent.removeChildWindow(panel)
        }
        webView?.navigationDelegate = nil
        webViewDelegate = nil
        webView = nil
        panel = nil
        onDismiss?()
    }

    private func loadHTMLTemplate(into webView: WKWebView) {
        guard let htmlURL = Bundle.main.url(forResource: "markdown-preview", withExtension: "html"),
              let htmlTemplate = try? String(contentsOf: htmlURL, encoding: .utf8) else {
            webView.loadHTMLString("<html><body><p>Failed to load preview template.</p></body></html>", baseURL: nil)
            return
        }

        webView.loadHTMLString(htmlTemplate, baseURL: nil)
    }

    private func injectMarkdown(_ markdownText: String) {
        guard let webView else {
            return
        }

        guard let jsonData = try? JSONEncoder().encode(markdownText),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return
        }

        let js = "renderMarkdown(\(jsonString));"
        webView.evaluateJavaScript(js) { _, error in
            if let error {
                print("Markdown render error: \(error.localizedDescription)")
            }
        }
    }
}
