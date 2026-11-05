import SwiftData
import SwiftUI

extension View {
    func quizCover(_ session: Binding<QuizSession?>) -> some View {
        fullScreenCover(item: session) { QuizView(session: $0) }
    }
}

extension [QuestionStat] {
    var history: [String: QuestionHistory] {
        Dictionary(
            map { ($0.questionID, QuestionHistory(seen: $0.seen, correct: $0.correct, lastWasCorrect: $0.lastWasCorrect, flagged: $0.flagged, lastAnswered: $0.lastAnswered)) },
            uniquingKeysWith: { first, _ in first }
        )
    }

    var flaggedIDs: Set<String> { Set(filter(\.flagged).map(\.questionID)) }
}

struct QuizView: View {
    @Bindable var session: QuizSession
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(\.palette) private var palette
    @State private var confirmingExit = false
    @State private var sheet: QuizSheet?

    private enum QuizSheet: String, Identifiable {
        case navigator, review, calculator
        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            Group {
                if let record = session.record {
                    QuizResultsView(session: session, record: record)
                } else {
                    questionScreen
                }
            }
            .pettyScreen()
            .toolbar { toolbar }
            .navigationBarTitleDisplayMode(.inline)
        }
        .confirmationDialog("Leave this quiz?", isPresented: $confirmingExit, titleVisibility: .visible) {
            if session.answeredCount > 0 {
                Button("End & Save Results") { session.finish(in: context) }
            }
            Button("Discard", role: .destructive) { dismiss() }
        } message: {
            Text("\(session.answeredCount) of \(session.questions.count) answered.")
        }
        .sheet(item: $sheet) { sheet in
            switch sheet {
            case .navigator: navigator
            case .review: submitReview
            case .calculator: ExamCalculatorView().presentationDetents([.medium])
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            if session.isFinished {
                Button("Done") { dismiss() }.fontWeight(.semibold)
            } else {
                Button { confirmingExit = true } label: { Image(systemName: "xmark") }
                    .accessibilityLabel("Close quiz")
            }
        }
        ToolbarItem(placement: .principal) {
            if session.isFinished {
                Text("Results").font(.headline)
            } else {
                VStack(spacing: 0) {
                    Text("\(session.currentIndex + 1) of \(session.questions.count)")
                        .font(.headline.monospacedDigit())
                    if session.config.isTimed {
                        TimelineView(.periodic(from: .now, by: 1)) { context in
                            let remaining = session.remainingSeconds(at: context.date) ?? 0
                            Text(remaining.durationLabel)
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(remaining < 300 ? .red : palette.secondaryText)
                                .onChange(of: remaining) { _, value in
                                    if value == 0 { session.finish(in: self.context) }
                                }
                        }
                    }
                }
            }
        }
        ToolbarItemGroup(placement: .topBarTrailing) {
            if !session.isFinished {
                Button { session.toggleFlag() } label: {
                    Image(systemName: session.flagged.contains(session.current.id) ? "flag.fill" : "flag")
                }
                .accessibilityLabel("Flag question")
                Button { sheet = .calculator } label: { Image(systemName: "plus.forwardslash.minus") }
                    .accessibilityLabel("Calculator")
                Button { sheet = .navigator } label: { Image(systemName: "square.grid.3x3") }
                    .accessibilityLabel("Question navigator")
            }
        }
    }

    private var questionScreen: some View {
        VStack(spacing: 0) {
            MeterBar(value: Double(session.currentIndex + 1) / Double(session.questions.count))
                .padding(.horizontal)
                .padding(.top, 4)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    QuestionCard(session: session)
                        .id(session.currentIndex)
                        .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
                }
                .padding()
            }

