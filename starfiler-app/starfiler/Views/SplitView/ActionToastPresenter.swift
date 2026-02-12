import AppKit

final class ActionToastPresenter {
    private weak var currentToast: NSView?
    private var dismissTask: Task<Void, Never>?
    var starEffectsEnabled = true
    var palette: FilerThemePalette?

    func show(message: String, in hostView: NSView) {
        dismissTask?.cancel()
        currentToast?.removeFromSuperview()

        let toastView = makeToastView(message: message)
        toastView.alphaValue = 0
        hostView.addSubview(toastView)

        NSLayoutConstraint.activate([
            toastView.trailingAnchor.constraint(equalTo: hostView.trailingAnchor, constant: -16),
            toastView.bottomAnchor.constraint(equalTo: hostView.bottomAnchor, constant: -16),
            toastView.widthAnchor.constraint(lessThanOrEqualToConstant: 380)
        ])

        hostView.layoutSubtreeIfNeeded()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.14
            toastView.animator().alphaValue = 1
        }

        if starEffectsEnabled, let layer = hostView.layer {
            let toastFrame = toastView.frame
            let burstPoint = CGPoint(x: toastFrame.minX + 6, y: toastFrame.midY)
            let glowColor = palette?.starGlowColor ?? .controlAccentColor
            StarSparkleAnimator.burst(count: 8, in: layer, at: burstPoint, color: glowColor, size: 10, duration: 0.5)
        }

        currentToast = toastView
        dismissTask = Task { @MainActor [weak self, weak toastView] in
            try? await Task.sleep(for: .milliseconds(2400))
            guard let self, let toastView else {
                return
            }

            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.16
                toastView.animator().alphaValue = 0
            }, completionHandler: {
                toastView.removeFromSuperview()
                if self.currentToast === toastView {
                    self.currentToast = nil
                }
            })
        }
    }

    private func makeToastView(message: String) -> NSView {
        let container = NSVisualEffectView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.material = .hudWindow
        container.blendingMode = .withinWindow
        container.state = .active
        container.wantsLayer = true
        container.layer?.cornerRadius = 10
        container.layer?.masksToBounds = true
        container.layer?.borderWidth = 1
        container.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.35).cgColor

        let sparkleImageView = NSImageView()
        sparkleImageView.translatesAutoresizingMaskIntoConstraints = false
        sparkleImageView.image = NSImage(systemSymbolName: "sparkles", accessibilityDescription: nil)
        sparkleImageView.contentTintColor = palette?.starGlowColor ?? .controlAccentColor
        sparkleImageView.isHidden = !starEffectsEnabled

        let label = NSTextField(wrappingLabelWithString: message)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textColor = .labelColor
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.maximumNumberOfLines = 3

        container.addSubview(sparkleImageView)
        container.addSubview(label)
        NSLayoutConstraint.activate([
            sparkleImageView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 10),
            sparkleImageView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            sparkleImageView.widthAnchor.constraint(equalToConstant: 18),
            sparkleImageView.heightAnchor.constraint(equalToConstant: 18),

            label.leadingAnchor.constraint(equalTo: sparkleImageView.trailingAnchor, constant: 6),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            label.topAnchor.constraint(equalTo: container.topAnchor, constant: 10),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -10)
        ])

        return container
    }
}
