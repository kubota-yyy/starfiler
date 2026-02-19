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

    func testSamePaneFileToFolderDragDropSmoke() {
        let table = focusFileTable()
        XCTAssertTrue(table.waitForExistence(timeout: 5))
        XCTAssertGreaterThanOrEqual(table.cells.count, 2, "Expected at least 2 cells for same-pane drag test")

        let sourceCell = table.cells.element(boundBy: 0)
        let targetCell = table.cells.element(boundBy: 1)
        XCTAssertTrue(sourceCell.waitForExistence(timeout: 5))
        XCTAssertTrue(targetCell.waitForExistence(timeout: 5))

        sourceCell.press(forDuration: 1.0, thenDragTo: targetCell)

        XCTAssertTrue(table.exists)
        XCTAssertTrue(app.windows.firstMatch.exists)
    }
}
