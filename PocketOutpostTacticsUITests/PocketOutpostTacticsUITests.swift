import XCTest

/// Critical-path smoke test: a brand-new player can go from the title screen into the first
/// battle, select their Guardian and end a turn.
final class PocketOutpostTacticsUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testFirstBattleFlow() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()

        let play = app.buttons["playButton"]
        XCTAssertTrue(play.waitForExistence(timeout: 10))
        play.tap()

        let toBattle = app.buttons["campaignButton"]
        XCTAssertTrue(toBattle.waitForExistence(timeout: 5))
        toBattle.tap()

        let guardian = app.buttons["squad-guardian"]
        XCTAssertTrue(guardian.waitForExistence(timeout: 8))
        guardian.tap()

        XCTAssertTrue(app.buttons["abilityButton"].waitForExistence(timeout: 5), "Selecting a unit shows its orders")
        app.buttons["waitButton"].tap()

        // Waiting with the only unit ends the turn automatically; the enemy acts, then control returns.
        let endTurn = app.buttons["endTurnButton"]
        XCTAssertTrue(endTurn.waitForExistence(timeout: 5))
        let back = NSPredicate(format: "isEnabled == true")
        expectation(for: back, evaluatedWith: endTurn)
        waitForExpectations(timeout: 20)
    }

    func testOutpostScreensOpen() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()
        app.buttons["playButton"].tap()
        XCTAssertTrue(app.buttons["squadButton"].waitForExistence(timeout: 5))
        app.buttons["squadButton"].tap()
        XCTAssertTrue(app.buttons["backButton"].waitForExistence(timeout: 5))
        app.buttons["backButton"].tap()
        app.buttons["building-watchtower"].tap()
        XCTAssertTrue(app.buttons["upgradeButton"].waitForExistence(timeout: 5))
    }
}
