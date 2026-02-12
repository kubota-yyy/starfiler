import AppKit

final class BorderlessSplitView: NSSplitView {
    override var dividerThickness: CGFloat {
        1
    }

    override var dividerColor: NSColor {
        NSColor.separatorColor.withAlphaComponent(0.72)
    }

    override func drawDivider(in rect: NSRect) {
        dividerColor.setFill()
        NSBezierPath(rect: rect.integral).fill()
    }
}