            controls
        }
    }

    private var controls: some View {
        let index = session.currentIndex
        let last = index == session.questions.count - 1
        let canAdvance = !session.isPractice || session.isRevealed(index)
        return HStack(spacing: 12) {
            if !session.isPractice {
                Button {
                    withAnimation { session.currentIndex -= 1 }
                } label: {
                    Image(systemName: "chevron.left").frame(width: 44, height: 44)
                }
                .buttonStyle(.bordered)
                .disabled(index == 0)
            }
            Button {
                if last {
                    if session.isPractice { session.finish(in: context) } else { sheet = .review }
                } else {
                    withAnimation(.snappy) { session.currentIndex += 1 }
                }
            } label: {
                Text(last ? (session.isPractice ? "See Results" : "Submit Exam") : "Next")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canAdvance)
            .accessibilityIdentifier("quiz.next")
        }
        .padding()
        .background(.ultraThinMaterial)
    }

    private var navigator: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 6), spacing: 10) {
                    ForEach(session.questions.indices, id: \.self) { index in
                        Button {
                            session.currentIndex = index
                            sheet = nil
                        } label: {
                            navigatorCell(index)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
            .navigationTitle("Questions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Close") { sheet = nil } }
                if !session.isPractice {
                    ToolbarItem(placement: .bottomBar) {
                        Button("Review & Submit (\(session.answeredCount)/\(session.questions.count) answered)") { sheet = .review }
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var submitReview: some View {
        let unanswered = session.unansweredCount
        let flagged = session.questions.filter { session.flagged.contains($0.id) }.count
        return NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    StatTile(value: "\(session.answeredCount)", label: "Answered", symbol: "checkmark.circle")
                    StatTile(value: "\(unanswered)", label: "Unanswered", symbol: "circle.dashed")
                    StatTile(value: "\(flagged)", label: "Flagged", symbol: "flag")
                }
                Text(unanswered > 0
                     ? "Unanswered items are scored incorrect, and there is no penalty for guessing. Answer every question before you submit."
                     : "Every question has an answer. Check your flagged items, then submit.")
                    .font(.subheadline)
                    .foregroundStyle(palette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                if let first = session.firstIndex(where: { session.selections[$0] == nil }) {
                    Button("Go to first unanswered (#\(first + 1))") { jump(to: first) }.buttonStyle(.bordered)
                }
                if let first = session.firstIndex(where: { session.flagged.contains(session.questions[$0].id) }) {
                    Button("Go to first flagged (#\(first + 1))") { jump(to: first) }.buttonStyle(.bordered)
                }
                Spacer()
                Button {
                    sheet = nil
                    session.finish(in: context)
                } label: {
                    Text("Submit Exam").font(.headline).frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("quiz.submit")
            }
            .padding()
            .navigationTitle("Before You Submit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Keep Working") { sheet = nil } } }
        }
        .presentationDetents([.medium, .large])
    }

    private func jump(to index: Int) {
        session.currentIndex = index
        sheet = nil
    }

    private func navigatorCell(_ index: Int) -> some View {
        let answered = session.selections[index] != nil
        let flagged = session.flagged.contains(session.questions[index].id)
        let fill: Color = if session.isPractice && session.isRevealed(index) {
            session.isCorrect(index) ? .green.opacity(0.7) : .red.opacity(0.7)
        } else if answered {
            palette.accent.opacity(0.8)
        } else {
            palette.secondaryText.opacity(0.15)
        }
        return Text("\(index + 1)")
            .font(.subheadline.weight(.semibold).monospacedDigit())
            .frame(maxWidth: .infinity, minHeight: 40)
            .foregroundStyle(answered ? .white : palette.text)
            .background(RoundedRectangle(cornerRadius: 10).fill(fill))
            .overlay(alignment: .topTrailing) {
                if flagged {
                    Image(systemName: "flag.fill").font(.system(size: 9)).foregroundStyle(.yellow).padding(3)
                }
            }
            .overlay {
                if index == session.currentIndex {
                    RoundedRectangle(cornerRadius: 10).strokeBorder(palette.text, lineWidth: 2)
                }
            }
    }
}

struct QuestionCard: View {
    let session: QuizSession
    @Environment(\.palette) private var palette
    private let library = ContentLibrary.shared

