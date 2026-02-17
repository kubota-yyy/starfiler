import XCTest

class BaseUITestCase: XCTestCase {
    var app: XCUIApplication!
    private var workspaceRootURL: URL?

    override func setUpWithError() throws {
        try super.setUpWithError()
        continueAfterFailure = false

        let workspaceRootURL = try makeWorkspace()
        self.workspaceRootURL = workspaceRootURL

        let configRootURL = workspaceRootURL.appendingPathComponent("config", isDirectory: true)
        try FileManager.default.createDirectory(at: configRootURL, withIntermediateDirectories: true)

        app = XCUIApplication()
        app.launchArguments += [
            "--uitest",
            "--disable-animations",
            "--sandbox-root", workspaceRootURL.path,
            "--config-root", configRootURL.path,
        ]
        app.launchEnvironment["STARFILER_UI_TEST"] = "1"
        app.launch()

        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 10))
    }

    override func tearDownWithError() throws {
        app?.terminate()
        if let workspaceRootURL {
            try? FileManager.default.removeItem(at: workspaceRootURL.deletingLastPathComponent())
        }
        try super.tearDownWithError()
    }

    @discardableResult
    func focusFileTable() -> XCUIElement {
        let table = app.tables["filePane.tableView"].firstMatch
        if table.waitForExistence(timeout: 5) {
            table.click()
        }
        return table
    }

    private func makeWorkspace() throws -> URL {
        let fixtureSource = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // starfilerUITests
            .deletingLastPathComponent() // starfiler-app
            .appendingPathComponent("starfilerTests/Fixtures/Sandbox/v1", isDirectory: true)
            .standardizedFileURL

        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: fixtureSource.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw NSError(
                domain: "BaseUITestCase",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Fixture source not found: \(fixtureSource.path)"]
            )
        }

        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("starfiler-ui-workspace-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let workspaceRoot = tempDir.appendingPathComponent("workspace", isDirectory: true)
        try FileManager.default.copyItem(at: fixtureSource, to: workspaceRoot)
        return workspaceRoot
    }
}
