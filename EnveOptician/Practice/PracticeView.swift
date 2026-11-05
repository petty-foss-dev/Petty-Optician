import SwiftData
import SwiftUI

struct PracticeView: View {
    @ObservedObject private var settings = StudySettings.shared
    @Query private var stats: [QuestionStat]
    @Query(sort: \QuizRecord.date, order: .reverse) private var records: [QuizRecord]
    @Environment(\.palette) private var palette
    @State private var activeQuiz: QuizSession?
    @State private var domains: Set<String> = []
    @State private var difficulties: Set<Int> = []
    @State private var source = QuizConfig.Source.all
    @State private var count = 20
    @State private var timed = false
    @State private var choosingDrills = false
    @State private var showingLensometer = false
    private let library = ContentLibrary.shared

    private var exam: ExamID { settings.exam }
    private var examInfo: Exam? { library.exam(exam) }
    private var history: [String: QuestionHistory] { stats.history }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    ExamSwitcher()
                    quickStart
                    customBuilder
                    recentHistory
                }
                .padding()
            }
            .tabScreen("Practice")
        }
        .quizCover($activeQuiz)
        .onChange(of: settings.exam) { domains = [] }
    }

    private var quickStart: some View {
        let examQuestions = library.questions(for: exam)
        let missed = examQuestions.filter { history[$0.id].map { $0.seen > 0 && !$0.lastWasCorrect } ?? false }
        let flagged = examQuestions.filter { history[$0.id]?.flagged ?? false }

        return VStack(alignment: .leading, spacing: 10) {
            SectionTitle(title: "Quick Start", trailing: "\(examQuestions.count) questions")
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                QuickAction(title: "Quick 10", subtitle: "Weak spots first", symbol: "bolt.fill") {
                    start("Quick 10", QuizBuilder.weakFirst(exam: exam, count: 10, library: library, history: history))
                }
                QuickAction(title: "Mock Exam", subtitle: mockSubtitle, symbol: "timer") { startMock() }
                QuickAction(title: "Missed", subtitle: "\(missed.count) to retry", symbol: "arrow.counterclockwise") {
                    start("Missed Questions", Array(missed.shuffled().prefix(50)))
                }
                .disabled(missed.isEmpty)
                QuickAction(title: "Flagged", subtitle: "\(flagged.count) saved", symbol: "flag.fill") {
                    start("Flagged Questions", flagged.shuffled())
                }
                .disabled(flagged.isEmpty)
                QuickAction(title: "Math Drills", subtitle: "Endless calculations", symbol: "function") { choosingDrills = true }
                if exam == .abo {
                    QuickAction(title: "Lensometer", subtitle: "Read lenses by hand", symbol: "scope") { showingLensometer = true }
                }
            }
        }
        .sheet(isPresented: $choosingDrills) {
            DrillPicker(exam: exam) { questions in
                choosingDrills = false
                start("Math Drills", questions)
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showingLensometer) {
            NavigationStack {
                LensometerTrainerView()
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showingLensometer = false } } }
            }
        }
    }

    private var mockSubtitle: String {
        guard let info = examInfo else { return "Full length" }
        let n = info.totalQuestions.map(String.init) ?? "Full"
        let t = info.timeMinutes.map { " · \($0) min" } ?? ""
        return "\(n) q\(t)"
    }

    private var customBuilder: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(title: "Build a Quiz")
            Panel {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Domains").font(.subheadline.weight(.semibold))
                        FlowLayout(spacing: 8) {
                            Button { domains = [] } label: { Chip(text: "All", selected: domains.isEmpty) }
                            ForEach(library.domains(for: exam)) { domain in
                                Button { toggle(domain.id, in: &domains) } label: {
                                    Chip(text: domain.name, selected: domains.contains(domain.id))
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Difficulty").font(.subheadline.weight(.semibold))
                        HStack(spacing: 8) {
                            Button { difficulties = [] } label: { Chip(text: "Any", selected: difficulties.isEmpty) }
                            ForEach([(1, "Recall"), (2, "Apply"), (3, "Multi-step")], id: \.0) { level, name in
                                Button { toggle(level, in: &difficulties) } label: {
                                    Chip(text: name, selected: difficulties.contains(level))
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }

                    Picker("Questions from", selection: $source) {
                        ForEach(QuizConfig.Source.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    Stepper(value: $count, in: 5...150, step: 5) {
                        Text("**\(count)** questions · \(available) available")
                    }

                    Toggle(isOn: $timed) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Exam mode")
                            Text(timed ? "Timed at exam pace (\(timedMinutes) min), answers at the end" : "Instant feedback after each answer")
                                .font(.caption)
                                .foregroundStyle(palette.secondaryText)
                        }
                    }

                    Button(action: startCustom) {
                        Text("Start Quiz").font(.headline).frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(available == 0)
                    .accessibilityIdentifier("practice.start")
                }
            }
        }
    }

    @ViewBuilder
    private var recentHistory: some View {
        let recent = records.filter { $0.exam == exam }.prefix(8)
        if !recent.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                SectionTitle(title: "History")
                Panel {
                    VStack(spacing: 12) {
                        ForEach(Array(recent)) { record in
                            RecordRow(record: record)
                            if record.id != recent.last?.id { Divider() }
                        }
                    }
                }
            }
        }
    }

    private var config: QuizConfig {
        QuizConfig(
            exam: exam,
            title: domains.count == 1 ? library.domainName(domains.first!) : "Custom Quiz",
            domains: domains,
            count: count,
            difficulties: difficulties,
            source: source,
            timeLimitSeconds: timed ? timedMinutes * 60 : nil
        )
    }

    private var available: Int {
        var unlimited = config
        unlimited.count = .max
        return QuizBuilder.questions(for: unlimited, library: library, history: history).count
    }

    private var timedMinutes: Int {
        let perQuestion = examInfo.flatMap { info in
            info.timeMinutes.flatMap { minutes in info.totalQuestions.map { Double(minutes) / Double($0) } }
        } ?? 1
        return max(1, Int((Double(min(count, available)) * perQuestion).rounded(.up)))
    }

    private func startCustom() {
        start(config.title, QuizBuilder.questions(for: config, library: library, history: history), timeLimit: config.timeLimitSeconds)
    }

    private func startMock() {
        guard let info = examInfo else { return }
        start(
            "\(info.shortName) Mock Exam",
            QuizBuilder.mockExam(info, library: library),
            timeLimit: info.timeMinutes.map { $0 * 60 }
        )
    }

    private func start(_ title: String, _ questions: [Question], timeLimit: Int? = nil) {
        guard !questions.isEmpty else { return }
        let config = QuizConfig(exam: exam, title: title, count: questions.count, timeLimitSeconds: timeLimit)
        activeQuiz = QuizSession(config: config, questions: questions, flagged: stats.flaggedIDs)
    }

    private func toggle<T: Hashable>(_ value: T, in set: inout Set<T>) {
        if set.contains(value) { set.remove(value) } else { set.insert(value) }
    }
}

