import SwiftData
import XCTest
@testable import PettyOptician

@MainActor
final class FeatureWaveTests: XCTestCase {
    private let library = ContentLibrary.shared

    func testMissedQuestionsComeBackOnAWideningSchedule() {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let day: TimeInterval = 86_400
        let stat = QuestionStat(questionID: "q")

        stat.recordAnswer(correct: false, at: start)
        XCTAssertEqual(stat.reviewDue, start.addingTimeInterval(day))
        XCTAssertFalse(stat.isReviewDue(at: start.addingTimeInterval(day / 2)))

        stat.recordAnswer(correct: true, at: start.addingTimeInterval(day / 2))
        XCTAssertEqual(stat.reviewDue, start.addingTimeInterval(day), "A correct answer before it's due doesn't advance it")

        var now = start.addingTimeInterval(day)
        for interval in QuestionStat.reviewIntervals.dropFirst() {
            stat.recordAnswer(correct: true, at: now)
            XCTAssertEqual(stat.reviewDue, now.addingTimeInterval(interval * day))
            now = stat.reviewDue!
        }
        stat.recordAnswer(correct: true, at: now)
        XCTAssertNil(stat.reviewDue, "Clears after the last step")

        stat.recordAnswer(correct: false, at: now)
        XCTAssertEqual(stat.reviewStep, 0)
        XCTAssertEqual(stat.reviewDue, now.addingTimeInterval(day))
    }

    func testDueForReviewListsEarliestFirst() {
        let questions = Array(library.questions(for: .abo).prefix(3))
        let now = Date.now
        let history: [String: QuestionHistory] = [
            questions[0].id: .init(seen: 1, correct: 0, lastWasCorrect: false, flagged: false, lastAnswered: now, reviewDue: now.addingTimeInterval(-60)),
            questions[1].id: .init(seen: 1, correct: 0, lastWasCorrect: false, flagged: false, lastAnswered: now, reviewDue: now.addingTimeInterval(-3_600)),
            questions[2].id: .init(seen: 1, correct: 0, lastWasCorrect: false, flagged: false, lastAnswered: now, reviewDue: now.addingTimeInterval(3_600)),
        ]
        XCTAssertEqual(QuizBuilder.dueForReview(questions, history: history, at: now).map(\.id), [questions[1].id, questions[0].id])
        XCTAssertEqual(QuizBuilder.nextReview(questions, history: history, after: now), now.addingTimeInterval(3_600))
    }

    func testPictureQuestionsHaveFourDistinctChoicesAndTheRightAnswer() {
        for exam in ExamID.allCases {
            let pool = PictureQuiz.items(for: exam, library: library)
            XCTAssertGreaterThan(pool.count, 10)
            for item in pool {
                let question = PictureQuiz.question(for: item, exam: exam, pool: pool)
                XCTAssertNotNil(question, item.id)
                guard let question else { continue }
                XCTAssertEqual(question.choices.count, 4)
                XCTAssertEqual(Set(question.choices).count, 4, item.id)
                XCTAssertEqual(question.choices[question.answer], item.title)
                XCTAssertEqual(question.picture, item.id)
                XCTAssertTrue(question.isGenerated)
                XCTAssertTrue(library.domains(for: exam).contains { $0.id == question.domain }, item.id)
            }
        }
    }

    func testProgressMergeFoldsDuplicateRecordsFromTwoDevices() throws {
        let container = try ModelContainer(for: Schema(ProgressSchema.models), configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none))
        let context = container.mainContext
        let older = QuestionStat(questionID: "q1")
        older.recordAnswer(correct: false, at: .now.addingTimeInterval(-500))
        older.flagged = true
        let newer = QuestionStat(questionID: "q1")
        newer.recordAnswer(correct: true, at: .now)
        newer.recordAnswer(correct: true, at: .now)
        context.insert(older)
        context.insert(newer)
        let keptUID = [older.uid, newer.uid].min { $0.uuidString < $1.uuidString }

        let oldNote = StudyNote(kind: .question, targetID: "q1", exam: .abo, text: "old")
        oldNote.updated = .now.addingTimeInterval(-100)
        context.insert(oldNote)
        context.insert(StudyNote(kind: .question, targetID: "q1", exam: .abo, text: "new"))
        try context.save()

        ProgressMerge.run(in: context)

