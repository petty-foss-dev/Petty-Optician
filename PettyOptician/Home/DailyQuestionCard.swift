import SwiftData
import SwiftUI

struct DailyQuestionCard: View {
    let exam: ExamID
    @ObservedObject private var settings = StudySettings.shared
    @Query private var stats: [QuestionStat]
    @Environment(\.modelContext) private var context
    @Environment(\.palette) private var palette
    @State private var speaker = Speaker()
    private let library = ContentLibrary.shared

    var body: some View {
        let entry = settings.dailyQuestion(for: exam)
        let question = entry.flatMap { library.question(id: $0.id) }
        VStack(alignment: .leading, spacing: 10) {
            if let question {
                SectionTitle(title: "Question of the Day", trailing: entry?.choice == nil ? nil : "Answered")
                Panel {
                    content(question, choice: entry?.choice)
                }
            }
        }
        .task(id: "\(exam.rawValue)|\(StudySettings.dayKey(.now))") {
            guard settings.dailyQuestion(for: exam) == nil,
                  let pick = QuizBuilder.dailyQuestion(from: library.questions(for: exam), history: stats.history, day: StudySettings.dayKey(.now))
            else { return }
            settings.setDailyQuestion(pick.id, choice: nil, for: exam)
        }
    }

    private func content(_ question: Question, choice: Int?) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                Chip(text: library.domainName(question.domain))
                Spacer()
                DifficultyDots(level: question.difficulty)
                Button {
                    if speaker.isSpeaking { speaker.stop() } else { Task { await speaker.say(Self.readAloud(question, choice: choice)) } }
                } label: {
                    Image(systemName: speaker.isSpeaking ? "stop.circle.fill" : "speaker.wave.2.circle")
                        .font(.title3)
                        .foregroundStyle(palette.accent)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(speaker.isSpeaking ? "Stop reading" : "Read aloud")
                .accessibilityIdentifier("daily.read")
            }
            Text(question.stem)
                .font(.headline)
                .foregroundStyle(palette.text)
                .fixedSize(horizontal: false, vertical: true)
            ForEach(Array(question.choices.enumerated()), id: \.offset) { index, text in
                ChoiceButton(letter: String(UnicodeScalar(UInt8(65 + index))), text: text, state: state(index, question: question, choice: choice)) {
                    answer(question, choice: index)
                }
                .accessibilityIdentifier("daily.choice.\(index)")
            }
            if let choice {
                ExplanationPanel(correct: choice == question.answer, explanation: question.explanation)
                QuestionExtras(question: question)
            }
        }
    }

    /// The question and choices, then the answer and explanation once it's been answered.
    static func readAloud(_ question: Question, choice: Int?) -> String {
        let letters = ["A", "B", "C", "D"]
        let choices = question.choices.enumerated().map { "\(letters[$0.offset]). \($0.element)." }.joined(separator: " ")
        guard choice != nil else { return "\(question.stem) \(choices)" }
        return "The answer is \(letters[question.answer]). \(question.choices[question.answer]). \(question.explanation)"
    }

    private func state(_ index: Int, question: Question, choice: Int?) -> ChoiceButton.State {
        guard let choice else { return .idle }
        if index == question.answer { return .correct }
        return index == choice ? .incorrect : .dimmed
    }

    private func answer(_ question: Question, choice: Int) {
        guard settings.dailyQuestion(for: exam)?.choice == nil else { return }
        withAnimation(.snappy) { settings.setDailyQuestion(question.id, choice: choice, for: exam) }
        let id = question.id
        let stat = (try? context.fetch(FetchDescriptor<QuestionStat>(predicate: #Predicate { $0.questionID == id })))?.first ?? {
            let created = QuestionStat(questionID: id)
            context.insert(created)
            return created
        }()
        stat.recordAnswer(correct: choice == question.answer)
        try? context.save()
        settings.recordStudy()
    }
}
