import XCTest

final class ShortcutRegressionUITests: BaseUITestCase {
    func testShortcutSmokeAcrossModes() {
        _ = focusFileTable()

        // normal mode navigation
        app.typeKey("j", modifierFlags: [.control])
        app.typeKey("k", modifierFlags: [.control])
        app.typeKey("u", modifierFlags: [.control])
        app.typeKey("d", modifierFlags: [.control])

        // visual mode enter/exit
        app.typeKey("v", modifierFlags: [.control])
        app.typeKey(XCUIKeyboardKey.escape.rawValue, modifierFlags: [.control])

        // filter mode enter/clear
        app.typeKey("/", modifierFlags: [])
        app.typeText("readme")
        app.typeKey(XCUIKeyboardKey.escape.rawValue, modifierFlags: [])

        // pane/layout toggles
        app.typeKey("8", modifierFlags: [.control])
        app.typeKey("8", modifierFlags: [.control])
        app.typeKey(XCUIKeyboardKey.space.rawValue, modifierFlags: [])
        app.typeKey(XCUIKeyboardKey.space.rawValue, modifierFlags: [])

        XCTAssertTrue(app.windows.firstMatch.exists)
    }
}