struct QuickAction: View {
    let title: String
    let subtitle: String
    let symbol: String
    let action: () -> Void
    @Environment(\.palette) private var palette
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            Panel(padding: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    Image(systemName: symbol)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(palette.accent)
                    Text(title).font(.headline).foregroundStyle(palette.text)
                    Text(subtitle).font(.caption).foregroundStyle(palette.secondaryText)
                }
            }
            .opacity(isEnabled ? 1 : 0.5)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("quick.\(title.lowercased().replacingOccurrences(of: " ", with: "-"))")
    }
}

struct RecordRow: View {
    let record: QuizRecord
    @Environment(\.palette) private var palette

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: record.isTimedExam ? "timer" : "checklist")
                .foregroundStyle(palette.accent)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(record.title).font(.subheadline.weight(.medium))
                Text(record.date, format: .dateTime.month().day().hour().minute())
                    .font(.caption)
                    .foregroundStyle(palette.secondaryText)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(record.percent, format: .percent.precision(.fractionLength(0)))
                    .font(.subheadline.weight(.bold).monospacedDigit())
                    .foregroundStyle(record.percent >= 0.75 ? .green : palette.text)
                Text("\(record.correct)/\(record.total)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(palette.secondaryText)
            }
        }
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(subviews, width: proposal.width ?? .infinity)
        let height = rows.map(\.height).reduce(0, +) + spacing * CGFloat(max(0, rows.count - 1))
        let width = rows.map(\.width).max() ?? 0
        return CGSize(width: proposal.width ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(subviews, width: bounds.width) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(_ subviews: Subviews, width: CGFloat) -> [Row] {
        var rows: [Row] = [Row()]
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let needed = rows[rows.count - 1].indices.isEmpty ? size.width : rows[rows.count - 1].width + spacing + size.width
            if needed > width, !rows[rows.count - 1].indices.isEmpty {
                rows.append(Row())
            }
            let isFirst = rows[rows.count - 1].indices.isEmpty
            rows[rows.count - 1].indices.append(index)
            rows[rows.count - 1].width += (isFirst ? 0 : spacing) + size.width
            rows[rows.count - 1].height = max(rows[rows.count - 1].height, size.height)
        }
        return rows
    }
}
