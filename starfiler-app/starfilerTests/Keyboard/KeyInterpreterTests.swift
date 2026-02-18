import XCTest
@testable import Starfiler

final class KeyInterpreterTests: XCTestCase {

    // MARK: - Helpers

    /// Creates a KeybindingManager with a specific config (no file-based loading).
    private func makeManager(bindings: [String: [String: String]]) -> KeybindingManager {
        // Write the config to a temp file, then load it
        let config = KeybindingsConfig(bindings: bindings)
        let data = try! JSONEncoder().encode(config)
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("json")
        try! data.write(to: tempURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        // Create an empty bundle stand-in. Since Bundle.main won't have
        // DefaultKeybindings.json in test context, we pass the user config
        // as default config by loading from the temp file.
        return KeybindingManager(
            bundle: Bundle(for: type(of: self)),
            userConfigURL: tempURL
        )
    }

    private func makeInterpreter(
        bindings: [String: [String: String]],
        mode: VimMode = .normal,
        timeout: TimeInterval = 0.3
    ) -> KeyInterpreter {
        let manager = makeManager(bindings: bindings)
        return KeyInterpreter(keybindingManager: manager, mode: mode, timeout: timeout)
    }

    private let baseBindings: [String: [String: String]] = [
        "normal": [
            "j": "cursorDown",
            "k": "cursorUp",
            "g g": "goToTop",
            "g h": "goHome",
            "d d": "delete",
            "/": "enterFilterMode",
            "G": "goToBottom",
            "Tab": "switchPane",
            "Ctrl-u": "pageUp",
        ],
        "visual": [
            "j": "cursorDown",
            "Escape": "exitVisualMode",
        ],
        "filter": [
            "Escape": "clearFilter",
        ],
    ]

    private func makeBookmarkJumpInterpreter(config: BookmarksConfig) -> BookmarkJumpInterpreter {
        BookmarkJumpInterpreter(bookmarksConfig: config)
    }

    // MARK: - Single Key Binding

    func testSingleKeyBinding() {
        var interpreter = makeInterpreter(bindings: baseBindings)
        let event = KeyEvent(key: "j")
        let result = interpreter.interpret(event)
        XCTAssertEqual(result, .action(.cursorDown))
    }

    // MARK: - Merge / Unbind

    func testMergeRemovesBindingWhenMarkedUnbound() {
        let defaults = KeybindingsConfig(bindings: [
            "normal": [
                "j": "cursorDown",
                "k": "cursorUp",
            ],
        ])
        let user = KeybindingsConfig(bindings: [
            "normal": [
                "j": KeybindingsConfig.unboundActionName,
            ],
        ])

        let merged = KeybindingManager.merge(defaultConfig: defaults, userConfig: user)

        XCTAssertNil(merged.bindings["normal"]?["j"])
        XCTAssertEqual(merged.bindings["normal"]?["k"], "cursorUp")
    }

    func testMergeCanOverrideOneBindingAndUnbindAnother() {
        let defaults = KeybindingsConfig(bindings: [
            "normal": [
                "j": "cursorDown",
                "k": "cursorUp",
            ],
        ])
        let user = KeybindingsConfig(bindings: [
            "normal": [
                "j": "goToTop",
                "k": KeybindingsConfig.unboundActionName,
            ],
        ])

        let merged = KeybindingManager.merge(defaultConfig: defaults, userConfig: user)

        XCTAssertEqual(merged.bindings["normal"]?["j"], "goToTop")
        XCTAssertNil(merged.bindings["normal"]?["k"])
    }

    func testUnmappedKeyReturnsUnhandled() {
        var interpreter = makeInterpreter(bindings: baseBindings)
        let event = KeyEvent(key: "z")
        let result = interpreter.interpret(event)
        XCTAssertEqual(result, .unhandled)
    }

    // MARK: - Multi-Key Sequence

    func testMultiKeySequencePending() {
        var interpreter = makeInterpreter(bindings: baseBindings)
        let event = KeyEvent(key: "g")
        let result = interpreter.interpret(event)
        XCTAssertEqual(result, .pending)
    }

    func testMultiKeySequenceComplete() {
        var interpreter = makeInterpreter(bindings: baseBindings)
        let now = Date()
        _ = interpreter.interpret(KeyEvent(key: "g"), now: now)
        let result = interpreter.interpret(KeyEvent(key: "g"), now: now.addingTimeInterval(0.1))
        XCTAssertEqual(result, .action(.goToTop))
    }

    func testMultiKeySequenceTimeout() {
        var interpreter = makeInterpreter(bindings: baseBindings, timeout: 0.3)
        let now = Date()
        let pending = interpreter.interpret(KeyEvent(key: "g"), now: now)
        XCTAssertEqual(pending, .pending)

        // Wait longer than timeout, then press "g" again
        let result = interpreter.interpret(KeyEvent(key: "g"), now: now.addingTimeInterval(0.5))
        // The pending sequence expired, so "g" alone is evaluated as a new pending
        XCTAssertEqual(result, .pending)
    }

    func testMultiKeySequenceDifferentSecondKey() {
        var interpreter = makeInterpreter(bindings: baseBindings)
        let now = Date()
        _ = interpreter.interpret(KeyEvent(key: "g"), now: now)
        let result = interpreter.interpret(KeyEvent(key: "h"), now: now.addingTimeInterval(0.1))
        XCTAssertEqual(result, .action(.goHome))
    }

    // MARK: - Mode Switching

    func testModeSwitch() {
        var interpreter = makeInterpreter(bindings: baseBindings, mode: .visual)
        XCTAssertEqual(interpreter.mode, .visual)

        let result = interpreter.interpret(KeyEvent(key: "j"))
        XCTAssertEqual(result, .action(.cursorDown))

        interpreter.setMode(.normal)
        XCTAssertEqual(interpreter.mode, .normal)
    }

    func testVisualModeEscape() {
        var interpreter = makeInterpreter(bindings: baseBindings, mode: .visual)
        let result = interpreter.interpret(KeyEvent(key: "Escape"))
        XCTAssertEqual(result, .action(.exitVisualMode))
    }

    func testFilterModeEscape() {
        var interpreter = makeInterpreter(bindings: baseBindings, mode: .filter)
        let result = interpreter.interpret(KeyEvent(key: "Escape"))
        XCTAssertEqual(result, .action(.clearFilter))
    }

    // MARK: - Command Modifier

    func testCommandModifierReturnsUnhandled() {
        var interpreter = makeInterpreter(bindings: baseBindings)
        let event = KeyEvent(key: "j", modifiers: .command)
        let result = interpreter.interpret(event)
        XCTAssertEqual(result, .unhandled)
    }

    func testCommandModifierReturnsActionWhenBindingExists() {
        let bindings: [String: [String: String]] = [
            "normal": [
                "Cmd-Up": "goForward",
                "Cmd-Down": "goBack",
                "Cmd-Left": "goToParent",
                "Cmd-Right": "cursorRight",
            ],
        ]
        var interpreter = makeInterpreter(bindings: bindings)

        let forward = interpreter.interpret(KeyEvent(key: "ArrowUp", modifiers: .command))
        XCTAssertEqual(forward, .action(.goForward))

        let backward = interpreter.interpret(KeyEvent(key: "ArrowDown", modifiers: .command))
        XCTAssertEqual(backward, .action(.goBack))
    }

    // MARK: - Special Keys

    func testTabKey() {
        var interpreter = makeInterpreter(bindings: baseBindings)
        let event = KeyEvent(key: "Tab")
        let result = interpreter.interpret(event)
        XCTAssertEqual(result, .action(.switchPane))
    }

    func testControlModifierKey() {
        var interpreter = makeInterpreter(bindings: baseBindings)
        let event = KeyEvent(key: "u", modifiers: .control)
        let result = interpreter.interpret(event)
        XCTAssertEqual(result, .action(.pageUp))
    }

    // MARK: - Shift Interpreted via Uppercase

    func testShiftKeyUppercase() {
        var interpreter = makeInterpreter(bindings: baseBindings)
        // "G" in the config triggers goToBottom. KeyEvent normalizes "G" to "g" with shift modifier
        // Let's check what KeybindingManager.parseToken does with "G":
        // It sees uppercase, inserts .shift, key becomes "g"
        let event = KeyEvent(key: "g", modifiers: .shift)
        let result = interpreter.interpret(event)
        XCTAssertEqual(result, .action(.goToBottom))
    }

    // MARK: - Type Select Guard

    func testHasExactBindingReturnsTrueForSingleKeyAction() {
        let bindings: [String: [String: String]] = [
            "normal": [
                "b": "openBookmarkSearch",
                "g g": "goToTop",
            ]
        ]
        let interpreter = makeInterpreter(bindings: bindings)
        XCTAssertTrue(interpreter.hasExactBinding(for: KeyEvent(key: "b")))
    }

    func testHasExactBindingReturnsFalseForPrefixOnlyKey() {
        let bindings: [String: [String: String]] = [
            "normal": [
                "g g": "goToTop"
            ]
        ]
        let interpreter = makeInterpreter(bindings: bindings)
        XCTAssertFalse(interpreter.hasExactBinding(for: KeyEvent(key: "g")))
    }

    func testHasExactBindingReturnsFalseForUnmappedKey() {
        var interpreter = makeInterpreter(bindings: baseBindings)
        _ = interpreter.interpret(KeyEvent(key: "g"))
        XCTAssertFalse(interpreter.hasExactBinding(for: KeyEvent(key: "z")))
    }

    // MARK: - Shortcut Guide Candidates

    func testCandidatesForInitialModifiersFiltersByModifier() {
        let interpreter = makeInterpreter(bindings: baseBindings)

        let candidates = interpreter.candidatesForInitialModifiers(.control)
        let actions = Set(candidates.map(\.action))

        XCTAssertTrue(actions.contains(.pageUp))
        XCTAssertFalse(actions.contains(.switchPane))
    }

    func testCandidatesForPendingSequenceNarrowByPrefix() {
        var interpreter = makeInterpreter(bindings: baseBindings)

        _ = interpreter.interpret(KeyEvent(key: "g"))
        let candidates = interpreter.candidatesForPendingSequence()
        let actions = Set(candidates.map(\.action))

        XCTAssertEqual(actions, Set([.goToTop, .goHome]))
    }

    // MARK: - Clear Pending Sequence

    func testClearPendingSequence() {
        var interpreter = makeInterpreter(bindings: baseBindings)
        let now = Date()
        let pending = interpreter.interpret(KeyEvent(key: "g"), now: now)
        XCTAssertEqual(pending, .pending)

        interpreter.clearPendingSequence()
        // "g" alone should now be treated as a new input, going to pending again
        let result = interpreter.interpret(KeyEvent(key: "g"), now: now.addingTimeInterval(0.1))
        XCTAssertEqual(result, .pending)
    }

    // MARK: - Bookmark Jump

    func testBookmarkJumpShowsEnterCandidateWhenPrefixHasExactAndDescendant() {
        let config = BookmarksConfig(groups: [
            BookmarkGroup(
                name: "RWD",
                entries: [
                    BookmarkEntry(displayName: "docs", path: "/Users/workspace/RWD/rwd/docs", shortcutKey: "d"),
                    BookmarkEntry(displayName: "unity", path: "/Users/workspace/RWD/rwd/docs/unity", shortcutKey: "d u"),
                ],
                shortcutKey: "r",
                isDefault: false
            )
        ])
        var interpreter = makeBookmarkJumpInterpreter(config: config)

        _ = interpreter.interpret(KeyEvent(key: "'"))
        _ = interpreter.interpret(KeyEvent(key: "r"))
        let result = interpreter.interpret(KeyEvent(key: "d"))

        guard case .pending(let hint) = result else {
            return XCTFail("Expected pending result")
        }
        XCTAssertTrue(hint.candidates.contains(where: { $0.key == "Enter" && $0.label == "docs" }))
        XCTAssertTrue(hint.candidates.contains(where: { $0.key == "u" && $0.label == "unity" }))
    }

    func testBookmarkJumpEnterConfirmsCurrentPrefix() {
        let config = BookmarksConfig(groups: [
            BookmarkGroup(
                name: "RWD",
                entries: [
                    BookmarkEntry(displayName: "docs", path: "/Users/workspace/RWD/rwd/docs", shortcutKey: "d"),
                    BookmarkEntry(displayName: "unity", path: "/Users/workspace/RWD/rwd/docs/unity", shortcutKey: "d u"),
                ],
                shortcutKey: "r",
                isDefault: false
            )
        ])
        var interpreter = makeBookmarkJumpInterpreter(config: config)

        _ = interpreter.interpret(KeyEvent(key: "'"))
        _ = interpreter.interpret(KeyEvent(key: "r"))
        _ = interpreter.interpret(KeyEvent(key: "d"))
        let result = interpreter.interpret(KeyEvent(key: "Return"))

        XCTAssertEqual(result, .jumpTo(path: "/Users/workspace/RWD/rwd/docs"))
    }

    func testBookmarkJumpCanContinueToDeeperSequence() {
        let config = BookmarksConfig(groups: [
            BookmarkGroup(
                name: "RWD",
                entries: [
                    BookmarkEntry(displayName: "docs", path: "/Users/workspace/RWD/rwd/docs", shortcutKey: "d"),
                    BookmarkEntry(displayName: "unity", path: "/Users/workspace/RWD/rwd/docs/unity", shortcutKey: "d u"),
                ],
                shortcutKey: "r",
                isDefault: false
            )
        ])
        var interpreter = makeBookmarkJumpInterpreter(config: config)

        _ = interpreter.interpret(KeyEvent(key: "'"))
        _ = interpreter.interpret(KeyEvent(key: "r"))
        _ = interpreter.interpret(KeyEvent(key: "d"))
        let result = interpreter.interpret(KeyEvent(key: "u"))

        XCTAssertEqual(result, .jumpTo(path: "/Users/workspace/RWD/rwd/docs/unity"))
    }
}
