import XCTest

@MainActor
final class StudyPathTests: XCTestCase {
    private let app = XCUIApplication()

    private func open(_ id: String, file: StaticString = #filePath, line: UInt = #line) {
        let button = app.buttons[id].firstMatch
        for _ in 0..<14 {
            if button.exists && button.isHittable {
                button.tap()
                return
            }
            app.swipeUp()
        }
        XCTFail("Cannot open \(id)", file: file, line: line)
    }

    private func launch() {
        continueAfterFailure = false
        app.launchArguments = ["--ui-testing"]
        app.launch()
    }

    func testPrismCheckpointReturnsToItsWorkedOrder() {
        launch()
        open("exam.abo")
        open("textbook.chapter.textbook.abo.optics")
        open("textbook.lesson.abo.optics#6")
        XCTAssertTrue(app.staticTexts.matching(identifier: "reader.heading").allElementsBoundByIndex.contains { $0.isHittable && $0.label.contains("Calculate prism") })
        open("reader.practice")
        open("choice.0")
        open("question.lesson")
        XCTAssertTrue(app.staticTexts["reader.heading"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts.matching(identifier: "reader.heading").allElementsBoundByIndex.contains { $0.isHittable && $0.label.contains("Calculate prism") })
    }

    func testOutlineOpensWorkedExampleAndIndependentPractice() {
        launch()
        open("exam.abo")
        open("textbook.objectives")
        open("outline.domain.Ophthalmic Optics")
        open("outline.topic.Prismatic effects")
        XCTAssertTrue(app.buttons["outline.lesson.abo.optics#2"].exists)
        open("outline.practice")
        XCTAssertTrue(app.buttons["choice.0"].waitForExistence(timeout: 5))
    }

    func testWearerCanBeFollowedFromDispensingToFollowUp() {
        launch()
        open("exam.ncle")
        open("textbook.chapter.textbook.ncle.dispensing")
        open("textbook.lesson.ncle.dispensing#2")
        open("reader.relatedLesson")
        XCTAssertTrue(app.staticTexts["reader.heading"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["reader.heading"].label.contains("Red-eye triage"))
        open("reader.practice")
        XCTAssertTrue(app.buttons["choice.0"].waitForExistence(timeout: 5))
    }
}