        let stats = try context.fetch(FetchDescriptor<QuestionStat>())
        XCTAssertEqual(stats.count, 1)
        XCTAssertEqual(stats[0].uid, keptUID, "Every device keeps the same record")
        XCTAssertEqual(stats[0].seen, 3)
        XCTAssertEqual(stats[0].correct, 2)
        XCTAssertTrue(stats[0].lastWasCorrect)
        XCTAssertTrue(stats[0].flagged)
        XCTAssertEqual(try context.fetch(FetchDescriptor<StudyNote>()).map(\.text), ["new"])
    }

    func testLessonNoteTargetRoundTrips() {
        let lesson = LessonRef(domain: "abo.optics", index: 3)
        let note = StudyNote(kind: .lesson, targetID: StudyNote.lessonTarget(lesson), exam: .abo, text: "x")
        XCTAssertEqual(note.lesson, lesson)
        XCTAssertNil(StudyNote(kind: .question, targetID: "abo-ana-001", exam: .abo, text: "x").lesson)
    }

    func testPhrasesStayShortAndBreakAtNaturalPlaces() {
        let sample = "The tear lens is the layer of tears between the back of a GP lens and the cornea."
        XCTAssertEqual(SpeechPhrases.split(sample).map(\.text), ["The tear lens is the layer of tears between the back of a GP lens", "and the cornea."])
        let clauses = SpeechPhrases.split("Lost endothelial cells are not meaningfully replaced; neighboring cells spread to cover the gap, so damage can lead to edema.")
        XCTAssertEqual(clauses.first?.text, "Lost endothelial cells are not meaningfully replaced;")
        XCTAssertEqual(clauses.first?.pause, SpeechPhrases.clausePause)
        XCTAssertEqual(SpeechPhrases.split("Use e.g. Trivex here. Then check.").map(\.text), ["Use e.g. Trivex here.", "Then check."])

        for card in library.flashcards + library.questions.map({ Flashcard(id: $0.id, exam: $0.exam, domain: $0.domain, front: $0.stem, back: $0.explanation) }) {
            let text = Speaker.spoken(card.back)
            let phrases = SpeechPhrases.split(text)
            XCTAssertTrue(phrases.allSatisfy { $0.text.count <= SpeechPhrases.maxLength || !$0.text.contains(" ") }, card.id)
            XCTAssertEqual(phrases.map(\.text).joined(separator: " "), text.split(whereSeparator: \.isWhitespace).joined(separator: " "), "No words lost: \(card.id)")
            XCTAssertEqual(phrases.last?.pause, SpeechPhrases.sentencePause, card.id)
        }
    }

    func testTrimSilenceDropsThePaddingButKeepsTheVoice() {
        let rate = 1_000.0
        let voiced = (0..<300).map { Float(sin(Double($0) * 0.5)) * 0.5 }
        let padded = [Float](repeating: 0, count: 400) + voiced + [Float](repeating: 0.001, count: 1_200)
        let trimmed = SpeechPhrases.trimSilence(padded, sampleRate: rate)
        XCTAssertLessThan(trimmed.count, voiced.count + 130)
        XCTAssertGreaterThanOrEqual(trimmed.count, voiced.count)
        XCTAssertEqual(trimmed.first, 0, "Fades in")
        XCTAssertTrue(SpeechPhrases.trimSilence([Float](repeating: 0, count: 500), sampleRate: rate).isEmpty)
    }

    func testSpokenTextReadsOpticsNotation() {
        XCTAssertEqual(Speaker.spoken("**−2.00** −1.00 × 180"), "minus 2.00 minus 1.00 axis 180")
        XCTAssertEqual(Speaker.spoken("2Δ BI"), "2 prism diopters BI")
    }

    func testSupertonicManifestIsBundledAndPinned() throws {
        let url = try XCTUnwrap(Bundle(for: PersonalCard.self).url(forResource: "SupertonicManifest", withExtension: "json")
            ?? Bundle.main.url(forResource: "SupertonicManifest", withExtension: "json"))
        let manifest = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]
        XCTAssertEqual(manifest?["revision"] as? String, "2b5b939dfa1bca362c5212dcafeb8aadde90b1bc")
        XCTAssertEqual((manifest?["files"] as? [Any])?.count, 36)
        XCTAssertGreaterThan(SupertonicPack.totalBytes, 150_000_000)
    }

    func testDailyQuestionReadAloudGivesTheAnswerOnlyAfterAnswering() throws {
        let question = try XCTUnwrap(library.questions.first)
        let before = DailyQuestionCard.readAloud(question, choice: nil)
        XCTAssertTrue(before.hasPrefix(question.stem))
        XCTAssertFalse(before.contains("The answer is"))
        XCTAssertTrue(DailyQuestionCard.readAloud(question, choice: 0).hasPrefix("The answer is"))
    }

    func testWidgetSnapshotRoundTripsThroughTheAppGroup() {
        var snapshot = WidgetSnapshot.placeholder
        snapshot.cardsDue = 7
        snapshot.save()
        XCTAssertEqual(WidgetSnapshot.load(), snapshot)
    }
}
