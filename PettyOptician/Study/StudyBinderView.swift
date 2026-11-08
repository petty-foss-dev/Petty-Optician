import SwiftData
import SwiftUI

struct StudyBinderView: View {
    @ObservedObject private var settings = StudySettings.shared
    @Environment(\.palette) private var palette
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @AppStorage("pettyoptician.binder.reviewedLessons") private var reviewed = ""
    @AppStorage("pettyoptician.binder.hasSeenDedication") private var hasSeenDedication = false
    @State private var editing: NoteTarget?
    @State private var showingDedication = false

    private enum Route: Hashable { case notes, guides, page(String) }
    private let library = ContentLibrary.shared

    var body: some View {
        let exam = settings.exam
        let lessons = library.binderLessons.filter { $0.exam == exam }
        let reviewedIDs = Set(reviewed.split(separator: ",").map(String.init))

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    BinderCover()
                    ExamSwitcher()
                    dividers
                    crashCourse(lessons, reviewedIDs: reviewedIDs)
                }
                .padding()
            }
            .tabScreen("Binder")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .notes: NotesView()
                case .guides: StudyView()
                case .page(let id):
                    if let lesson = library.binderLessons.first(where: { $0.id == id }),
                       let index = library.binderLessons.filter({ $0.exam == lesson.exam }).firstIndex(where: { $0.id == id }) {
                        BinderLessonView(lesson: lesson, number: index + 1, reviewed: $reviewed)
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        editing = .quick(exam: exam)
                    } label: {
                        Label("Jot a note", systemImage: "square.and.pencil")
                    }
                    .accessibilityIdentifier("binder.newNote")
                }
            }
            .sheet(item: $editing) { NoteEditor(target: $0) }
            .onAppear {
                if !hasSeenDedication { showingDedication = true }
            }
            .alert("For Erin", isPresented: $showingDedication) {
                Button("Continue") { hasSeenDedication = true }
            } message: {
                Text("I named this binder after Erin, one of my amazing coworkers. Her notes and advice helped me and many others pass our exams. This binder is dedicated to her and the work she shared with us.")
            }
        }
    }

    private var dividers: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 8))
            : AnyLayout(HStackLayout(spacing: 8))
        return layout {
            NavigationLink(value: Route.notes) {
                BinderDivider(title: "My Notes", symbol: "note.text", color: .orange)
            }
            .accessibilityIdentifier("binder.notes")
            NavigationLink(value: Route.guides) {
                BinderDivider(title: "Exam Guides", symbol: "books.vertical", color: .indigo)
            }
            .accessibilityIdentifier("binder.guides")
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func crashCourse(_ lessons: [BinderLesson], reviewedIDs: Set<String>) -> some View {
        if !lessons.isEmpty {
            let reviewedCount = lessons.count { reviewedIDs.contains($0.id) }
            VStack(alignment: .leading, spacing: 10) {
                SectionTitle(title: "Crash Course", trailing: settings.exam.subject)
                ProgressView(value: Double(reviewedCount), total: Double(lessons.count)) {
                    Text("\(reviewedCount) of \(lessons.count) pages reviewed")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(palette.secondaryText)
                }
                .tint(palette.accent)
                .padding(.horizontal, 4)

                if let next = lessons.first(where: { !reviewedIDs.contains($0.id) }) {
                    NavigationLink(value: Route.page(next.id)) {
                        Label(reviewedCount == 0 ? "Start the crash course" : "Open next unread page",
                              systemImage: "bookmark.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(palette.onAccent)
                            .frame(maxWidth: .infinity, minHeight: 32)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                SectionTitle(title: "All Pages")
                ForEach(Array(lessons.enumerated()), id: \.element.id) { index, lesson in
                    let isReviewed = reviewedIDs.contains(lesson.id)
                    NavigationLink(value: Route.page(lesson.id)) {
                        LinkRow(
                            title: "\(index + 1). \(lesson.title)",
                            subtitle: lesson.subtitle,
                            symbol: isReviewed ? "checkmark.circle.fill" : "doc.text"
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityValue(isReviewed ? "Reviewed" : "Unreviewed")
                }
            }
        }
    }
}

private struct BinderCover: View {
    @Environment(\.palette) private var palette

    var body: some View {
        HStack(spacing: 16) {
            VStack(spacing: 16) {
                ForEach(0..<3) { _ in
                    Capsule()
                        .fill(palette.onAccent)
                        .frame(width: 16, height: 5)
                }
            }
            .padding(.horizontal, 11)
            .frame(maxHeight: .infinity)
            .background(palette.accent)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 8) {
                Label("ABO + NCLE", systemImage: "sparkle")
                    .font(.caption.weight(.bold).monospaced())
                    .foregroundStyle(palette.accent)
                Text("Erin’s Study Binder")
                    .font(.system(.largeTitle, design: .serif, weight: .bold))
                    .foregroundStyle(palette.text)
                    .accessibilityAddTraits(.isHeader)
                Text("Flip a page. Try a recall check. Scribble in the margins.")
                    .font(.subheadline)
                    .foregroundStyle(palette.secondaryText)
            }
            .padding(.vertical, 19)
            .padding(.trailing, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .fixedSize(horizontal: false, vertical: true)
        .background(palette.accent.opacity(0.10))
        .clipShape(.rect(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16).strokeBorder(palette.accent.opacity(0.25))
        }
    }
}

private struct BinderDivider: View {
    let title: String
    let symbol: String
    let color: Color
    @Environment(\.palette) private var palette

    var body: some View {
        Label(title, systemImage: symbol)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(palette.text)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: 46, alignment: .leading)
            .background(color.opacity(0.15), in: RoundedRectangle(cornerRadius: 10))
            .overlay(alignment: .bottom) {
                Capsule()
                    .fill(color)
                    .frame(height: 3)
                    .padding(.horizontal, 10)
                    .accessibilityHidden(true)
            }
    }
}

private struct BinderLessonView: View {
    let lesson: BinderLesson
    let number: Int
    @Binding var reviewed: String
    @Environment(\.palette) private var palette
    @State private var showsAnswer = false

    var body: some View {
        let reviewedIDs = Set(reviewed.split(separator: ",").map(String.init))
        let isReviewed = reviewedIDs.contains(lesson.id)
        let noteTarget = NoteTarget.binderPage(lesson)

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("\(lesson.exam.shortLabel)  /  PAGE \(number)")
                    .font(.caption.weight(.bold).monospaced())
                    .foregroundStyle(palette.accent)
                Text(lesson.title)
                    .font(.system(.largeTitle, design: .serif, weight: .bold))
                    .foregroundStyle(palette.text)
                    .accessibilityAddTraits(.isHeader)
                Text(lesson.subtitle)
                    .foregroundStyle(palette.secondaryText)

                Panel {
                    RichText(text: lesson.notes)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Label("Memory cue", systemImage: "sparkle")
                        .font(.headline)
                        .foregroundStyle(palette.accent)
                    RichText(text: lesson.cue)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(palette.accent.opacity(0.09), in: RoundedRectangle(cornerRadius: 14))

                Panel {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Cover & recall", systemImage: "questionmark.bubble")
                            .font(.headline)
                            .foregroundStyle(palette.text)
                            .accessibilityAddTraits(.isHeader)
                        RichText(text: lesson.prompt)
                        Button(showsAnswer ? "Hide answer" : "Reveal answer") {
                            showsAnswer.toggle()
                        }
                        .buttonStyle(.bordered)
                        .tint(palette.accent)
                        if showsAnswer {
                            RichText(text: lesson.answer)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    SectionTitle(title: "In the Margin")
                    NotePreview(target: noteTarget)
                    NoteButton(target: noteTarget)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))

                Button {
                    var updated = reviewedIDs
                    if isReviewed {
                        updated.remove(lesson.id)
                    } else {
                        updated.insert(lesson.id)
                    }
                    reviewed = updated.sorted().joined(separator: ",")
                } label: {
                    Label(isReviewed ? "Mark as unread" : "Mark as reviewed",
                          systemImage: isReviewed ? "arrow.uturn.backward" : "checkmark.circle")
                        .foregroundStyle(palette.onAccent)
                        .frame(maxWidth: .infinity, minHeight: 32)
                }
                .buttonStyle(.borderedProminent)
                .tint(palette.accent)
                .sensoryFeedback(.success, trigger: isReviewed) { !$0 && $1 }

                if let domain = ContentLibrary.shared.domains(for: lesson.exam).first(where: { $0.id == lesson.domain }) {
                    NavigationLink {
                        GuideView(domain: domain)
                    } label: {
                        LinkRow(title: "Open full study guide", subtitle: domain.name, symbol: "book")
                    }
                    .buttonStyle(.plain)
                }

                if lesson.binderReference != nil || lesson.sources?.isEmpty == false {
                    VStack(alignment: .leading, spacing: 6) {
                        SectionTitle(title: "Sources")
                        if let reference = lesson.binderReference {
                            Text(reference)
                                .font(.subheadline)
                                .foregroundStyle(palette.secondaryText)
                                .padding(.horizontal, 4)
                        }
                        ForEach(lesson.sources ?? [], id: \.self) { source in
                            Link(source.title, destination: source.url)
                                .font(.subheadline)
                                .tint(palette.accent)
                                .padding(.horizontal, 4)
                        }
                    }
                }
            }
            .padding()
        }
        .tabScreen("Binder Page \(number)")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    StudyBinderView()
        .modelContainer(for: StudyNote.self, inMemory: true)
}
