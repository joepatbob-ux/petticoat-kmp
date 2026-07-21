import XCTest

final class PetticoatUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    /// Splash → Login → Dashboard → Device detail happy path.
    @MainActor
    func testLoginToDeviceFlow() {
        let app = XCUIApplication()
        app.launch()

        // The splash auto-advances to Login; wait for the Login button.
        let loginButton = app.buttons["Login"]
        XCTAssertTrue(loginButton.waitForExistence(timeout: 10),
                      "Login button should appear after the splash screen")
        loginButton.tap()

        // Dashboard shows the device row labeled with the device name ("Home").
        let deviceRow = app.buttons["Home"].firstMatch
        XCTAssertTrue(deviceRow.waitForExistence(timeout: 5),
                      "The dashboard device row should appear after logging in")
        deviceRow.tap()

        // The device detail screen has a Control tab in the bottom tab bar.
        let controlTab = app.buttons["Control"].firstMatch
        XCTAssertTrue(controlTab.waitForExistence(timeout: 5),
                      "The device detail screen's Control tab should appear")
    }
}
