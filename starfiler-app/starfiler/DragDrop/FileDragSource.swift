import AppKit

final class FileDragSource: NSObject, NSDraggingSource {
    private static var localDragURLs: [URL] = []

    static var currentLocalDragURLs: [URL] {
        localDragURLs
    }

    func beginDragging(from sourceView: NSView, with event: NSEvent, urls: [URL], draggingFrame: NSRect? = nil) -> Bool {
        let normalizedURLs = urls.map(\.standardizedFileURL)
        guard !normalizedURLs.isEmpty else {
            return false
        }

        let frame = draggingFrame ?? defaultDraggingFrame(in: sourceView)

        let draggingItems = normalizedURLs.map { url in
            let draggingItem = NSDraggingItem(pasteboardWriter: url as NSURL)
            let icon = NSWorkspace.shared.icon(forFile: url.path)
            icon.size = NSSize(width: 18, height: 18)

            draggingItem.setDraggingFrame(frame, contents: icon)
            return draggingItem
        }

        Self.localDragURLs = normalizedURLs

        let session = sourceView.beginDraggingSession(with: draggingItems, event: event, source: self)
        session.animatesToStartingPositionsOnCancelOrFail = true
        return true
    }

    private func defaultDraggingFrame(in sourceView: NSView) -> NSRect {
        if let tableView = sourceView as? NSTableView {
            if tableView.selectedRow >= 0 {
                return tableView.rect(ofRow: tableView.selectedRow)
            }

            return NSRect(x: 0, y: 0, width: max(tableView.bounds.width, 120), height: max(tableView.rowHeight, 24))
        }

        if let collectionView = sourceView as? NSCollectionView,
           let selectedIndexPath = collectionView.selectionIndexPaths.first,
           let attributes = collectionView.layoutAttributesForItem(at: selectedIndexPath) {
            return attributes.frame
        }

        let centerX = sourceView.bounds.midX - 60
        let centerY = sourceView.bounds.midY - 12
        return NSRect(x: centerX, y: centerY, width: 120, height: 24)
    }

    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        context == .withinApplication ? [.copy, .move] : [.copy]
    }

    func ignoreModifierKeys(for session: NSDraggingSession) -> Bool {
        false
    }

    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        Self.localDragURLs = []
    }
}
