import SwiftData
import XCTest
@testable import PettyOptician

final class ExamDayTests: XCTestCase {
    private func question(_ id: String, domain: String = "abo.optics", topic: String = "Prism") -> Question {
        Question(id: id, exam: .abo, domain: domain, topic: topic, difficulty: 1, stem: id, choices: ["a", "b", "c", "d"], answer: 0, explanation: "", source: nil, diagram: nil)
    }

    private func history(seen: Int, correct: Int) -> QuestionHistory {
        QuestionHistory(seen: seen, correct: correct, lastWasCorrect: correct > 0, flagged: false, lastAnswered: .now)
    }

    func testCalculatorChainsAndFunctions() {
        var calc = CalculatorEngine()
        for key in ["1", "2", ".", "5"] { calc.digit(key) }
        calc.operation(.multiply)
        calc.digit("4")
        calc.operation(.subtract)
        XCTAssertEqual(calc.display, "50")
        calc.digit("8")
        calc.equals()
        XCTAssertEqual(calc.display, "42")

        calc.clear()
        calc.digit("3"); calc.digit("0")
        calc.apply(.sin)
        XCTAssertEqual(calc.value, 0.5, accuracy: 1e-9)
        calc.apply(.square)
        XCTAssertEqual(calc.value, 0.25, accuracy: 1e-9)

        calc.clear()
        calc.digit("1")
        calc.operation(.divide)
        calc.digit("0")
        calc.equals()
        XCTAssertEqual(calc.display, "Error")
    }

    func testCalculatorIgnoresSecondDecimalAndNegates() {
        var calc = CalculatorEngine()
        for key in ["2", ".", ".", "5"] { calc.digit(key) }
        XCTAssertEqual(calc.display, "2.5")
        calc.negate()
        XCTAssertEqual(calc.display, "-2.5")
    }

    func testTopicScoresAndWeakestOrdering() {
        let questions = [question("q1", topic: "Prism"), question("q2", topic: "Prism"), question("q3", topic: "Vertex"), question("q4", topic: "Abbe")]
        let history = [
            "q1": history(seen: 2, correct: 0),
            "q2": history(seen: 2, correct: 1),
            "q3": history(seen: 4, correct: 4),
            "q4": history(seen: 1, correct: 0),
        ]
        let scores = TopicScore.scores(for: questions, history: history)
        let prism = scores.first { $0.topic == "Prism" }
        XCTAssertEqual(prism?.attempts, 4)
        XCTAssertEqual(prism?.correct, 1)
        XCTAssertEqual(prism?.questionCount, 2)

        let weakest = TopicScore.weakest(scores, limit: 3)
        XCTAssertEqual(weakest.map(\.topic), ["Prism", "Vertex"], "Abbe has too few attempts to judge")
    }

    @MainActor
    func testPretestItemsAreTrackedButNotScored() throws {
        let container = try ModelContainer(for: Schema(ProgressSchema.models), configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let questions = (0..<10).map { question("pre-\($0)") }
        let config = QuizConfig(exam: .abo, title: "Mock", count: 10, timeLimitSeconds: 600, pretestCount: 3)
        let session = QuizSession(config: config, questions: questions)
        XCTAssertEqual(session.pretestIndices.count, 3)
        for index in questions.indices {
            session.currentIndex = index
            session.select(0)
        }
        session.finish(in: container.mainContext)

        XCTAssertEqual(session.record?.total, 7)
        XCTAssertEqual(session.record?.correct, 7)
        XCTAssertEqual(try container.mainContext.fetch(FetchDescriptor<QuestionStat>()).count, 10)
    }
}
