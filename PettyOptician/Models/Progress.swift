import Foundation
import SwiftData

// CloudKit sync rules for every model here: each stored property has a default and nothing is `.unique`.
// Devices can create the same record independently; `ProgressMerge` folds duplicates back together.

@Model
final class QuestionStat {
    /// Days until a missed question comes back; one correct answer when due moves it to the next step.
    static let reviewIntervals: [Double] = [1, 3, 7, 21]

    /// Same on every device once synced, so all devices keep the same record when merging duplicates.
    var uid: UUID = UUID()
    var questionID: String = ""
    var seen: Int = 0
    var correct: Int = 0
    var lastAnswered: Date = Date.distantPast
    var lastWasCorrect: Bool = false
    var flagged: Bool = false
    var reviewDue: Date?
    var reviewStep: Int = 0

    init(questionID: String) {
        self.questionID = questionID
    }

    func recordAnswer(correct isCorrect: Bool, at date: Date = .now) {
        seen += 1
        correct += isCorrect ? 1 : 0
        lastWasCorrect = isCorrect
        lastAnswered = date
        if !isCorrect {
            reviewStep = 0
            reviewDue = date.addingTimeInterval(Self.reviewIntervals[0] * 86_400)
        } else if let due = reviewDue, due <= date {
            reviewStep += 1
            reviewDue = reviewStep < Self.reviewIntervals.count
                ? date.addingTimeInterval(Self.reviewIntervals[reviewStep] * 86_400)
                : nil
            if reviewDue == nil { reviewStep = 0 }
        }
    }

    func isReviewDue(at date: Date = .now) -> Bool { reviewDue.map { $0 <= date } ?? false }
}

@Model
final class CardReview {
    var cardID: String = ""
    var ease: Double = CardScheduler.startingEase
    var intervalDays: Double = 0
    var due: Date = Date.distantPast
    var reps: Int = 0
    var lapses: Int = 0
    var lastReviewed: Date = Date.distantPast
    var introduced: Date = Date.distantPast

    init(cardID: String) {
        self.cardID = cardID
        due = .now
        introduced = .now
    }
}

struct DomainScore: Codable, Hashable, Sendable {
    let domain: String
    let correct: Int
    let total: Int
}

@Model
final class QuizRecord {
    var id: UUID = UUID()
    var date: Date = Date.distantPast
    var examRaw: String = ExamID.abo.rawValue
    var title: String = ""
    var isTimedExam: Bool = false
    var total: Int = 0
    var correct: Int = 0
    var seconds: Int = 0
    var breakdownData: Data = Data()
    var missedIDs: [String] = []

    init(
        exam: ExamID,
        title: String,
        isTimedExam: Bool,
        total: Int,
        correct: Int,
        seconds: Int,
        breakdown: [DomainScore],
        missedIDs: [String]
    ) {
        date = .now
        examRaw = exam.rawValue
        self.title = title
        self.isTimedExam = isTimedExam
        self.total = total
        self.correct = correct
        self.seconds = seconds
        breakdownData = (try? JSONEncoder().encode(breakdown)) ?? Data()
        self.missedIDs = missedIDs
    }

    var exam: ExamID { ExamID(rawValue: examRaw) ?? .abo }

    var percent: Double { total == 0 ? 0 : Double(correct) / Double(total) }

    var breakdown: [DomainScore] {
        (try? JSONDecoder().decode([DomainScore].self, from: breakdownData)) ?? []
    }
}

@Model
final class ResourceMark {
    var uid: UUID = UUID()
    var resourceID: String = ""
    var completed: Bool = false
    var favorite: Bool = false

    init(resourceID: String) {
        self.resourceID = resourceID
    }
}

/// A flashcard the user made from a practice question; reviewed alongside the bundled cards.
@Model
final class PersonalCard {
    static let idPrefix = "mine-"

    var cardID: String = ""
    var questionID: String = ""
    var examRaw: String = ExamID.abo.rawValue
    var domain: String = ""
    var front: String = ""
    var back: String = ""
    var created: Date = Date.distantPast

    init(question: Question) {
        cardID = Self.idPrefix + question.id
        questionID = question.id
        examRaw = question.exam.rawValue
        domain = question.domain
        front = Self.front(for: question)
        back = Self.back(for: question)
        created = .now
    }

    var exam: ExamID { ExamID(rawValue: examRaw) ?? .abo }

    /// Built from the current question so content fixes reach cards made earlier; the stored text covers removed questions.
    var flashcard: Flashcard {
        guard let question = ContentLibrary.shared.question(id: questionID) else {
            return Flashcard(id: cardID, exam: exam, domain: domain, front: front, back: back)
        }
        return Flashcard(id: cardID, exam: exam, domain: domain, front: Self.front(for: question), back: Self.back(for: question))
    }

    private static let letters = ["A", "B", "C", "D"]

    /// The choices stay on the front: many stems ("Which of these…") can't be answered without them.
    static func front(for question: Question) -> String {
        ([question.stem, ""] + question.choices.enumerated().map { "- \(letters[$0.offset]). \($0.element)" }).joined(separator: "\n")
    }

    static func back(for question: Question) -> String {
        "**\(letters[question.answer]). \(question.choices[question.answer])**\n\n\(question.explanation)"
    }

    func delete(from context: ModelContext) {
        let id = cardID
        try? context.delete(model: CardReview.self, where: #Predicate { $0.cardID == id })
        context.delete(self)
    }
}

extension [PersonalCard] {
    func flashcards(for exam: ExamID) -> [Flashcard] {
        filter { $0.exam == exam }.sorted { $0.created < $1.created }.map(\.flashcard)
    }
}

@Model
final class StudyNote {
    enum Kind: String, Sendable { case lesson, question, binderPage, quick }

    var kindRaw: String = Kind.question.rawValue
    var targetID: String = ""
    var examRaw: String = ExamID.abo.rawValue
    var text: String = ""
    var updated: Date = Date.distantPast

    init(kind: Kind, targetID: String, exam: ExamID, text: String) {
        kindRaw = kind.rawValue
        self.targetID = targetID
        examRaw = exam.rawValue
        self.text = text
        updated = .now
    }

    var kind: Kind { Kind(rawValue: kindRaw) ?? .question }
    var exam: ExamID { ExamID(rawValue: examRaw) ?? .abo }

    static func lessonTarget(_ lesson: LessonRef) -> String { "\(lesson.domain)#\(lesson.index)" }

    var lesson: LessonRef? {
        guard kind == .lesson else { return nil }
        let parts = targetID.split(separator: "#")
        guard parts.count == 2, let index = Int(parts[1]) else { return nil }
        return LessonRef(domain: String(parts[0]), index: index)
    }
}

enum ProgressSchema {
    static let models: [any PersistentModel.Type] = [
        QuestionStat.self, CardReview.self, QuizRecord.self, ResourceMark.self, PersonalCard.self, StudyNote.self
    ]
}
