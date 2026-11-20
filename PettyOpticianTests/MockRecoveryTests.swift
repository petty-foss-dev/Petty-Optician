import SwiftData
import XCTest
@testable import PettyOptician

@MainActor
final class MockRecoveryTests: XCTestCase {
    private func directory() -> URL {
        let url = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }

    private func begin(_ exam: ExamID, store: SavedMockExams, at date: Date = .now) throws -> QuizSession {
        let questions = Array(ContentLibrary.shared.questions(for: exam).prefix(4))
        let config = QuizConfig(exam: exam, title: "Mock Exam", count: questions.count,
                                timeLimitSeconds: 600, pretestIDs: [questions[3].id])
        return try store.begin(config: config, questions: questions, flagged: [], at: date)
    }

    func testBothTracksRestoreTheirOriginalPaperDeadlineAndAnswers() throws {
        let url = directory()
        let store = SavedMockExams(directory: url)
        let start = Date(timeIntervalSinceNow: -90)
        let first = try begin(.abo, store: store, at: start)
        first.select(2)
        first.toggleFlag()
        first.currentIndex = 2
        first.select(3)
        let second = try begin(.ncle, store: store)
        XCTAssertIdentical(try begin(.abo, store: store), first)

        let reopened = SavedMockExams(directory: url)
        let restored = try XCTUnwrap(reopened.sessions[.abo])
        XCTAssertEqual(restored.questions, first.questions)
        XCTAssertEqual(restored.id, first.id)
        XCTAssertEqual(restored.remainingSeconds(at: start.addingTimeInterval(120)), 480)
        XCTAssertEqual(restored.selections, [2, nil, 3, nil])
        XCTAssertEqual(restored.flagged, [first.questions[0].id])
        XCTAssertEqual(restored.currentIndex, 2)
        XCTAssertEqual(restored.pretestIndices, [3])
        XCTAssertEqual(reopened.sessions[.ncle]?.id, second.id)
        XCTAssertTrue(restored.discard())
        let afterDiscard = SavedMockExams(directory: url)
        XCTAssertNil(afterDiscard.sessions[.abo])
        XCTAssertEqual(afterDiscard.sessions[.ncle]?.id, second.id)
    }

    func testExpiredDraftCannotChangeAnswersAndSubmissionIsIdempotentAcrossLaunches() throws {
        let url = directory()
        let store = SavedMockExams(directory: url)
        let expired = try begin(.abo, store: store, at: Date(timeIntervalSinceNow: -900))
        let interrupted = SavedMockExams(directory: url)
        let stale = try XCTUnwrap(interrupted.sessions[.abo])
        expired.select(0)
        expired.toggleFlag()
        XCTAssertEqual(expired.answeredCount, 0)
        XCTAssertTrue(expired.flagged.isEmpty)
        let container = try ModelContainer(for: Schema(ProgressSchema.models),
                                           configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none))
        expired.finish(in: container.mainContext)
        stale.finish(in: container.mainContext)
        XCTAssertEqual(stale.record?.id, expired.id)
        XCTAssertEqual(stale.record?.total, 3)
        XCTAssertEqual(stale.record?.seconds, 600)
        XCTAssertEqual(stale.record?.date, expired.startDate.addingTimeInterval(600))
        XCTAssertEqual(try container.mainContext.fetchCount(FetchDescriptor<QuizRecord>()), 1)
        let stats = try container.mainContext.fetch(FetchDescriptor<QuestionStat>())
        XCTAssertEqual(stats.count, 4)
        XCTAssertTrue(stats.allSatisfy { $0.seen == 1 })
        XCTAssertTrue(SavedMockExams(directory: url).sessions.isEmpty)
    }
}
