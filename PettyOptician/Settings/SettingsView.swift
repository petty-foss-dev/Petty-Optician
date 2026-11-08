import SwiftData
import SwiftUI

struct SettingsView: View {
    @ObservedObject private var theme = ThemeManager.shared
    @ObservedObject private var settings = StudySettings.shared
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
                    NavigationLink { VoiceSettingsView() } label: {
                        LabeledContent("Listening voice", value: settings.supertonicVoice.map { "Supertonic \($0.rawValue)" } ?? "Apple")
                    }
                    .accessibilityIdentifier("settings.voice")
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
                    Text("Clears quiz history, flashcard scheduling, cards you made, flags, saved resources and your streak.")
                }

                Section {
                    NavigationLink { TipJarView() } label: {
                        Label("Tip Jar", systemImage: "heart.text.square")
                    }
                    .accessibilityIdentifier("settings.tipjar")
                } footer: {
                    Text("petty: Optician is free. If it helped you, you can say thanks with a tip.")
                }

                Section {
                    NavigationLink("Image Credits") { ImageCreditsView() }
                    Text("petty: Optician is an independent study aid. It is not affiliated with or endorsed by the American Board of Opticianry, the National Contact Lens Examiners, or the California State Board of Optometry. Practice questions are original and are not taken from the actual exams.")
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
        try? context.delete(model: PersonalCard.self)
        try? context.save()
        StudySettings.shared.resetStreak()
    }
}
