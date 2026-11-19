import SwiftData
import SwiftUI

struct HomeView: View {
    let openStudy: () -> Void
    @ObservedObject private var settings = StudySettings.shared
    @Query private var stats: [QuestionStat]
    @Query private var reviews: [CardReview]
    @Query private var personalCards: [PersonalCard]
    @Query(sort: \QuizRecord.date, order: .reverse) private var records: [QuizRecord]
    @Environment(\.palette) private var palette
    @State private var activeQuiz: QuizSession?
    @State private var activeDeck: FlashcardDeck?
    @State private var showingSettings = false
    @State private var showingBinder = false
    private let library = ContentLibrary.shared

    private var exam: ExamID { settings.exam }

    var body: some View {
        let questions = library.questions(for: exam)
        let ids = Set(questions.map(\.id))
        let examStats = stats.filter { ids.contains($0.questionID) && $0.seen > 0 }
        let mastered = examStats.filter(\.lastWasCorrect).count
        let readiness = weightedReadiness(stats: examStats)
        let allCards = library.flashcards(for: exam) + personalCards.flashcards(for: exam)
        let reviewed = Set(reviews.map(\.cardID))
        let cardIDs = Set(allCards.map(\.id))
        let dueIDs = Set(reviews.filter { cardIDs.contains($0.cardID) && $0.due <= .now }.map(\.cardID))
            .union(allCards.filter { $0.id.hasPrefix(PersonalCard.idPrefix) && !reviewed.contains($0.id) }.map(\.id))

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    ExamSwitcher()

                    TextbookContinueCard(exam: exam, openContents: openStudy)

                    hero(readiness: readiness, mastered: mastered, total: questions.count, answered: examStats.count)

                    ExamPlanCard(unseen: questions.count - examStats.count, dueCards: dueIDs.count)

                    Button { showingBinder = true } label: {
                        LinkRow(title: "Erin’s Study Binder", subtitle: "Pick up a crash course page or jot a note.", symbol: "book.closed")
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("today.binder")

                    HStack(spacing: 12) {
                        StatTile(value: "\(settings.streak)", label: "Day streak", symbol: "flame.fill")
                        StatTile(value: "\(dueIDs.count)", label: "Cards due", symbol: "rectangle.on.rectangle.angled")
                        StatTile(value: "\(records.filter { $0.exam == exam }.count)", label: "Quizzes", symbol: "checklist")
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        SectionTitle(title: "Today's Plan")
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                            QuickAction(title: "Daily 10", subtitle: "Unseen & missed first", symbol: "bolt.fill") {
                                let picked = QuizBuilder.weakFirst(exam: exam, count: 10, library: library, history: stats.history)
                                activeQuiz = QuizSession(
                                    config: QuizConfig(exam: exam, title: "Daily 10", count: picked.count),
                                    questions: picked,
                                    flagged: stats.flaggedIDs
                                )
                            }
                            .disabled(questions.isEmpty)
                            QuickAction(title: "Review Cards", subtitle: "\(dueIDs.count) due now", symbol: "rectangle.stack.fill") {
                                activeDeck = FlashcardDeck(title: "Due Cards", cards: allCards.filter { dueIDs.contains($0.id) })
                            }
                            .disabled(dueIDs.isEmpty)
                            let history = stats.history
                            let recheck = QuizBuilder.dueForReview(questions, history: history)
                            QuickAction(title: "Re-check Missed", subtitle: recheckSubtitle(recheck.count, next: QuizBuilder.nextReview(questions, history: history)), symbol: "arrow.clockwise.circle") {
                                activeQuiz = QuizSession(
                                    config: QuizConfig(exam: exam, title: "Re-check Missed", count: min(recheck.count, 30)),
                                    questions: Array(recheck.prefix(30)),
                                    flagged: stats.flaggedIDs
                                )
                            }
                            .disabled(recheck.isEmpty)
                            if let info = library.exam(exam), let weakest = QuizBuilder.weakestSection(info, library: library, history: history) {
                                QuickAction(title: "Weakest Section", subtitle: weakest.subtitle, symbol: "scope") {
                                    startWeakest(weakest.domain)
                                }
                            }
                        }
                    }

                    DailyQuestionCard(exam: exam)

                    domainReadiness

                    if let last = records.first(where: { $0.exam == exam }) {
                        VStack(alignment: .leading, spacing: 10) {
                            SectionTitle(title: "Last Session")
                            Panel { RecordRow(record: last) }
                        }
                    }

                    NavigationLink { TipJarView() } label: {
                        Panel(padding: 14) {
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: "heart.text.square").font(.title3).foregroundStyle(palette.accent)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Helped you study?").font(.subheadline.weight(.semibold)).foregroundStyle(palette.text)
                                    Text("This app is free. If it helped you pass or review, you can leave a tip to say thanks.")
                                        .font(.caption)
                                        .foregroundStyle(palette.secondaryText)
                                        .multilineTextAlignment(.leading)
                                }
                                Spacer(minLength: 0)
                                Image(systemName: "chevron.right").font(.caption).foregroundStyle(palette.tertiaryText)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("today.tipjar")
                }
                .padding()
            }
            .tabScreen("Today")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingSettings = true } label: { Image(systemName: "gearshape") }
                        .accessibilityLabel("Settings")
                }
            }
        }
        .quizCover($activeQuiz)
        .fullScreenCover(item: $activeDeck) { FlashcardSessionView(deck: $0) }
        .sheet(isPresented: $showingSettings) { SettingsView() }
        .binderSheet($showingBinder)
    }

    private func recheckSubtitle(_ due: Int, next: Date?) -> String {
        if due > 0 { return "\(due) due today" }
        guard let next else { return "Missed questions come back here" }
        return "Next \(next.formatted(.relative(presentation: .named)))"
    }

    private func startWeakest(_ domain: ExamDomain) {
        let picked = QuizBuilder.weakFirst(exam: exam, domain: domain.id, count: 15, library: library, history: stats.history)
        activeQuiz = QuizSession(
            config: QuizConfig(exam: exam, title: domain.name, domains: [domain.id], count: picked.count),
            questions: picked,
            flagged: stats.flaggedIDs
        )
    }

    private func weightedReadiness(stats: [QuestionStat]) -> Double {
        let correct = Set(stats.filter(\.lastWasCorrect).map(\.questionID))
        let domains = library.domains(for: exam)
        let totalWeight = domains.map(\.weight).reduce(0, +)
        guard totalWeight > 0 else { return 0 }
        return domains.reduce(0) { sum, domain in
            let ids = library.questions(for: exam, domain: domain.id).map(\.id)
            guard !ids.isEmpty else { return sum }
            return sum + domain.weight * Double(ids.filter(correct.contains).count) / Double(ids.count)
        } / totalWeight
    }

    private func hero(readiness: Double, mastered: Int, total: Int, answered: Int) -> some View {
        let info = library.exam(exam)
        let mocks = MockReadiness(records: records, exam: info)
        return Panel(padding: 20) {
            HStack(spacing: 20) {
                ZStack {
                    ProgressRing(progress: readiness, lineWidth: 12)
                    VStack(spacing: 0) {
                        Text(readiness, format: .percent.precision(.fractionLength(0)))
                            .font(.title2.weight(.bold).monospacedDigit())
                        Text("ready").font(.caption2).foregroundStyle(palette.secondaryText)
                    }
                }
                .frame(width: 104, height: 104)

                VStack(alignment: .leading, spacing: 6) {
                    Text(info?.shortName ?? exam.shortLabel)
                        .font(.caption.weight(.bold))
                        .tracking(1)
                        .foregroundStyle(palette.accent)
                    Text(exam.subject).font(.title3.weight(.bold))
                    Text("\(mastered) of \(total) questions answered correctly")
                        .font(.subheadline)
                        .foregroundStyle(palette.secondaryText)
                    Text("\(answered) attempted · weighted by the official outline")
                        .font(.caption)
                        .foregroundStyle(palette.tertiaryText)
                    Label(mocks.summary, systemImage: mocks.isReady ? "checkmark.seal.fill" : "timer")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(mocks.isReady ? .green : palette.secondaryText)
                }
            }
        }
    }

    private var domainReadiness: some View {
        let mocks = MockReadiness(records: records, exam: library.exam(exam))
        return VStack(alignment: .leading, spacing: 10) {
            SectionTitle(title: "Exam Sections", trailing: "% of exam")
            Panel {
                VStack(spacing: 14) {
                    ForEach(library.domains(for: exam)) { domain in
                        DomainMeter(domain: domain, exam: exam, stats: stats, mockReady: mocks.isReady(domain.id)) {
                            let picked = QuizBuilder.weakFirst(exam: exam, domain: domain.id, count: 10, library: library, history: stats.history)
                            activeQuiz = QuizSession(
                                config: QuizConfig(exam: exam, title: domain.name, domains: [domain.id], count: picked.count),
                                questions: picked,
                                flagged: stats.flaggedIDs
                            )
                        }
                    }
                }
            }
        }
    }
}

