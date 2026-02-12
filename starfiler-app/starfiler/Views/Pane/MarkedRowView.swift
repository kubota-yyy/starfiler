import AppKit

final class MarkedRowView: NSTableRowView {
    var isMarkedRow = false
    var isVisualMode = false
    var markedColor = NSColor.systemOrange.withAlphaComponent(0.14)
    var visualMarkedColor = NSColor.controlAccentColor.withAlphaComponent(0.22)

    override func drawBackground(in dirtyRect: NSRect) {
        guard isMarkedRow else {
            super.drawBackground(in: dirtyRect)
            return
        }

        let color = isVisualMode ? visualMarkedColor : markedColor

        color.setFill()
        dirtyRect.fill()
    }
}
