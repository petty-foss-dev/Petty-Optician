import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class QuizSession: Identifiable {
    let id = UUID()
    let config: QuizConfig
    let questions: [Question]
    let startDate = Date.now
    /// Unscored items mixed in like the real exam's pretest questions; answered and tracked, but left out of the score.
    let pretestIndices: Set<Int>

    var currentIndex = 0
    private(set) var selections: [Int?]
    private(set) var revealed: Set<Int> = []
    var flagged: Set<String>
    private(set) var record: QuizRecord?

    init(config: QuizConfig, questions: [Question], flagged: Set<String> = []) {
        self.config = config
        self.questions = questions
        selections = Array(repeating: nil, count: questions.count)
        self.flagged = flagged
        pretestIndices = Set(questions.indices.shuffled().prefix(config.pretestCount))
    }

    var isPractice: Bool { !config.isTimed }
    var current: Question { questions[currentIndex] }
    var isFinished: Bool { record != nil }
    var answeredCount: Int { selections.compactMap { $0 }.count }

    func isRevealed(_ index: Int) -> Bool { revealed.contains(index) }

    func select(_ choice: Int) {
        guard !isFinished, !(isPractice && revealed.contains(currentIndex)) else { return }
        selections[currentIndex] = choice
        if isPractice { revealed.insert(currentIndex) }
    }

    func toggleFlag() {
        let id = current.id
        if flagged.contains(id) { flagged.remove(id) } else { flagged.insert(id) }
    }

    func remainingSeconds(at now: Date) -> Int? {
        config.timeLimitSeconds.map { max(0, $0 - Int(now.timeIntervalSince(startDate))) }
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
        let counted = countedIndices
        let indices = counted.filter { !pretestIndices.contains($0) }
        var stats = Dictionary(
            ((try? context.fetch(FetchDescriptor<QuestionStat>())) ?? []).map { ($0.questionID, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        func stat(for id: String) -> QuestionStat {
            if let existing = stats[id] { return existing }
            let created = QuestionStat(questionID: id)
            context.insert(created)
            stats[id] = created
            return created
        }

        for index in counted where !questions[index].id.hasPrefix(DrillGenerator.idPrefix) {
            let entry = stat(for: questions[index].id)
            let correct = isCorrect(index)
            entry.seen += 1
            entry.correct += correct ? 1 : 0
            entry.lastWasCorrect = correct
            entry.lastAnswered = .now
        }
        for question in questions where flagged.contains(question.id) || stats[question.id] != nil {
            stat(for: question.id).flagged = flagged.contains(question.id)
        }

        let grouped = Dictionary(grouping: indices) { questions[$0].domain }
        let breakdown = grouped.map { domain, idx in
            DomainScore(domain: domain, correct: idx.filter(isCorrect).count, total: idx.count)
        }.sorted { $0.domain < $1.domain }

        let created = QuizRecord(
            exam: config.exam,
            title: config.title,
            isTimedExam: config.isTimed,
            total: indices.count,
            correct: indices.filter(isCorrect).count,
            seconds: Int(Date.now.timeIntervalSince(startDate)),
            breakdown: breakdown,
            missedIDs: indices.filter { !isCorrect($0) }.map { questions[$0].id }
        )
        context.insert(created)
        try? context.save()
        record = created
        StudySettings.shared.recordStudy()
    }
}
