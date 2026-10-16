//
//  ScreenTourUITests.swift
//  SpecMatrixUITests
//

import XCTest

/// Visits every tab and attaches screenshots, for visual review of each appearance and text size.
/// The appearance and text size come from the simulator settings in effect when the test runs.
final class ScreenTourUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testScreenTour() throws {
        let app = XCUIApplication()
        app.launch()

        for tab in ["Specs", "Network", "Display", "Camera", "Settings"] {
            let button = app.tabBars.buttons[tab]
            XCTAssertTrue(button.waitForExistence(timeout: 10), "Missing tab \(tab)")
            button.tap()
            attach(app, "\(tab) top")
            app.swipeUp()
            attach(app, "\(tab) scrolled")
            app.swipeUp()
            app.swipeUp()
            attach(app, "\(tab) bottom")
        }
    }

    @MainActor
    private func attach(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
