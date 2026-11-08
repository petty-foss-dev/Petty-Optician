import XCTest
@testable import PettyOptician

final class StudyOrganizationTests: XCTestCase {
    private let library = ContentLibrary.shared

    private func history(seen: Int, correct: Int, last: Bool) -> QuestionHistory {
        QuestionHistory(seen: seen, correct: correct, lastWasCorrect: last, flagged: false, lastAnswered: .now)
    }

    func testMostQuestionsLinkToALessonAndNearlyEveryLessonHasQuestions() {
        let links = LessonLinks(library: library)
        let linked = library.questions.filter { links.lesson(for: $0) != nil }
        XCTAssertGreaterThan(Double(linked.count) / Double(library.questions.count), 0.85)

        let lessons = library.guides.flatMap { guide in guide.sections.indices.map { LessonRef(domain: guide.domain, index: $0) } }
        XCTAssertLessThanOrEqual(lessons.filter { links.questions(for: $0).isEmpty }.count, 5)

        for question in linked {
            let lesson = links.lesson(for: question)!
            XCTAssertTrue(library.guide(for: lesson.domain).map { $0.sections.indices.contains(lesson.index) } ?? false, question.id)
            XCTAssertTrue(links.questions(for: lesson).contains(question), question.id)
        }
    }

    func testLessonLinksLandOnTheMatchingLesson() throws {
        let links = LessonLinks(library: library)
        let cases = [("ncle-fit-038", "keratoconus"), ("abo-ana-001", "cornea")]
        for (id, keyword) in cases {
            let question = try XCTUnwrap(library.questions.first { $0.id == id })
            let lesson = try XCTUnwrap(links.lesson(for: question), id)
            let section = library.guide(for: lesson.domain)!.sections[lesson.index]
            XCTAssertTrue((section.heading + " " + section.body).lowercased().contains(keyword), "\(id) → \(section.heading)")
        }
    }

    func testUnsureMeansRightNowAfterAnEarlierMiss() {
        XCTAssertTrue(QuizBuilder.matches(.unsure, history(seen: 2, correct: 1, last: true)))
        XCTAssertFalse(QuizBuilder.matches(.unsure, history(seen: 2, correct: 2, last: true)))
        XCTAssertFalse(QuizBuilder.matches(.unsure, history(seen: 2, correct: 1, last: false)))
        XCTAssertFalse(QuizBuilder.matches(.unsure, nil))
    }

    func testDailyQuestionIsStableAndPrefersUnseen() {
        let questions = library.questions(for: .abo)
        let seen = Dictionary(uniqueKeysWithValues: questions.dropFirst(5).map { ($0.id, history(seen: 1, correct: 1, last: true)) })
        let first = QuizBuilder.dailyQuestion(from: questions, history: seen, day: "2026-11-06")
        XCTAssertEqual(first, QuizBuilder.dailyQuestion(from: questions.shuffled(), history: seen, day: "2026-11-06"))
        XCTAssertTrue(questions.prefix(5).contains(first!))

        let week = Set((1...7).compactMap { QuizBuilder.dailyQuestion(from: questions, history: [:], day: "2026-11-0\($0)")?.id })
        XCTAssertGreaterThan(week.count, 4)
    }

    func testWeakestSectionNeedsEnoughAnswers() throws {
        let exam = try XCTUnwrap(library.exam(.abo))
        XCTAssertEqual(QuizBuilder.weakestSection(exam, library: library, history: [:])?.domain.id, exam.domains.max { $0.weight < $1.weight }?.id)

        func answer(_ domain: String, correct: Int, of total: Int) -> [String: QuestionHistory] {
            Dictionary(uniqueKeysWithValues: library.questions(for: .abo, domain: domain).prefix(total).enumerated().map { index, q in
                (q.id, history(seen: 1, correct: index < correct ? 1 : 0, last: index < correct))
            })
        }
        let weak = QuizBuilder.weakestSection(exam, library: library, history: answer("abo.laws", correct: 4, of: 10))
        XCTAssertEqual(weak?.domain.id, "abo.laws")
        XCTAssertEqual(weak?.accuracy ?? 0, 0.4, accuracy: 1e-9)

        let strong = QuizBuilder.weakestSection(exam, library: library, history: answer("abo.laws", correct: 9, of: 10))
        XCTAssertNotEqual(strong?.domain.id, "abo.laws")
        XCTAssertNil(strong?.accuracy)
    }

    func testMockReadinessNeedsThreePassingFullLengthMocksInARow() throws {
        let exam = try XCTUnwrap(library.exam(.abo))
        let full = exam.scoredQuestions ?? 100
        func mock(_ correct: Int, daysAgo: Double, timed: Bool = true, total: Int? = nil, laws: (Int, Int) = (8, 10)) -> QuizRecord {
            let record = QuizRecord(
                exam: .abo, title: "Mock", isTimedExam: timed, total: total ?? full, correct: correct, seconds: 60,
                breakdown: [DomainScore(domain: "abo.laws", correct: laws.0, total: laws.1)], missedIDs: []
            )
            record.date = .now.addingTimeInterval(-daysAgo * 86_400)
            return record
        }

        var readiness = MockReadiness(records: [mock(80, daysAgo: 1), mock(90, daysAgo: 2), mock(50, daysAgo: 3)], exam: exam)
        XCTAssertEqual(readiness.passingStreak, 2)
        XCTAssertFalse(readiness.isReady)

        readiness = MockReadiness(
            records: [mock(80, daysAgo: 1), mock(76, daysAgo: 2), mock(75, daysAgo: 3), mock(95, daysAgo: 0, timed: false), mock(20, daysAgo: 0, total: 20)],
            exam: exam
        )
        XCTAssertEqual(readiness.mocks.count, 3)
        XCTAssertTrue(readiness.isReady)
        XCTAssertTrue(readiness.isReady("abo.laws"))

        readiness = MockReadiness(records: [mock(80, daysAgo: 1), mock(80, daysAgo: 2, laws: (6, 10)), mock(80, daysAgo: 3)], exam: exam)
        XCTAssertFalse(readiness.isReady("abo.laws"))
    }

    func testProblemReportPrefillsTheQuestion() throws {
        let question = try XCTUnwrap(library.questions.first)
        let url = ProblemReport.url(for: question)
        XCTAssertEqual(url.host(), "github.com")
        XCTAssertEqual(url.path(), "/petty-foss-dev/Petty-Optician/issues/new")
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        XCTAssertEqual(items.first { $0.name == "title" }?.value, "Question \(question.id): ")
        let body = try XCTUnwrap(items.first { $0.name == "body" }?.value)
        XCTAssertTrue(body.contains(question.stem))
        XCTAssertTrue(body.contains("\(question.choices[question.answer]) (marked correct)"))
    }

    func testPersonalCardCarriesTheAnswerAndExplanation() throws {
        let question = try XCTUnwrap(library.questions.first)
        let card = PersonalCard(question: question).flashcard
        XCTAssertEqual(card.id, PersonalCard.idPrefix + question.id)
        XCTAssertTrue(card.front.hasPrefix(question.stem))
        XCTAssertTrue(card.back.hasPrefix("**\(["A", "B", "C", "D"][question.answer]). \(question.choices[question.answer])**"))
        XCTAssertTrue(card.back.hasSuffix(question.explanation))
    }
}
