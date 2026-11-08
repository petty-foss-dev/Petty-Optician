import SwiftData
import SwiftUI
import WidgetKit

/// Rebuilds the widget snapshot from current progress and asks WidgetKit to redraw when it changed.
enum WidgetPublisher {
    @MainActor
    static func publish(in context: ModelContext) {
        let settings = StudySettings.shared
        let library = ContentLibrary.shared
        let exam = settings.exam
        let stats = (try? context.fetch(FetchDescriptor<QuestionStat>())) ?? []
        let reviews = (try? context.fetch(FetchDescriptor<CardReview>())) ?? []
        let mine = (try? context.fetch(FetchDescriptor<PersonalCard>())) ?? []
        let history = stats.history
        let questions = library.questions(for: exam)

        let cardIDs = Set(library.flashcards(for: exam).map(\.id) + mine.flashcards(for: exam).map(\.id))
        let reviewed = Set(reviews.map(\.cardID))
        let cardsDue = reviews.filter { cardIDs.contains($0.cardID) && $0.due <= .now }.count
            + cardIDs.filter { $0.hasPrefix(PersonalCard.idPrefix) && !reviewed.contains($0) }.count

        let daily = settings.dailyQuestion(for: exam).flatMap { library.question(id: $0.id) }.map {
            WidgetSnapshot.DailyQuestion(
                id: $0.id, stem: $0.stem, choices: $0.choices, answer: $0.answer,
                section: library.domainName($0.domain), day: StudySettings.dayKey(.now)
            )
        }
        let correct = Set(stats.filter(\.lastWasCorrect).map(\.questionID))
        let snapshot = WidgetSnapshot(
            exam: exam.shortLabel,
            daysUntilExam: settings.daysUntilExam(exam),
            cardsDue: cardsDue,
            recheckDue: QuizBuilder.dueForReview(questions, history: history).count,
            streak: settings.streak,
            readiness: questions.isEmpty ? 0 : Double(questions.filter { correct.contains($0.id) }.count) / Double(questions.count),
            daily: daily
        )
        guard snapshot != WidgetSnapshot.load() else { return }
        snapshot.save()
        WidgetCenter.shared.reloadAllTimelines()
    }
}
