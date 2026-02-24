import Foundation

enum GlobalActionRoutingResult: Equatable {
    case handled
    case handledWithToast(String)
    case unhandled
}

struct GlobalActionRouter {
    struct Handlers {
        let copy: () -> Void
        let copyToClipboard: () -> Void
        let paste: () -> Void
        let pasteFromClipboard: () -> Void
        let move: () -> Void
        let cutToClipboard: () -> Void
        let delete: () -> Void
        let rename: () -> Void
        let createDirectory: () -> Void
        let undo: () -> Void
        let togglePreview: () -> Void
        let toggleSidebar: () -> Void
        let toggleLeftPane: () -> Void
        let toggleRightPane: () -> Void
        let toggleSinglePane: () -> Void
        let equalizePaneWidths: () -> Void
        let matchOtherPaneDirectory: () -> Bool
        let goToOtherPaneDirectory: () -> Bool
        let openBookmarkSearch: () -> Void
        let openHistory: () -> Void
        let addBookmark: () -> Void
        let batchRename: () -> Void
        let syncPanesLeftToRight: () -> Bool
        let syncPanesRightToLeft: () -> Bool
        let togglePin: () -> String
        let terminalAction: (KeyAction) -> Void
    }

    func route(_ action: KeyAction, handlers: Handlers) -> GlobalActionRoutingResult {
        switch action {
        case .copy:
            handlers.copy()
            return .handled
        case .copyToClipboard:
            handlers.copyToClipboard()
            return .handled
        case .paste:
            handlers.paste()
            return .handled
        case .pasteFromClipboard:
            handlers.pasteFromClipboard()
            return .handled
        case .move:
            handlers.move()
            return .handled
        case .cutToClipboard:
            handlers.cutToClipboard()
            return .handled
        case .delete:
            handlers.delete()
            return .handled
        case .rename:
            handlers.rename()
            return .handled
        case .createDirectory:
            handlers.createDirectory()
            return .handled
        case .undo:
            handlers.undo()
            return .handled
        case .togglePreview:
            handlers.togglePreview()
            return .handled
        case .toggleSidebar:
            handlers.toggleSidebar()
            return .handled
        case .toggleLeftPane:
            handlers.toggleLeftPane()
            return .handled
        case .toggleRightPane:
            handlers.toggleRightPane()
            return .handled
        case .toggleSinglePane:
            handlers.toggleSinglePane()
            return .handled
        case .equalizePaneWidths:
            handlers.equalizePaneWidths()
            return .handled
        case .matchOtherPaneDirectory:
            return handlers.matchOtherPaneDirectory() ? .handledWithToast("Other pane set to current folder") : .handled
        case .goToOtherPaneDirectory:
            return handlers.goToOtherPaneDirectory() ? .handledWithToast("Moved to other pane folder") : .handled
        case .openBookmarkSearch:
            handlers.openBookmarkSearch()
            return .handled
        case .openHistory:
            handlers.openHistory()
            return .handled
        case .addBookmark:
            handlers.addBookmark()
            return .handled
        case .batchRename:
            handlers.batchRename()
            return .handled
        case .syncPanesLeftToRight:
            return handlers.syncPanesLeftToRight() ? .handledWithToast("Synced: Left → Right") : .handled
        case .syncPanesRightToLeft:
            return handlers.syncPanesRightToLeft() ? .handledWithToast("Synced: Right → Left") : .handled
        case .togglePin:
            return .handledWithToast(handlers.togglePin())
        case .launchClaude, .launchCodex, .toggleTerminalPanel:
            handlers.terminalAction(action)
            return .handled
        default:
            return .unhandled
        }
    }
}
