import XCTest

final class DragDropSmokeUITests: BaseUITestCase {
    func testPaneToPaneDragDropSmoke() {
        let sourceTable = focusFileTable()
        let tables = app.tables.matching(identifier: "filePane.tableView")
        let targetTable: XCUIElement

        if tables.count >= 2 {
            targetTable = tables.element(boundBy: 1)
        } else {
            let rightPane = app.otherElements["mainSplit.rightPane"].firstMatch
            let rightPaneTable = rightPane.tables["filePane.tableView"].firstMatch
            targetTable = rightPaneTable.exists ? rightPaneTable : sourceTable
        }

        XCTAssertTrue(sourceTable.waitForExistence(timeout: 5))
        XCTAssertTrue(targetTable.waitForExistence(timeout: 5))

        let sourceCell = sourceTable.cells.firstMatch
        guard sourceCell.exists else {
            XCTFail("Expected source cell for drag")
            return
        }

        sourceCell.press(forDuration: 1.0, thenDragTo: targetTable)

        XCTAssertTrue(targetTable.exists)
        XCTAssertTrue(app.windows.firstMatch.exists)
    }
}
