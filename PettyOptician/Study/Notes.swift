import SwiftData
import SwiftUI

struct NoteTarget: Identifiable, Hashable {
    let kind: StudyNote.Kind
    let targetID: String
    let exam: ExamID
    let title: String

    var id: String { "\(kind.rawValue)|\(targetID)" }

    static func lesson(_ lesson: LessonRef, exam: ExamID, heading: String) -> NoteTarget {
        NoteTarget(kind: .lesson, targetID: StudyNote.lessonTarget(lesson), exam: exam, title: heading)
    }

    static func question(_ question: Question) -> NoteTarget {
        NoteTarget(kind: .question, targetID: question.id, exam: question.exam, title: question.stem)
    }

    static func binderPage(_ lesson: BinderLesson) -> NoteTarget {
        NoteTarget(kind: .binderPage, targetID: lesson.id, exam: lesson.exam, title: lesson.title)
    }

    static func quick(exam: ExamID) -> NoteTarget {
        NoteTarget(kind: .quick, targetID: UUID().uuidString, exam: exam, title: "Quick Note")
    }
}

struct NoteButton: View {
    let target: NoteTarget
    @Query private var notes: [StudyNote]
    @State private var editing: NoteTarget?

    init(target: NoteTarget) {
        self.target = target
        let kind = target.kind.rawValue, id = target.targetID
        _notes = Query(filter: #Predicate<StudyNote> { $0.kindRaw == kind && $0.targetID == id })
    }

    var body: some View {
        Button { editing = target } label: {
            Label(notes.isEmpty ? "Add Note" : "Edit Note", systemImage: notes.isEmpty ? "square.and.pencil" : "note.text")
        }
        .buttonStyle(.bordered)
        .accessibilityIdentifier("note.button")
        .sheet(item: $editing) { NoteEditor(target: $0) }
    }
}

struct NotePreview: View {
    let target: NoteTarget
    @Query private var notes: [StudyNote]
    @Environment(\.palette) private var palette

    init(target: NoteTarget) {
        self.target = target
        let kind = target.kind.rawValue, id = target.targetID
        _notes = Query(filter: #Predicate<StudyNote> { $0.kindRaw == kind && $0.targetID == id },
                       sort: \StudyNote.updated, order: .reverse)
    }

    var body: some View {
        if let note = notes.first {
            Label {
                Text(note.text).font(.subheadline).foregroundStyle(palette.text)
            } icon: {
                Image(systemName: "note.text").foregroundStyle(palette.accent)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 12).fill(palette.accent.opacity(0.08)))
        }
    }
}

struct NoteEditor: View {
    let target: NoteTarget
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(\.palette) private var palette
    @Query private var notes: [StudyNote]
    @State private var text = ""
    @FocusState private var focused: Bool

    init(target: NoteTarget) {
        self.target = target
        let kind = target.kind.rawValue, id = target.targetID
        _notes = Query(filter: #Predicate<StudyNote> { $0.kindRaw == kind && $0.targetID == id },
                       sort: \StudyNote.updated, order: .reverse)
    }

    private var editorTitle: String {
        switch target.kind {
        case .lesson: "Lesson Note"
        case .question: "Question Note"
        case .binderPage: "Margin Note"
        case .quick: "Quick Note"
        }
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                Text(target.kind == .quick ? "\(target.exam.shortLabel) · Formulas, reminders, or anything worth keeping." : target.title)
                    .font(.subheadline)
                    .foregroundStyle(palette.secondaryText)
                    .lineLimit(3)
                TextEditor(text: $text)
                    .focused($focused)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 12).fill(palette.cardBackground))
                    .accessibilityLabel("Note text")
                    .accessibilityIdentifier("note.text")
                if notes.first != nil {
                    Button("Delete Note", role: .destructive) {
                        notes.forEach(context.delete)
                        try? context.save()
                        dismiss()
                    }
                }
            }
            .padding()
            .pettyScreen()
            .navigationTitle(editorTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).accessibilityIdentifier("note.save")
                        .disabled(notes.isEmpty && text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                text = notes.first?.text ?? ""
                focused = true
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func save() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            notes.forEach(context.delete)
        } else if let note = notes.first {
            note.text = trimmed
            note.updated = .now
        } else {
            context.insert(StudyNote(kind: target.kind, targetID: target.targetID, exam: target.exam, text: trimmed))
        }
        try? context.save()
        dismiss()
    }
}

