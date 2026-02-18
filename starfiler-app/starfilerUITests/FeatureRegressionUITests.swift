import XCTest

final class FeatureRegressionUITests: BaseUITestCase {
    func testFeatureFlowSmoke() {
        let table = focusFileTable()
        XCTAssertTrue(table.exists)

        // Bookmark search panel open/close
        app.typeKey("7", modifierFlags: [.control])
        app.typeKey(XCUIKeyboardKey.escape.rawValue, modifierFlags: [])

        // Spotlight mode
        app.typeKey("f", modifierFlags: [.control])
        app.typeText("photo")
        app.typeKey(XCUIKeyboardKey.escape.rawValue, modifierFlags: [])

        // Media/files mode toggle
        app.typeKey("0", modifierFlags: [.control])
        app.typeKey("0", modifierFlags: [.control])

        // Sync and pin toggles
        app.typeKey("l", modifierFlags: [.control, .shift])
        app.typeKey("h", modifierFlags: [.control, .shift])
        app.typeKey("9", modifierFlags: [.control])

        XCTAssertTrue(app.windows.firstMatch.exists)
    }
}
