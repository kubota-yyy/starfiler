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

    // MARK: - Single Key Binding

    func testSingleKeyBinding() {
        var interpreter = makeInterpreter(bindings: baseBindings)
        let event = KeyEvent(key: "j")
        let result = interpreter.interpret(event)
        XCTAssertEqual(result, .action(.cursorDown))
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
}