struct NotesView: View {
    @ObservedObject private var settings = StudySettings.shared
    @Query(sort: \StudyNote.updated, order: .reverse) private var notes: [StudyNote]
    @State private var query = ""
    @State private var editing: NoteTarget?

    var body: some View {
        let mine = notes.filter { $0.exam == settings.exam }
        let search = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let matching = search.isEmpty ? mine : mine.filter { $0.text.localizedStandardContains(search) }
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                if mine.isEmpty {
                    ContentUnavailableView {
                        Label("A page of your own", systemImage: "note.text")
                    } description: {
                        Text("Jot a quick note or add one in the margin of a binder page. Notes from exam guides and questions show up here, too.")
                    } actions: {
                        Button("Jot a note") { editing = .quick(exam: settings.exam) }
                            .buttonStyle(.borderedProminent)
                    }
                } else if matching.isEmpty {
                    ContentUnavailableView.search(text: search)
                }
                ForEach(matching) { NoteRow(note: $0) }
            }
            .padding()
        }
        .pettyScreen()
        .navigationTitle("My Notes")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always),
                    prompt: "Search \(settings.exam.shortLabel) notes")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    editing = .quick(exam: settings.exam)
                } label: {
                    Label("New quick note", systemImage: "square.and.pencil")
                }
                .accessibilityIdentifier("notes.new")
            }
        }
        .sheet(item: $editing) { NoteEditor(target: $0) }
    }
}

struct NoteRow: View {
    let note: StudyNote
    @Environment(\.palette) private var palette
    @State private var editing: NoteTarget?
    private let library = ContentLibrary.shared

    var body: some View {
        if note.kind == .quick || note.kind == .binderPage {
            let lesson = note.kind == .binderPage ? library.binderLessons.first { $0.id == note.targetID } : nil
            let label = note.kind == .quick ? "Quick Note" : "Binder Margin"
            Button {
                editing = NoteTarget(kind: note.kind, targetID: note.targetID, exam: note.exam, title: lesson?.title ?? label)
            } label: {
                card(label: label, title: lesson?.title)
            }
            .buttonStyle(.plain)
            .sheet(item: $editing) { NoteEditor(target: $0) }
        } else if let ref = note.lesson, let lesson = Textbook.shared.lesson(for: ref) {
            NavigationLink { TextbookReaderView(exam: Textbook.shared.chapter(for: lesson).exam, lesson: lesson) } label: {
                card(label: "\(library.domainName(ref.domain)) · Lesson", title: lesson.section.heading)
            }
            .buttonStyle(.plain)
        } else if let question = library.question(id: note.targetID) {
            NavigationLink {
                ScrollView { QuestionPreviewRow(question: question).padding() }
                    .pettyScreen()
                    .navigationTitle(question.topic)
                    .navigationBarTitleDisplayMode(.inline)
            } label: {
                card(label: "\(library.domainName(question.domain)) · Question", title: question.stem)
            }
            .buttonStyle(.plain)
        }
    }

    private func card(label: String, title: String?) -> some View {
        Panel(padding: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text(label.uppercased()).font(.caption2.weight(.bold)).tracking(0.6).foregroundStyle(palette.accent)
                if let title {
                    Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(palette.text).lineLimit(2).multilineTextAlignment(.leading)
                }
                Text(note.text).font(.subheadline).foregroundStyle(palette.secondaryText).lineLimit(4).multilineTextAlignment(.leading)
                Text(note.updated, format: .relative(presentation: .named)).font(.caption2).foregroundStyle(palette.tertiaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
