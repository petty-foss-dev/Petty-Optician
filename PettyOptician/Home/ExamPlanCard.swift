import SwiftUI

struct ExamPlanCard: View {
    let dueCards: Int
    @ObservedObject private var settings = StudySettings.shared
    @ObservedObject private var reading = ReadingProgress.shared
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
        let lessons = Textbook.shared.lessons(for: settings.exam)
        let remaining = lessons.count { !reading.completed.contains($0.id) }
        guard remaining > 0 else {
            return "Textbook complete. Review missed questions and \(dueCards) due cards."
        }
        let done = reading.readLessons(in: lessons).count
        let target = (remaining + done + days - 1) / days
        return "\(done) of \(target) \(target == 1 ? "lesson" : "lessons") read today · \(remaining) left before exam day."
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
                    Text("A daily reminder to read and review.")
                }
            }
            .navigationTitle("Study Plan")
            .navigationBarTitleDisplayMode(.inline)
    }
}
