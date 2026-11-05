import SwiftUI

struct ExamPlanCard: View {
    let unseen: Int
    let dueCards: Int
    @ObservedObject private var settings = StudySettings.shared
    @State private var editing = false
    @Environment(\.palette) private var palette

    var body: some View {
        let exam = settings.exam
        Button { editing = true } label: {
            Panel(padding: 16) {
                if let days = settings.daysUntilExam(exam), days >= 0 {
                    HStack(alignment: .center, spacing: 16) {
                        VStack(spacing: 0) {
                            Text("\(days)")
                                .font(.system(size: 34, weight: .bold).monospacedDigit())
                                .foregroundStyle(palette.accent)
                            Text(days == 1 ? "day" : "days").font(.caption).foregroundStyle(palette.secondaryText)
                        }
                        .frame(minWidth: 64)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("until your \(exam.shortLabel) exam").font(.headline).foregroundStyle(palette.text)
                            Text(plan(days: days)).font(.subheadline).foregroundStyle(palette.secondaryText)
                                .multilineTextAlignment(.leading)
                        }
                        Spacer(minLength: 0)
                    }
                } else {
                    HStack(spacing: 14) {
                        Image(systemName: "calendar.badge.plus").font(.title2).foregroundStyle(palette.accent)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Set your \(exam.shortLabel) exam date").font(.headline).foregroundStyle(palette.text)
                            Text("Get a countdown, a daily target and study reminders.")
                                .font(.subheadline).foregroundStyle(palette.secondaryText)
                        }
                        Spacer(minLength: 0)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("plan.card")
        .sheet(isPresented: $editing) {
            NavigationStack {
                StudyPlanSettings()
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { editing = false } } }
            }
            .presentationDetents([.medium, .large])
        }
    }

    private func plan(days: Int) -> String {
        guard days > 0 else { return "Exam day. Skim the formula sheet and get some rest." }
        let perDay = Int((Double(unseen) / Double(days)).rounded(.up))
        let mock = days <= 14 ? " Take a full mock exam every few days." : ""
        if unseen == 0 { return "Every question seen. Review missed questions and \(dueCards) due cards.\(mock)" }
        return "Aim for \(perDay) new questions a day to see all \(unseen) remaining.\(mock)"
    }
}

struct StudyPlanSettings: View {
    @ObservedObject private var settings = StudySettings.shared

    var body: some View {
            Form {
                ForEach(ExamID.allCases) { exam in
                    Section("\(exam.shortLabel) exam date") {
                        let binding = Binding<Bool>(
                            get: { settings.examDate(for: exam) != nil },
                            set: { settings.setExamDate($0 ? Calendar.current.date(byAdding: .day, value: 60, to: .now) : nil, for: exam) }
                        )
                        Toggle("Scheduled", isOn: binding)
                        if let date = settings.examDate(for: exam) {
                            DatePicker("Date", selection: Binding(get: { date }, set: { settings.setExamDate($0, for: exam) }), in: Date.now..., displayedComponents: .date)
                        }
                    }
                }
                Section {
                    Toggle("Daily reminder", isOn: $settings.reminderEnabled)
                    if settings.reminderEnabled {
                        DatePicker("Time", selection: $settings.reminderTime, displayedComponents: .hourAndMinute)
                    }
                } footer: {
                    Text("A notification each day with your countdown and what's due.")
                }
            }
            .navigationTitle("Study Plan")
            .navigationBarTitleDisplayMode(.inline)
    }
}
