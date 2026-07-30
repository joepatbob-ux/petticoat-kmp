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

        // Compact (iPhone): the dashboard shows a device card whose temperature
        // button ("Open <device name> controls") opens the detail screen.
        // Regular width (iPad): the split view already shows the selected
        // device's detail, so there's no dashboard row to tap.
        let deviceRow = app.buttons["Open Home controls"].firstMatch
        if deviceRow.waitForExistence(timeout: 4) {
            deviceRow.tap()
        }

        // Both layouts converge on the device detail's Control tab.
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

    /// The Control screen's sensor pill opens the Sensors screen with its sensors listed.
    @MainActor
    func testSensorsScreenFromControl() {
        let app = launchToDeviceDetail()

        app.buttons["sensorAveragePill"].tap()
        XCTAssertTrue(app.navigationBars["Sensors"].waitForExistence(timeout: 5),
                      "Tapping the sensor pill should open the Sensors screen")
        XCTAssertTrue(app.staticTexts["Thermostat"].waitForExistence(timeout: 3),
                      "The Sensors screen should list the thermostat sensor")
    }

    /// The Settings tab drills into Display Options.
    @MainActor
    func testSettingsTabDisplayOptions() {
        let app = launchToDeviceDetail()

        app.buttons["Settings"].firstMatch.tap()
        app.buttons["Display Options"].tap()
        XCTAssertTrue(app.switches["Continuous Backlight"].waitForExistence(timeout: 5),
                      "Display Options should show the Continuous Backlight toggle")
    }

    /// The Usage tab shows the runtime range control.
    @MainActor
    func testUsageTab() {
        let app = launchToDeviceDetail()

        app.buttons["Usage"].firstMatch.tap()
        XCTAssertTrue(app.buttons["Recent"].waitForExistence(timeout: 5),
                      "The Usage tab should show the range selector")
    }

    /// On iPad (regular width) the sidebar shows device cards with a selected-state
    /// indicator. The initially active device should be selected; tapping another
    /// device moves the selection to it.
    @MainActor
    func testSidebarSelectionState() throws {
        let app = XCUIApplication()
        // Landscape so the split view shows the sidebar column alongside the
        // detail; in portrait iPad collapses it and the cards aren't present.
        XCUIDevice.shared.orientation = .landscapeLeft
        app.launch()

        let loginButton = app.buttons["Login"]
        XCTAssertTrue(loginButton.waitForExistence(timeout: 10),
                      "Login button should appear after the splash screen")
        loginButton.tap()

        // The sidebar device cards are only present on regular-width (iPad)
        // layouts. Queried by identifier to disambiguate from the detail
        // toolbar's device-picker menu, which shares the device name.
        let homeCard = app.buttons["sidebar-device-Home"]
        guard homeCard.waitForExistence(timeout: 5) else {
            throw XCTSkip("Sidebar only visible on regular-width (iPad) layout")
        }

        // The first device should start selected.
        XCTAssertTrue(homeCard.isSelected,
                      "'Home' device card should be selected on launch")

        // Tapping the second device should move the selection.
        let upstairsCard = app.buttons["sidebar-device-Upstairs"]
        XCTAssertTrue(upstairsCard.waitForExistence(timeout: 3),
                      "'Upstairs' device card should appear in the sidebar")
        upstairsCard.tap()

        XCTAssertTrue(upstairsCard.isSelected,
                      "'Upstairs' should be selected after tapping it")
        XCTAssertFalse(homeCard.isSelected,
                       "'Home' should no longer be selected after switching devices")
    }
}
