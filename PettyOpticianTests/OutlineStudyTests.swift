import XCTest
@testable import PettyOptician

final class OutlineStudyTests: XCTestCase {
    func testEveryBundledObjectiveHasReadingAnExampleAndIndependentPractice() throws {
        let library = ContentLibrary.shared
        let guide = try OutlineStudy.load(from: Bundle(for: QuizRecord.self), library: library, textbook: .shared)
        for exam in library.exams {
            for domain in try XCTUnwrap(exam.officialOutline) {
                for name in try XCTUnwrap(domain.subtopics) {
                    let topic = try XCTUnwrap(guide.topic(name, exam: exam.id), name)
                    XCTAssertFalse(topic.lessons.isEmpty, name)
                    XCTAssertFalse(topic.checks.isEmpty, name)
                    XCTAssertEqual(topic.example.exam, exam.id, name)
                    XCTAssertTrue(topic.checks.allSatisfy { $0.id != topic.example.id && $0.exam == exam.id }, name)
                }
            }
        }
    }

    func testOccupationalLensObjectiveCanLeadToTheProductsChapter() throws {
        let topic = try XCTUnwrap(OutlineStudy.shared.topic("Lens options for occupations and lifestyle", exam: .abo))
        XCTAssertTrue(topic.lessons.contains { $0.ref.domain == "abo.products" })
        XCTAssertEqual(topic.example.id, "case-abo-063")
        XCTAssertTrue(topic.checks.contains { $0.id == "abo-len-046" })
    }
}
