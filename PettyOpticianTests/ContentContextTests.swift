import XCTest
@testable import PettyOptician

/// Every question stem and flashcard front is read cold — shuffled, in a widget, read aloud — so it must name what it's about.
final class ContentContextTests: XCTestCase {
    private let library = ContentLibrary.shared

    /// Instrument parts that are meaningless unless the instrument is named in the same text.
    private let instrumentParts: [(parts: [String], instruments: [String])] = [
        (["the target", "the reticle", "the marking device", "the eyepiece", "the power wheel", "the axis wheel", "the lens stop", "the lens table"],
         ["lensometer", "lensmeter", "focimeter", "keratomet", "trainer"]),
        (["the mires"], ["keratomet", "lensometer", "lensmeter", "topograph", "placido", "ophthalmometer"]),
        (["the drum", "the dial"], ["keratomet", "lensometer", "lensmeter", "radiuscope", "lens clock", "pupillometer", "distometer", "colmascope"]),
        (["the slit beam", "the beam width", "the parallelepiped", "the optic section"], ["slit lamp", "slit-lamp", "biomicroscop"]),
    ]

    private let danglingPhrases = [
        "as shown", "shown above", "shown below", "the above", "in the image", "this image", "pictured", "the photo", "the diagram", "the figure",
        "the previous question", "the last question", "the same patient", "this step", "in step ",
    ]

    private func problems(in text: String) -> [String] {
        let lower = text.lowercased()
        var found = danglingPhrases.filter { lower.contains($0) }
        for rule in instrumentParts where !rule.instruments.contains(where: lower.contains) {
            found += rule.parts.filter { lower.contains($0) }
        }
        return found
    }

    func testQuestionStemsNameWhatTheyAreAbout() {
        let offenders = library.questions.compactMap { q -> String? in
            let found = problems(in: q.stem)
            return found.isEmpty ? nil : "\(q.id): \(found.joined(separator: ", ")) — \(q.stem.prefix(90))"
        }
        XCTAssert(offenders.isEmpty, "Stems that depend on missing context:\n" + offenders.joined(separator: "\n"))
    }

    func testFlashcardFrontsNameWhatTheyAreAbout() {
        let offenders = library.flashcards.compactMap { card -> String? in
            let found = problems(in: card.front)
            return found.isEmpty ? nil : "\(card.id): \(found.joined(separator: ", ")) — \(card.front.prefix(90))"
        }
        XCTAssert(offenders.isEmpty, "Card fronts that depend on missing context:\n" + offenders.joined(separator: "\n"))
    }

    func testCardsMadeFromQuestionsShowTheChoicesAndAnswer() throws {
        let question = try XCTUnwrap(library.questions.first { $0.stem.lowercased().contains("which of the following") })
        let card = PersonalCard(question: question).flashcard
        for choice in question.choices { XCTAssertTrue(card.front.contains(choice), question.id) }
        XCTAssertTrue(card.back.contains(question.choices[question.answer]))
        XCTAssertTrue(card.back.hasPrefix("**\(["A", "B", "C", "D"][question.answer]). "))
    }
}
