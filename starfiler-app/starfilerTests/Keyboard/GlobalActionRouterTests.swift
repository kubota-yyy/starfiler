import XCTest
@testable import Starfiler

final class GlobalActionRouterTests: XCTestCase {
    func testNonGlobalActionReturnsUnhandled() {
        let router = GlobalActionRouter()
        let recorder = Recorder()

        let result = router.route(.cursorDown, handlers: recorder.handlers)

        XCTAssertEqual(result, .unhandled)
        XCTAssertEqual(recorder.invocations.count, 0)
    }

    func testEveryConfiguredGlobalActionIsHandled() {
        let router = GlobalActionRouter()

        for action in globalActions {
            let recorder = Recorder()
            let result = router.route(action, handlers: recorder.handlers)
            XCTAssertNotEqual(result, .unhandled, "Expected handled action for \(action)")
            XCTAssertEqual(recorder.invocations.count, 1, "Expected single invocation for \(action)")
        }
    }

    func testToastActionsReturnExpectedMessages() {
        let router = GlobalActionRouter()

        do {
            let recorder = Recorder()
            recorder.matchOtherPaneDirectoryResult = true
            let result = router.route(.matchOtherPaneDirectory, handlers: recorder.handlers)
            XCTAssertEqual(result, .handledWithToast("Other pane set to current folder"))
        }

        do {
            let recorder = Recorder()
            recorder.goToOtherPaneDirectoryResult = true
            let result = router.route(.goToOtherPaneDirectory, handlers: recorder.handlers)
            XCTAssertEqual(result, .handledWithToast("Moved to other pane folder"))
        }

        do {
            let recorder = Recorder()
            recorder.syncLeftToRightResult = true
            let result = router.route(.syncPanesLeftToRight, handlers: recorder.handlers)
            XCTAssertEqual(result, .handledWithToast("Synced: Left → Right"))
        }

        do {
            let recorder = Recorder()
            recorder.syncRightToLeftResult = true
            let result = router.route(.syncPanesRightToLeft, handlers: recorder.handlers)
            XCTAssertEqual(result, .handledWithToast("Synced: Right → Left"))
        }

        do {
            let recorder = Recorder()
            recorder.togglePinToast = "Pinned"
            let result = router.route(.togglePin, handlers: recorder.handlers)
            XCTAssertEqual(result, .handledWithToast("Pinned"))
        }
    }

    private var globalActions: [KeyAction] {
        [
            .copy,
            .copyToClipboard,
            .paste,
            .pasteFromClipboard,
            .move,
            .cutToClipboard,
            .delete,
            .rename,
            .createDirectory,
            .undo,
            .togglePreview,
            .toggleSidebar,
            .toggleLeftPane,
            .toggleRightPane,
            .toggleSinglePane,
            .equalizePaneWidths,
            .matchOtherPaneDirectory,
            .goToOtherPaneDirectory,
            .openBookmarkSearch,
            .openHistory,
            .addBookmark,
            .batchRename,
            .syncPanesLeftToRight,
            .syncPanesRightToLeft,
            .togglePin,
            .launchClaude,
            .launchCodex,
            .toggleTerminalPanel,
        ]
    }
}

private final class Recorder {
    var invocations: [String] = []
    var matchOtherPaneDirectoryResult = false
    var goToOtherPaneDirectoryResult = false
    var syncLeftToRightResult = false
    var syncRightToLeftResult = false
    var togglePinToast = "Pinned"

    var handlers: GlobalActionRouter.Handlers {
        GlobalActionRouter.Handlers(
            copy: { self.invocations.append("copy") },
            copyToClipboard: { self.invocations.append("copyToClipboard") },
            paste: { self.invocations.append("paste") },
            pasteFromClipboard: { self.invocations.append("pasteFromClipboard") },
            move: { self.invocations.append("move") },
            cutToClipboard: { self.invocations.append("cutToClipboard") },
            delete: { self.invocations.append("delete") },
            rename: { self.invocations.append("rename") },
            createDirectory: { self.invocations.append("createDirectory") },
            undo: { self.invocations.append("undo") },
            togglePreview: { self.invocations.append("togglePreview") },
            toggleSidebar: { self.invocations.append("toggleSidebar") },
            toggleLeftPane: { self.invocations.append("toggleLeftPane") },
            toggleRightPane: { self.invocations.append("toggleRightPane") },
            toggleSinglePane: { self.invocations.append("toggleSinglePane") },
            equalizePaneWidths: { self.invocations.append("equalizePaneWidths") },
            matchOtherPaneDirectory: {
                self.invocations.append("matchOtherPaneDirectory")
                return self.matchOtherPaneDirectoryResult
            },
            goToOtherPaneDirectory: {
                self.invocations.append("goToOtherPaneDirectory")
                return self.goToOtherPaneDirectoryResult
            },
            openBookmarkSearch: { self.invocations.append("openBookmarkSearch") },
            openHistory: { self.invocations.append("openHistory") },
            addBookmark: { self.invocations.append("addBookmark") },
            batchRename: { self.invocations.append("batchRename") },
            syncPanesLeftToRight: {
                self.invocations.append("syncPanesLeftToRight")
                return self.syncLeftToRightResult
            },
            syncPanesRightToLeft: {
                self.invocations.append("syncPanesRightToLeft")
                return self.syncRightToLeftResult
            },
            togglePin: {
                self.invocations.append("togglePin")
                return self.togglePinToast
            },
            terminalAction: { action in
                self.invocations.append("terminal:\(action.rawValue)")
            }
        )
    }
}
