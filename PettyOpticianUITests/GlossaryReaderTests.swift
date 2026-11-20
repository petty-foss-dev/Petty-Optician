import XCTest

@MainActor
final class GlossaryReaderTests: XCTestCase {
    func testOpenDefinitionAndReturnToThePassage() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        app.buttons["exam.abo"].tap()
        let chapter = app.buttons["textbook.chapter.textbook.abo.anatomy"]
        for _ in 0..<6 where !chapter.isHittable { app.swipeUp() }
        chapter.tap()
        let term = app.links.matching(NSPredicate(format: "label =[c] %@", "cornea")).firstMatch
        XCTAssertTrue(term.waitForExistence(timeout: 5))
        for _ in 0..<4 where !term.isHittable { app.swipeUp() }
        let position = term.frame.midY
        term.tap()
        let title = app.staticTexts["definition.term"]
        XCTAssertTrue(title.waitForExistence(timeout: 3))
        XCTAssertEqual(title.label, "Cornea")
        app.buttons["definition.done"].tap()
        XCTAssertTrue(term.isHittable)
        XCTAssertEqual(term.frame.midY, position, accuracy: 4)
    }
}
