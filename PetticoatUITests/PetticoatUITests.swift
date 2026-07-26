import XCTest

final class PetticoatUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    /// Launches the app and drives Splash → Login → Dashboard → Device detail,
    /// returning the running app parked on the device detail's Control tab.
    @MainActor
    @discardableResult
    private func launchToDeviceDetail() -> XCUIApplication {
        let app = XCUIApplication()
        app.launch()

        // The splash auto-advances to Login; wait for the Login button.
        let loginButton = app.buttons["Login"]
        XCTAssertTrue(loginButton.waitForExistence(timeout: 10),
                      "Login button should appear after the splash screen")
        loginButton.tap()

        // Dashboard shows the device card; its temperature button opens the detail
        // screen (accessibility label "Open <device name> controls").
        let deviceRow = app.buttons["Open Home controls"].firstMatch
        XCTAssertTrue(deviceRow.waitForExistence(timeout: 5),
                      "The dashboard device row should appear after logging in")
        deviceRow.tap()

        // The device detail screen has a Control tab in the bottom tab bar.
        let controlTab = app.buttons["Control"].firstMatch
        XCTAssertTrue(controlTab.waitForExistence(timeout: 5),
                      "The device detail screen's Control tab should appear")
        return app
    }

    /// Splash → Login → Dashboard → Device detail happy path.
    @MainActor
    func testLoginToDeviceFlow() {
        launchToDeviceDetail()
    }

    /// The Reminders tab shows the seeded service reminders and can open the add flow.
    @MainActor
    func testRemindersTabAddFlow() {
        let app = launchToDeviceDetail()

        app.buttons["Reminders"].firstMatch.tap()

        XCTAssertTrue(app.staticTexts["Upstairs Air Filter"].waitForExistence(timeout: 5),
                      "A seeded service reminder should appear on the Reminders tab")

        app.buttons["Add Reminder"].tap()
        XCTAssertTrue(app.navigationBars["New Reminder"].waitForExistence(timeout: 5),
                      "Tapping add should present the New Reminder editor")
    }
}
