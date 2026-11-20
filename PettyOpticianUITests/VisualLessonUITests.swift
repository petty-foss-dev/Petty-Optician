import XCTest

@MainActor
final class VisualLessonUITests: XCTestCase {
    private let app = XCUIApplication()

    private func open(_ id: String, file: StaticString = #filePath, line: UInt = #line) {
        let button = app.buttons[id].firstMatch
        for _ in 0..<18 {
            if button.exists && button.isHittable {
                button.tap()
                return
            }
            app.swipeUp()
        }
        XCTFail("Could not reach \(id)", file: file, line: line)
    }

    func testCompareMonocularCentersThenPracticeOnANewOrder() {
        continueAfterFailure = false
        app.launchArguments = ["--ui-testing"]
        app.launch()
        open("exam.abo")
        open("textbook.chapter.textbook.abo.dispensing")
        open("textbook.lesson.abo.dispensing#5")
        open("visual.choice.0")
        let feedback = app.descendants(matching: .any).matching(identifier: "visual.feedback").firstMatch
        XCTAssertTrue(feedback.waitForExistence(timeout: 4))
        XCTAssertTrue(feedback.label.contains("Compare again"))
        open("visual.choice.1")
        XCTAssertTrue(feedback.label.contains("Correct"))
        open("reader.practice")
        XCTAssertTrue(app.buttons["choice.0"].waitForExistence(timeout: 5))
    }

    func testComparePushUpFindingsThenOpenTheTrainer() {
        continueAfterFailure = false
        app.launchArguments = ["--ui-testing"]
        app.launch()
        open("exam.ncle")
        open("textbook.chapter.textbook.ncle.fitting")
        open("textbook.lesson.ncle.fitting#2")
        open("After blink")
        open("Push-up")
        let lens = app.descendants(matching: .any).matching(identifier: "visual.specimen.0").firstMatch
        XCTAssertTrue(lens.label.contains("resists"))
        open("visual.choice.0")
        let feedback = app.descendants(matching: .any).matching(identifier: "visual.feedback").firstMatch
        XCTAssertTrue(feedback.waitForExistence(timeout: 4))
        XCTAssertTrue(feedback.label.contains("Correct"))
        open("reader.trainer")
        XCTAssertTrue(app.buttons["softlens.pushup"].waitForExistence(timeout: 5))
    }
}