private struct DomainMeter: View {
    let domain: ExamDomain
    let exam: ExamID
    let stats: [QuestionStat]
    let mockReady: Bool
    let action: () -> Void
    @Environment(\.palette) private var palette
    private let library = ContentLibrary.shared

    var body: some View {
        let ids = Set(library.questions(for: exam, domain: domain.id).map(\.id))
        let answered = stats.filter { ids.contains($0.questionID) && $0.seen > 0 }
        let correct = answered.filter(\.lastWasCorrect).count
        let mastery = ids.isEmpty ? 0 : Double(correct) / Double(ids.count)

        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(domain.name).font(.subheadline.weight(.medium)).foregroundStyle(palette.text)
                    if mockReady {
                        Image(systemName: "checkmark.seal.fill").font(.caption).foregroundStyle(.green)
                            .accessibilityLabel("Ready in mock exams")
                    }
                    Spacer()
                    Text("\(Int(domain.weight))%")
                        .font(.caption.weight(.semibold).monospacedDigit())
                        .foregroundStyle(palette.tertiaryText)
                    Image(systemName: "play.circle").foregroundStyle(palette.accent)
                }
                MeterBar(value: mastery, tint: mastery >= 0.75 ? .green : nil)
                Text("\(correct)/\(ids.count) mastered · \(answered.count) attempted")
                    .font(.caption2)
                    .foregroundStyle(palette.secondaryText)
            }
        }
        .buttonStyle(.plain)
        .disabled(ids.isEmpty)
    }
}
