import XCTest

@MainActor
final class MockResumeUITests: XCTestCase {
    func testMockSurvivesProcessTerminationAndExplicitExit() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        func openPractice() {
            app.buttons["Practice"].firstMatch.tap()
            app.buttons["exam.abo"].tap()
        }
        func tapWhenReady(_ button: XCUIElement) {
            let hittable = NSPredicate(format: "exists == true AND hittable == true")
            let ready = XCTNSPredicateExpectation(predicate: hittable, object: button)
            XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 8), .completed)
            button.tap()
        }
        func discard() {
            app.buttons["Close quiz"].tap()
            tapWhenReady(app.buttons["Discard"])
        }
        openPractice()
        let resume = app.buttons["practice.resumeMock"]
        if resume.exists {
            tapWhenReady(resume)
            if app.buttons["Close quiz"].exists { discard() } else { app.buttons["Done"].tap() }
        }
        tapWhenReady(app.buttons["quick.mock-exam"])
        app.buttons["quiz.next"].tap()
        let stem = app.staticTexts["quiz.stem"].label
        let choice = app.buttons["choice.0"]
        choice.tap()
        app.buttons["Flag question"].tap()
        app.terminate()
        app.launch()
        openPractice()
        XCTAssertTrue(resume.waitForExistence(timeout: 5))
        tapWhenReady(resume)
        XCTAssertTrue(app.staticTexts["2 of 125"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["quiz.stem"].label, stem)
        XCTAssertTrue(choice.isSelected)
        XCTAssertEqual(app.buttons["Flag question"].value as? String, "Flagged")
        app.buttons["Close quiz"].tap()
        tapWhenReady(app.buttons["Save & Leave"])
        tapWhenReady(resume)
        XCTAssertEqual(app.staticTexts["quiz.stem"].label, stem)
        discard()
        XCTAssertTrue(app.buttons["quick.mock-exam"].waitForExistence(timeout: 5))
    }
}
