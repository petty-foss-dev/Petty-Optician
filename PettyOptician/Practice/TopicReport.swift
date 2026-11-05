import SwiftData
import SwiftUI

struct TopicScore: Identifiable, Hashable, Sendable {
    let domain: String
    let topic: String
    let questionCount: Int
    let attempts: Int
    let correct: Int

    var id: String { domain + "/" + topic }
    var accuracy: Double { attempts == 0 ? 0 : Double(correct) / Double(attempts) }

    static let minimumAttempts = 3

    static func scores(for questions: [Question], history: [String: QuestionHistory]) -> [TopicScore] {
        Dictionary(grouping: questions) { TopicKey(domain: $0.domain, topic: $0.topic) }
            .map { key, group in
                let stats = group.compactMap { history[$0.id] }
                return TopicScore(
                    domain: key.domain,
                    topic: key.topic,
                    questionCount: group.count,
                    attempts: stats.map(\.seen).reduce(0, +),
                    correct: stats.map(\.correct).reduce(0, +)
                )
            }
            .sorted { ($0.domain, $0.topic) < ($1.domain, $1.topic) }
    }

    /// Lowest accuracy first among topics with enough attempts to judge; ties go to the more-attempted topic.
    static func weakest(_ scores: [TopicScore], limit: Int) -> [TopicScore] {
        Array(
            scores.filter { $0.attempts >= minimumAttempts }
                .sorted { ($0.accuracy, -$0.attempts) < ($1.accuracy, -$1.attempts) }
                .prefix(limit)
        )
    }

    private struct TopicKey: Hashable {
        let domain: String
        let topic: String
    }
}

extension QuizBuilder {
    static func topicDrill(_ topics: [TopicScore], exam: ExamID, count: Int, library: ContentLibrary, history: [String: QuestionHistory]) -> [Question] {
        let ids = Set(topics.map(\.id))
        let pool = library.questions(for: exam).filter { ids.contains($0.domain + "/" + $0.topic) }
        return weakFirst(pool, count: count, history: history)
    }
}

struct WeakTopicsPanel: View {
    let exam: ExamID
    let history: [String: QuestionHistory]
    let start: (String, [Question]) -> Void
    @Environment(\.palette) private var palette
    private let library = ContentLibrary.shared

    var body: some View {
        let scores = TopicScore.scores(for: library.questions(for: exam), history: history)
        let weakest = TopicScore.weakest(scores, limit: 3)
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(title: "Weak Topics")
            Panel {
                VStack(alignment: .leading, spacing: 14) {
                    if weakest.isEmpty {
                        Text("Answer a few questions in a topic (\(TopicScore.minimumAttempts)+) and your weakest topics show up here.")
                            .font(.subheadline)
                            .foregroundStyle(palette.secondaryText)
                    } else {
                        ForEach(weakest) { TopicScoreRow(score: $0) }
                        Button {
                            start("Weak Topics Drill", QuizBuilder.topicDrill(weakest, exam: exam, count: 20, library: library, history: history))
                        } label: {
                            Label("Drill These Topics", systemImage: "scope").frame(maxWidth: .infinity, minHeight: 40)
                        }
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("practice.weak-drill")
                    }
                    NavigationLink {
                        TopicReportView(exam: exam, history: history, start: start)
                    } label: {
                        HStack {
                            Text("All topics by section")
                            Spacer()
                            Image(systemName: "chevron.right").foregroundStyle(palette.tertiaryText)
                        }
                        .font(.subheadline.weight(.medium))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct TopicReportView: View {
    let exam: ExamID
    let history: [String: QuestionHistory]
    let start: (String, [Question]) -> Void
    @Environment(\.palette) private var palette
    private let library = ContentLibrary.shared

    var body: some View {
        let scores = TopicScore.scores(for: library.questions(for: exam), history: history)
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                Text("Accuracy across every attempt, by official section. Tap a topic to practice it.")
                    .font(.subheadline)
                    .foregroundStyle(palette.secondaryText)
                ForEach(library.domains(for: exam)) { domain in
                    let topics = scores.filter { $0.domain == domain.id }
                    if !topics.isEmpty {
                        SectionTitle(title: domain.name)
                        Panel {
                            VStack(spacing: 12) {
                                ForEach(topics) { score in
                                    Button {
                                        start(score.topic, QuizBuilder.topicDrill([score], exam: exam, count: 15, library: library, history: history))
                                    } label: {
                                        TopicScoreRow(score: score)
                                    }
                                    .buttonStyle(.plain)
                                    if score.id != topics.last?.id { Divider() }
                                }
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .pettyScreen()
        .navigationTitle("Topic Report")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct TopicScoreRow: View {
    let score: TopicScore
    @Environment(\.palette) private var palette

    var body: some View {
        let judged = score.attempts >= TopicScore.minimumAttempts
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(score.topic).font(.subheadline.weight(.medium)).foregroundStyle(palette.text)
                Spacer()
                Text(judged ? score.accuracy.formatted(.percent.precision(.fractionLength(0))) : "\(score.attempts) tries")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(palette.secondaryText)
            }
            MeterBar(value: judged ? score.accuracy : 0, tint: score.accuracy >= 0.75 ? .green : palette.accent)
            Text("\(score.questionCount) questions · \(score.attempts) attempts")
                .font(.caption2)
                .foregroundStyle(palette.tertiaryText)
        }
        .contentShape(Rectangle())
    }
}
