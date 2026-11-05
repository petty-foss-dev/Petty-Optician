import SwiftData
import SwiftUI

struct SettingsView: View {
    @ObservedObject private var theme = ThemeManager.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var confirmingReset = false
    private let library = ContentLibrary.shared

    var body: some View {
        NavigationStack {
            Form {
                Section("Appearance") {
                    Picker("Theme", selection: $theme.selectedTheme) {
                        ForEach(ThemeManager.AppTheme.allCases) { Text($0.rawValue).tag($0) }
                    }
                }

                Section("Study Plan") {
                    NavigationLink("Exam dates & reminders") { StudyPlanSettings() }
                }

                Section("Content") {
                    ForEach(ExamID.allCases) { exam in
                        LabeledContent(exam.shortLabel) {
                            Text("\(library.questions(for: exam).count) questions · \(library.flashcards(for: exam).count) cards")
                        }
                    }
                    LabeledContent("Study guides", value: "\(library.guides.count)")
                    LabeledContent("Library resources", value: "\(library.resources.count)")
                    LabeledContent("Diagrams & photos", value: "\(library.diagrams.count) · \(library.images.count)")
                }

                Section {
                    Button("Reset All Progress", role: .destructive) { confirmingReset = true }
                } footer: {
                    Text("Clears quiz history, flashcard scheduling, flags, saved resources and your streak.")
                }

                Section {
                    NavigationLink("Image Credits") { ImageCreditsView() }
                    Text("Enve Optician is an independent study aid. It is not affiliated with or endorsed by the American Board of Opticianry, the National Contact Lens Examiners, or the California State Board of Optometry. Practice questions are original and are not taken from the actual exams.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .confirmationDialog("Reset all progress?", isPresented: $confirmingReset, titleVisibility: .visible) {
                Button("Reset", role: .destructive, action: reset)
            } message: {
                Text("This can't be undone.")
            }
        }
    }

    private func reset() {
        try? context.delete(model: QuestionStat.self)
        try? context.delete(model: CardReview.self)
        try? context.delete(model: QuizRecord.self)
        try? context.delete(model: ResourceMark.self)
        try? context.save()
        StudySettings.shared.resetStreak()
    }
}
