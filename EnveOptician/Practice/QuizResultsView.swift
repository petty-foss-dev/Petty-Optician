import SwiftData
import SwiftUI

struct QuizResultsView: View {
    let session: QuizSession
    let record: QuizRecord
    @Environment(\.palette) private var palette
    @State private var retry: QuizSession?
    @State private var reviewFilter = ReviewFilter.missed
    private let library = ContentLibrary.shared

    private enum ReviewFilter: String, CaseIterable, Identifiable {
        case missed = "Missed", all = "All"
        var id: String { rawValue }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                scoreHeader
                if !record.breakdown.isEmpty { breakdown }
                if !record.missedIDs.isEmpty { retryButton }
                review
            }
            .padding()
        }
        .quizCover($retry)
    }

    private var scoreHeader: some View {
        Panel {
            HStack(spacing: 20) {
                ZStack {
                    ProgressRing(progress: record.percent, lineWidth: 12)
                    Text(record.percent, format: .percent.precision(.fractionLength(0)))
                        .font(.title2.weight(.bold).monospacedDigit())
                }
                .frame(width: 96, height: 96)

                VStack(alignment: .leading, spacing: 6) {
                    Text(record.title).font(.headline)
                    Text("\(record.correct) of \(record.total) correct")
                        .foregroundStyle(palette.secondaryText)
                    Label(record.seconds.durationLabel, systemImage: "clock")
                        .font(.subheadline)
                        .foregroundStyle(palette.secondaryText)
                    Text(verdict)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(record.percent >= 0.75 ? .green : palette.accent)
                }
            }
        }
    }

    private var verdict: String {
        switch record.percent {
        case 0.85...: "Exam-ready on this set"
        case 0.75..<0.85: "Solid — keep sharpening"
        case 0.6..<0.75: "Getting there"
        default: "Review the guides for these topics"
        }
    }

    private var breakdown: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(title: "By Domain")
            Panel {
                VStack(spacing: 14) {
                    ForEach(record.breakdown, id: \.domain) { score in
                        let pct = score.total == 0 ? 0 : Double(score.correct) / Double(score.total)
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(library.domainName(score.domain)).font(.subheadline.weight(.medium))
                                Spacer()
                                Text("\(score.correct)/\(score.total)")
                                    .font(.subheadline.monospacedDigit())
                                    .foregroundStyle(palette.secondaryText)
                            }
                            MeterBar(value: pct, tint: pct >= 0.75 ? .green : palette.accent)
                        }
                    }
                }
            }
        }
    }

    private var retryButton: some View {
        Button {
            let missed = Set(record.missedIDs)
            let questions = session.questions.filter { missed.contains($0.id) }.shuffled()
            var config = session.config
            config.title = "Retry Missed"
            config.timeLimitSeconds = nil
            retry = QuizSession(config: config, questions: questions, flagged: session.flagged)
        } label: {
            Label("Retry \(record.missedIDs.count) Missed", systemImage: "arrow.counterclockwise")
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.borderedProminent)
    }

    private var review: some View {
        let indices = session.questions.indices.filter { index in
            session.selections[index] != nil || !session.isPractice
        }
        let shown = reviewFilter == .all ? indices : indices.filter { !session.isCorrect($0) }

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionTitle(title: "Review")
                Picker("Show", selection: $reviewFilter) {
                    ForEach(ReviewFilter.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .frame(width: 160)
            }
            if shown.isEmpty {
                Panel { Text("Nothing missed — nice work.").foregroundStyle(palette.secondaryText) }
            }
            ForEach(shown, id: \.self) { index in
                ReviewRow(question: session.questions[index], selection: session.selections[index], number: index + 1)
            }
        }
    }
}

private struct ReviewRow: View {
    let question: Question
    let selection: Int?
    let number: Int
    @State private var expanded = false
    @Environment(\.palette) private var palette

    var body: some View {
        let correct = selection == question.answer
        Panel {
            VStack(alignment: .leading, spacing: 10) {
                Button {
                    withAnimation(.snappy) { expanded.toggle() }
                } label: {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: correct ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(correct ? .green : .red)
                        Text("\(number). \(question.stem)")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(palette.text)
                            .multilineTextAlignment(.leading)
                            .lineLimit(expanded ? nil : 2)
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.down")
                            .rotationEffect(.degrees(expanded ? 180 : 0))
                            .foregroundStyle(palette.tertiaryText)
                    }
                }
                .buttonStyle(.plain)

                if expanded {
                    VStack(alignment: .leading, spacing: 6) {
                        if let selection, !correct {
                            Text("Your answer: \(question.choices[selection])")
                                .font(.subheadline)
                                .foregroundStyle(.red)
                        } else if selection == nil {
                            Text("Not answered").font(.subheadline).foregroundStyle(.red)
                        }
                        Text("Correct: \(question.choices[question.answer])")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.green)
                        RichText(text: question.explanation)
                            .font(.subheadline)
                        QuestionExtras(question: question)
                    }
                }
            }
        }
    }
}
