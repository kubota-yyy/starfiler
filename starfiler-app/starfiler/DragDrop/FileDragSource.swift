import AppKit

final class FileDragSource: NSObject, NSDraggingSource {
    func beginDragging(from tableView: NSTableView, with event: NSEvent, urls: [URL]) -> Bool {
        let normalizedURLs = urls.map(\.standardizedFileURL)
        guard !normalizedURLs.isEmpty else {
            return false
        }

        let draggingItems = normalizedURLs.map { url in
            let draggingItem = NSDraggingItem(pasteboardWriter: url as NSURL)
            let icon = NSWorkspace.shared.icon(forFile: url.path)
            icon.size = NSSize(width: 18, height: 18)

            let rowRect = tableView.selectedRow >= 0
                ? tableView.rect(ofRow: tableView.selectedRow)
                : NSRect(x: 0, y: 0, width: tableView.bounds.width, height: tableView.rowHeight)

            draggingItem.setDraggingFrame(rowRect, contents: icon)
            return draggingItem
        }

        let session = tableView.beginDraggingSession(with: draggingItems, event: event, source: self)
        session.animatesToStartingPositionsOnCancelOrFail = true
        return true
    }

    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        context == .withinApplication ? [.copy, .move] : [.copy]
    }

    func ignoreModifierKeys(for session: NSDraggingSession) -> Bool {
        false
    }
}
