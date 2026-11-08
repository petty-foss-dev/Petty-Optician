import Charts
import SwiftData
import SwiftUI

/// ABO-NCLE sets each form's pass mark by Modified Angoff and doesn't publish it, so readiness uses a fixed margin:
/// three full-length mocks in a row at 75% or better.
struct MockReadiness {
    static let target = 0.75
    static let streakNeeded = 3

    /// Newest first.
    let mocks: [QuizRecord]

    init(records: [QuizRecord], exam: Exam?) {
        let fullLength = exam?.scoredQuestions ?? exam?.totalQuestions ?? 100
        mocks = records
            .filter { $0.exam == exam?.id && $0.isTimedExam && $0.total >= fullLength }
            .sorted { $0.date > $1.date }
    }

    var passingStreak: Int { mocks.prefix { $0.percent >= Self.target }.count }

    var isReady: Bool { passingStreak >= Self.streakNeeded }

    var summary: String {
        if mocks.isEmpty { return "No full-length mock exams yet" }
        if isReady { return "Ready: \(Self.streakNeeded) passing mocks in a row" }
        return "\(min(passingStreak, Self.streakNeeded)) of \(Self.streakNeeded) passing mocks in a row"
    }

    /// A section is ready once it cleared the target in each of the last three mocks.
    func isReady(_ domain: String) -> Bool {
        let recent = mocks.prefix(Self.streakNeeded)
        guard recent.count == Self.streakNeeded else { return false }
        return recent.allSatisfy { record in
            record.breakdown.first { $0.domain == domain }.map { $0.total > 0 && Double($0.correct) / Double($0.total) >= Self.target } ?? false
        }
    }
}

struct MockReadinessPanel: View {
    let readiness: MockReadiness
    let exam: ExamID
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(title: "Exam Readiness")
            Panel {
                VStack(alignment: .leading, spacing: 12) {
                    let latest = Array(readiness.mocks.prefix(MockReadiness.streakNeeded).reversed())
                    HStack(spacing: 8) {
                        ForEach(0..<MockReadiness.streakNeeded, id: \.self) { slot in
                            MockPill(record: slot < latest.count ? latest[slot] : nil)
                        }
                    }
                    Text(readiness.summary).font(.headline).foregroundStyle(readiness.isReady ? .green : palette.text)
                    Text("Take full-length mock exams. Three in a row at \(MockReadiness.target.formatted(.percent)) or better means you're likely ready; ABO-NCLE doesn't publish its pass mark, so this leaves a margin.")
                        .font(.caption)
                        .foregroundStyle(palette.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    if !readiness.mocks.isEmpty {
                        NavigationLink { MockHistoryView(readiness: readiness, exam: exam) } label: {
                            HStack {
                                Text("Mock exam history by section")
                                Spacer()
                                Image(systemName: "chevron.right").foregroundStyle(palette.tertiaryText)
                            }
                            .font(.subheadline.weight(.medium))
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("readiness.history")
                    }
                }
            }
        }
    }
}

private struct MockPill: View {
    let record: QuizRecord?
    @Environment(\.palette) private var palette

    var body: some View {
        let passed = record.map { $0.percent >= MockReadiness.target }
        HStack(spacing: 4) {
            Image(systemName: passed == true ? "checkmark.circle.fill" : passed == false ? "xmark.circle.fill" : "circle.dashed")
            Text(record.map { $0.percent.formatted(.percent.precision(.fractionLength(0))) } ?? "—")
                .monospacedDigit()
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(passed == true ? .green : passed == false ? .red : palette.tertiaryText)
        .frame(maxWidth: .infinity, minHeight: 36)
        .background(Capsule().fill(palette.secondaryText.opacity(0.1)))
    }
}

struct MockHistoryView: View {
    let readiness: MockReadiness
    let exam: ExamID
    @Environment(\.palette) private var palette
    private let library = ContentLibrary.shared

    var body: some View {
        let chronological = Array(readiness.mocks.prefix(10).reversed())
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SectionTitle(title: "Scores", trailing: "last \(chronological.count)")
                Panel { scoreChart(chronological) }

                SectionTitle(title: "By Section", trailing: "last \(min(5, chronological.count)) mocks")
                Panel {
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(library.domains(for: exam)) { domain in
                            sectionRow(domain, records: Array(chronological.suffix(5)))
                        }
                    }
                }

                SectionTitle(title: "All Mocks", trailing: "\(readiness.mocks.count)")
                Panel {
                    VStack(spacing: 12) {
                        ForEach(readiness.mocks) { record in
                            RecordRow(record: record)
                            if record.id != readiness.mocks.last?.id { Divider() }
                        }
                    }
                }
            }
            .padding()
        }
        .pettyScreen()
        .navigationTitle("Mock Exams")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func scoreChart(_ records: [QuizRecord]) -> some View {
        Chart {
            ForEach(Array(records.enumerated()), id: \.element.id) { index, record in
                LineMark(x: .value("Mock", index + 1), y: .value("Score", record.percent))
                    .foregroundStyle(palette.accent)
                PointMark(x: .value("Mock", index + 1), y: .value("Score", record.percent))
                    .foregroundStyle(record.percent >= MockReadiness.target ? Color.green : Color.red)
            }
            RuleMark(y: .value("Target", MockReadiness.target))
                .foregroundStyle(palette.secondaryText)
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                .annotation(position: .top, alignment: .leading) {
                    Text("Target \(MockReadiness.target.formatted(.percent))").font(.caption2).foregroundStyle(palette.secondaryText)
                }
        }
        .chartYScale(domain: 0...1)
        .chartXScale(domain: 1...max(2, records.count))
        .chartYAxis {
            AxisMarks(values: [0, 0.25, 0.5, 0.75, 1]) { _ in
                AxisGridLine()
                AxisValueLabel(format: FloatingPointFormatStyle<Double>.Percent())
            }
        }
        .chartXAxis { AxisMarks(values: .stride(by: 1)) { _ in AxisValueLabel() } }
        .frame(height: 200)
    }

    private func sectionRow(_ domain: ExamDomain, records: [QuizRecord]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(domain.name).font(.subheadline.weight(.medium)).foregroundStyle(palette.text)
                Spacer()
                if readiness.isReady(domain.id) {
                    Label("Ready", systemImage: "checkmark.seal.fill").font(.caption.weight(.bold)).foregroundStyle(.green)
                }
            }
            HStack(spacing: 6) {
                ForEach(records) { record in
                    let score = record.breakdown.first { $0.domain == domain.id }
                    let pct = score.flatMap { $0.total > 0 ? Double($0.correct) / Double($0.total) : nil }
                    Text(pct.map { $0.formatted(.percent.precision(.fractionLength(0))) } ?? "—")
                        .font(.caption.weight(.semibold).monospacedDigit())
                        .frame(maxWidth: .infinity, minHeight: 28)
                        .foregroundStyle(pct == nil ? palette.tertiaryText : .white)
                        .background(RoundedRectangle(cornerRadius: 8).fill(cellColor(pct)))
                }
            }
        }
    }

    private func cellColor(_ pct: Double?) -> Color {
        guard let pct else { return palette.secondaryText.opacity(0.1) }
        return pct >= MockReadiness.target ? .green.opacity(0.75) : .red.opacity(0.7)
    }
}
