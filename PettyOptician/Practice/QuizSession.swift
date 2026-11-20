import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class QuizSession: Identifiable {
    let id: UUID
    let config: QuizConfig
    let questions: [Question]
    let startDate: Date
    @ObservationIgnored private weak var store: SavedMockExams?
    var saveError: String?
    var isSavedMock: Bool { store != nil }
    /// Unscored items mixed in like the real exam's pretest questions; answered and tracked, but left out of the score.
    let pretestIndices: Set<Int>

    var currentIndex: Int { didSet { persist() } }
    private(set) var selections: [Int?]
    private(set) var revealed: Set<Int> = []
    private(set) var flagged: Set<String>
    private var changedFlags: Set<String> = []
    private(set) var record: QuizRecord?

    init(config: QuizConfig, questions: [Question], flagged: Set<String> = []) {
        id = UUID()
        startDate = .now
        currentIndex = 0
        self.config = config
        self.questions = questions
        selections = Array(repeating: nil, count: questions.count)
        self.flagged = flagged
        pretestIndices = Set(questions.indices.filter { config.pretestIDs.contains(questions[$0].id) })
    }

    init(saved: SavedMock, store: SavedMockExams) {
        self.store = store
        id = saved.id
        startDate = saved.started
        questions = saved.questions
        currentIndex = saved.index
        selections = saved.selections
        flagged = saved.flags
        changedFlags = saved.changedFlags
        config = QuizConfig(exam: saved.exam, title: saved.title, count: saved.questions.count,
                            timeLimitSeconds: saved.duration, pretestIDs: saved.pretestIDs)
        pretestIndices = Set(saved.questions.indices.filter { saved.pretestIDs.contains(saved.questions[$0].id) })
    }

    @discardableResult
    func persist() -> Bool {
        guard let store, let duration = config.timeLimitSeconds, !isFinished else { return true }
        do {
            try store.save(SavedMock(id: id, exam: config.exam, title: config.title, started: startDate,
                                     duration: duration, questions: questions, pretestIDs: config.pretestIDs,
                                     index: currentIndex, selections: selections, flags: flagged, changedFlags: changedFlags))
            return true
        } catch {
            saveError = "Your latest change could not be saved on this device. Keep the exam open and try again."
            return false
        }
    }

    func discard() -> Bool {
        do {
            try store?.remove(config.exam, id: id)
            return true
        } catch {
            saveError = "The saved mock could not be removed. Please try again."
            return false
        }
    }

    var isPractice: Bool { !config.isTimed }
    var current: Question { questions[currentIndex] }
    var isFinished: Bool { record != nil }
    var answeredCount: Int { selections.compactMap { $0 }.count }

    func isRevealed(_ index: Int) -> Bool { revealed.contains(index) }

    func select(_ choice: Int) {
        guard !isFinished, remainingSeconds(at: .now) != 0, !(isPractice && revealed.contains(currentIndex)) else { return }
        selections[currentIndex] = choice
        if isPractice { revealed.insert(currentIndex) }
        persist()
    }

    func toggleFlag() {
        guard !isFinished, remainingSeconds(at: .now) != 0 else { return }
        let id = current.id
        changedFlags.insert(id)
        if flagged.contains(id) { flagged.remove(id) } else { flagged.insert(id) }
        persist()
    }

    func remainingSeconds(at now: Date) -> Int? {
        config.timeLimitSeconds.map { min($0, max(0, $0 - Int(now.timeIntervalSince(startDate)))) }
    }

    /// Practice sessions count only what was answered; timed exams count blanks as wrong.
    private var countedIndices: [Int] {
        isPractice ? questions.indices.filter { selections[$0] != nil } : Array(questions.indices)
    }

    var unansweredCount: Int { selections.filter { $0 == nil }.count }

    func firstIndex(where predicate: (Int) -> Bool) -> Int? {
        questions.indices.first(where: predicate)
    }

    func isCorrect(_ index: Int) -> Bool { selections[index] == questions[index].answer }

    func finish(in context: ModelContext) {
        guard !isFinished else { return }
        let existingStats: [QuestionStat]
        do {
            if isSavedMock {
                let sessionID = id
                var descriptor = FetchDescriptor<QuizRecord>(predicate: #Predicate { $0.id == sessionID })
                descriptor.fetchLimit = 1
                if let existing = try context.fetch(descriptor).first {
                    record = existing
                    _ = discard()
                    return
                }
            }
            existingStats = try context.fetch(FetchDescriptor<QuestionStat>())
        } catch {
            saveError = "Your results could not be loaded. Please try submitting again."
            return
        }
        let counted = countedIndices
        let indices = counted.filter { !pretestIndices.contains($0) }
        var stats = Dictionary(existingStats.map { ($0.questionID, $0) }, uniquingKeysWith: { first, _ in first })
        func stat(for id: String) -> QuestionStat {
            if let existing = stats[id] { return existing }
            let created = QuestionStat(questionID: id)
            context.insert(created)
            stats[id] = created
            return created
        }

        for index in counted where !questions[index].isGenerated {
            stat(for: questions[index].id).recordAnswer(correct: isCorrect(index))
        }
        for id in changedFlags {
            stat(for: id).flagged = flagged.contains(id)
        }

        let grouped = Dictionary(grouping: indices) { questions[$0].domain }
        let breakdown = grouped.map { domain, idx in
            DomainScore(domain: domain, correct: idx.filter(isCorrect).count, total: idx.count)
        }.sorted { $0.domain < $1.domain }

        let elapsed = max(0, Int(Date.now.timeIntervalSince(startDate)))
        let seconds = min(elapsed, config.timeLimitSeconds ?? elapsed)
        let created = QuizRecord(
            exam: config.exam,
            title: config.title,
            isTimedExam: config.isTimed,
            total: indices.count,
            correct: indices.filter(isCorrect).count,
            seconds: seconds,
            breakdown: breakdown,
            missedIDs: indices.filter { !isCorrect($0) }.map { questions[$0].id }
        )
        created.id = id
        if let limit = config.timeLimitSeconds {
            created.date = min(.now, startDate.addingTimeInterval(TimeInterval(limit)))
        }
        context.insert(created)
        do {
            try context.save()
        } catch {
            context.rollback()
            saveError = "Your score could not be saved. Please try submitting again."
            return
        }
        record = created
        _ = discard()
        StudySettings.shared.recordStudy()
    }
}