    var body: some View {
        let question = session.current
        let index = session.currentIndex
        let revealed = session.isPractice && session.isRevealed(index)
        let selection = session.selections[index]

        VStack(alignment: .leading, spacing: 16) {
            // Timed exams hide section and topic, which the real exam doesn't show.
            if !session.config.isTimed {
                HStack(spacing: 6) {
                    Chip(text: library.domainName(question.domain))
                    Chip(text: question.topic)
                    Spacer()
                    DifficultyDots(level: question.difficulty)
                }
            }

            Text(question.stem)
                .font(.title3.weight(.semibold))
                .foregroundStyle(palette.text)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 10) {
                ForEach(Array(question.choices.enumerated()), id: \.offset) { choiceIndex, choice in
                    ChoiceButton(
                        letter: String(UnicodeScalar(UInt8(65 + choiceIndex))),
                        text: choice,
                        state: choiceState(choiceIndex, question: question, selection: selection, revealed: revealed)
                    ) {
                        withAnimation(.snappy) { session.select(choiceIndex) }
                    }
                    .accessibilityIdentifier("choice.\(choiceIndex)")
                }
            }

            if revealed {
                ExplanationPanel(correct: selection == question.answer, explanation: question.explanation)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                QuestionExtras(question: question)
            }
        }
    }

    private func choiceState(_ choice: Int, question: Question, selection: Int?, revealed: Bool) -> ChoiceButton.State {
        if revealed {
            if choice == question.answer { return .correct }
            if choice == selection { return .incorrect }
            return .dimmed
        }
        return choice == selection ? .selected : .idle
    }
}

struct ChoiceButton: View {
    enum State { case idle, selected, correct, incorrect, dimmed }

    let letter: String
    let text: String
    let state: State
    let action: () -> Void
    @Environment(\.palette) private var palette

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                Text(letter)
                    .font(.subheadline.weight(.bold))
                    .frame(width: 28, height: 28)
                    .foregroundStyle(badgeForeground)
                    .background(Circle().fill(tint.opacity(state == .idle || state == .dimmed ? 0.15 : 1)))
                Text(text)
                    .font(.body)
                    .foregroundStyle(palette.text)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                if state == .correct { Image(systemName: "checkmark.circle.fill").foregroundStyle(.green) }
                if state == .incorrect { Image(systemName: "xmark.circle.fill").foregroundStyle(.red) }
            }
            .padding(14)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(palette.cardBackground)
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(tint.opacity(state == .idle || state == .dimmed ? 0 : 0.9), lineWidth: 2)
                    }
            }
            .opacity(state == .dimmed ? 0.55 : 1)
        }
        .buttonStyle(.plain)
    }

    private var tint: Color {
        switch state {
        case .correct: .green
        case .incorrect: .red
        case .selected: palette.accent
        case .idle, .dimmed: palette.secondaryText
        }
    }

    private var badgeForeground: Color {
        state == .idle || state == .dimmed ? palette.text : .white
    }
}

struct ExplanationPanel: View {
    let correct: Bool
    let explanation: String
    @Environment(\.palette) private var palette

    var body: some View {
        Panel {
            VStack(alignment: .leading, spacing: 8) {
                Label(correct ? "Correct" : "Not quite", systemImage: correct ? "checkmark.seal.fill" : "lightbulb.fill")
                    .font(.headline)
                    .foregroundStyle(correct ? .green : palette.accent)
                RichText(text: explanation)
            }
        }
    }
}

struct DifficultyDots: View {
    let level: Int
    @Environment(\.palette) private var palette

    var body: some View {
        HStack(spacing: 3) {
            ForEach(1...3, id: \.self) { i in
                Circle()
                    .fill(i <= level ? palette.accent : palette.secondaryText.opacity(0.25))
                    .frame(width: 6, height: 6)
            }
        }
        .accessibilityLabel("Difficulty \(level) of 3")
    }
}
