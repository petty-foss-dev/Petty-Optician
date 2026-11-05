import Foundation
import SwiftData

@Model
final class QuestionStat {
    @Attribute(.unique) var questionID: String
    var seen: Int
    var correct: Int
    var lastAnswered: Date
    var lastWasCorrect: Bool
    var flagged: Bool

    init(questionID: String) {
        self.questionID = questionID
        seen = 0
        correct = 0
        lastAnswered = .distantPast
        lastWasCorrect = false
        flagged = false
    }
}

@Model
final class CardReview {
    @Attribute(.unique) var cardID: String
    var ease: Double
    var intervalDays: Double
    var due: Date
    var reps: Int
    var lapses: Int
    var lastReviewed: Date
    var introduced: Date

    init(cardID: String) {
        self.cardID = cardID
        ease = CardScheduler.startingEase
        intervalDays = 0
        due = .now
        reps = 0
        lapses = 0
        lastReviewed = .distantPast
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
    var id: UUID
    var date: Date
    var examRaw: String
    var title: String
    var isTimedExam: Bool
    var total: Int
    var correct: Int
    var seconds: Int
    var breakdownData: Data
    var missedIDs: [String]

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
        id = UUID()
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
    @Attribute(.unique) var resourceID: String
    var completed: Bool
    var favorite: Bool

    init(resourceID: String) {
        self.resourceID = resourceID
        completed = false
        favorite = false
    }
}

enum ProgressSchema {
    static let models: [any PersistentModel.Type] = [
        QuestionStat.self, CardReview.self, QuizRecord.self, ResourceMark.self
    ]
}
