import SwiftData
import SwiftUI

struct PracticeView: View {
    @ObservedObject private var settings = StudySettings.shared
    @Query private var stats: [QuestionStat]
    @Query(sort: \QuizRecord.date, order: .reverse) private var records: [QuizRecord]
    @Environment(\.palette) private var palette
    @Environment(\.modelContext) private var context
    @State private var mockError: String?
    @State private var confirmingDiscard = false
    private let savedMocks = SavedMockExams.shared
    @State private var activeQuiz: QuizSession?
    @State private var domains: Set<String> = []
    @State private var difficulties: Set<Int> = []
    @State private var source = QuizConfig.Source.all
    @State private var count = 20
    @State private var timed = false
    @State private var choosingDrills = false
    @State private var trainer: Trainer?
    @State private var query = ""
    private let library = ContentLibrary.shared

    private var exam: ExamID { settings.exam }
    private var examInfo: Exam? { library.exam(exam) }
    private var history: [String: QuestionHistory] { stats.history }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    ExamSwitcher()
                    if query.trimmingCharacters(in: .whitespaces).isEmpty {
                        quickStart
                        MockReadinessPanel(readiness: MockReadiness(records: records, exam: examInfo), exam: exam)
                        trainers
                        WeakTopicsPanel(exam: exam, history: history) { start($0, $1) }
                        customBuilder
                        recentHistory
                    } else {
                        SearchResultsView(query: query, exam: exam, kind: .questions)
                    }
                }
                .padding()
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search questions: transposition, Dk/t, ANSI…")
            .tabScreen("Practice")
            .navigationDestination(for: GuideHit.self) { GuideView(domain: $0.domain, focus: $0.index) }
            .navigationDestination(for: TopicHit.self) { TopicView(topic: $0) }
        }
        .quizCover($activeQuiz)
        .alert("Saved mock", isPresented: Binding(get: { mockError != nil }, set: { if !$0 { mockError = nil } })) {
            Button("OK") { mockError = nil }
        } message: {
            Text(mockError ?? "")
        }
        .confirmationDialog("Discard the unreadable \(exam.shortLabel) mock?", isPresented: $confirmingDiscard, titleVisibility: .visible) {
            Button("Discard Saved Mock", role: .destructive) {
                do { try savedMocks.remove(exam) }
                catch { mockError = "The saved mock could not be removed. Please try again." }
            }
        }
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
                if let saved = savedMocks.sessions[exam] {
                    TimelineView(.periodic(from: .now, by: 1)) { time in
                        let expired = saved.remainingSeconds(at: time.date) == 0
                        QuickAction(title: expired ? "View Mock Results" : "Resume Mock",
                                    subtitle: expired ? "Time expired" : "\(saved.answeredCount)/\(saved.questions.count) answered",
                                    symbol: expired ? "timer" : "play.fill") {
                            if saved.remainingSeconds(at: .now) == 0 { saved.finish(in: context) }
                            activeQuiz = saved
                        }
                        .accessibilityIdentifier("practice.resumeMock")
                    }
                } else if savedMocks.unreadable.contains(exam) {
                    QuickAction(title: "Saved Mock Unavailable", subtitle: "Review saved exam", symbol: "exclamationmark.triangle") {
                        confirmingDiscard = true
                    }
                } else {
                    QuickAction(title: "Mock Exam", subtitle: mockSubtitle, symbol: "timer") { startMock() }
                }
                let recheck = QuizBuilder.dueForReview(examQuestions, history: history)
                QuickAction(title: "Re-check Missed", subtitle: recheck.isEmpty ? "None due today" : "\(recheck.count) due today", symbol: "arrow.clockwise.circle") {
                    start("Re-check Missed", Array(recheck.prefix(30)))
                }
                .disabled(recheck.isEmpty)
                QuickAction(title: "Missed", subtitle: "\(missed.count) to retry", symbol: "arrow.counterclockwise") {
                    start("Missed Questions", Array(missed.shuffled().prefix(50)))
                }
                .disabled(missed.isEmpty)
                QuickAction(title: "Flagged", subtitle: "\(flagged.count) saved", symbol: "flag.fill") {
                    start("Flagged Questions", flagged.shuffled())
                }
                .disabled(flagged.isEmpty)
                if let info = examInfo, let weakest = QuizBuilder.weakestSection(info, library: library, history: history) {
                    QuickAction(title: "Weakest Section", subtitle: weakest.subtitle, symbol: "scope") {
                        start(weakest.domain.name, QuizBuilder.weakFirst(exam: exam, domain: weakest.domain.id, count: 15, library: library, history: history))
                    }
                }
                QuickAction(title: "Math Drills", subtitle: "Endless calculations", symbol: "function") { choosingDrills = true }
                QuickAction(title: "Picture Quiz", subtitle: "\(PictureQuiz.items(for: exam, library: library).count) photos & diagrams", symbol: "photo.on.rectangle") {
                    start("Picture Quiz", PictureQuiz.questions(exam: exam, count: 15, library: library))
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
    }

    private var trainers: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(title: "Hands-On Trainers")
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(Trainer.available(for: exam)) { item in
                    QuickAction(title: item.title, subtitle: item.subtitle, symbol: item.symbol) { trainer = item }
                }
            }
            NavigationLink { SimulatorLabView() } label: {
                LinkRow(title: "Online Simulators", subtitle: "Free web simulators and tools from other sites", symbol: "globe")
            }
            .buttonStyle(.plain)
        }
        .sheet(item: $trainer) { trainer in
            NavigationStack {
                trainer.screen
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { self.trainer = nil } } }
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
                        Text("Sections").font(.subheadline.weight(.semibold))
                        FlowLayout(spacing: 8) {
                            Button { domains = [] } label: {
                                Chip(text: "All · \(matching { $0.domains = [] })", selected: domains.isEmpty)
                            }
                            ForEach(library.domains(for: exam)) { domain in
                                Button { toggle(domain.id, in: &domains) } label: {
                                    Chip(text: "\(domain.name) · \(matching { $0.domains = [domain.id] })", selected: domains.contains(domain.id))
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Difficulty").font(.subheadline.weight(.semibold))
                        FlowLayout(spacing: 8) {
                            Button { difficulties = [] } label: {
                                Chip(text: "Any · \(matching { $0.difficulties = [] })", selected: difficulties.isEmpty)
                            }
                            ForEach([(1, "Recall"), (2, "Apply"), (3, "Multi-step")], id: \.0) { level, name in
                                Button { toggle(level, in: &difficulties) } label: {
                                    Chip(text: "\(name) · \(matching { $0.difficulties = [level] })", selected: difficulties.contains(level))
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Questions").font(.subheadline.weight(.semibold))
                        FlowLayout(spacing: 8) {
                            ForEach(QuizConfig.Source.allCases) { option in
                                Button { source = option } label: {
                                    Chip(text: "\(option.label) · \(matching { $0.source = option })", selected: source == option)
                                }
                                .accessibilityIdentifier("builder.source.\(option.rawValue)")
                            }
                        }
                        .buttonStyle(.plain)
                        Text(source.caption).font(.caption).foregroundStyle(palette.secondaryText)
                    }

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

    private var available: Int { matching { _ in } }

    /// How many questions the builder would draw from if one filter were changed.
    private func matching(_ change: (inout QuizConfig) -> Void) -> Int {
        var variant = config
        change(&variant)
        return QuizBuilder.pool(for: variant, library: library, history: history).count
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
        guard let info = examInfo, let minutes = info.timeMinutes else { return }
        let mock = QuizBuilder.mockExam(info, library: library)
        let config = QuizConfig(exam: exam, title: "\(info.shortName) Mock Exam", count: mock.questions.count,
                                timeLimitSeconds: minutes * 60, pretestIDs: mock.pretestIDs)
        do {
            activeQuiz = try savedMocks.begin(config: config, questions: mock.questions, flagged: stats.flaggedIDs)
        } catch {
            mockError = "The mock could not be saved on this device. Check available storage and try again."
        }
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
                let size = Self.size(of: subviews[index], maxWidth: bounds.width)
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

    /// Items wider than the container wrap their text instead of running past the edge.
    private static func size(of subview: LayoutSubview, maxWidth: CGFloat) -> CGSize {
        let natural = subview.sizeThatFits(.unspecified)
        return natural.width <= maxWidth ? natural : subview.sizeThatFits(ProposedViewSize(width: maxWidth, height: nil))
    }

    private func arrange(_ subviews: Subviews, width: CGFloat) -> [Row] {
        var rows: [Row] = [Row()]
        for index in subviews.indices {
            let size = Self.size(of: subviews[index], maxWidth: width)
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
