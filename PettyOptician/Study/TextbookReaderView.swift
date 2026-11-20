import SwiftData
import SwiftUI

struct TextbookReaderView: View {
    let exam: ExamID
    @State private var currentID: String
    @State private var activeQuiz: QuizSession?
    @State private var markedRead = 0
    @ObservedObject private var progress = ReadingProgress.shared
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    private let lessons: [TextbookLesson]
    private let textbook = Textbook.shared
    private let library = ContentLibrary.shared

    init(exam: ExamID, lesson: TextbookLesson) {
        self.exam = exam
        lessons = Textbook.shared.lessons(for: exam)
        _currentID = State(initialValue: lesson.id)
    }

    private var index: Int { lessons.firstIndex { $0.id == currentID }! }
    private var lesson: TextbookLesson { lessons[index] }
    private var previous: TextbookLesson? { index > 0 ? lessons[index - 1] : nil }
    private var next: TextbookLesson? { index + 1 < lessons.count ? lessons[index + 1] : nil }

    var body: some View {
        let lesson = lesson
        let chapter = textbook.chapter(for: lesson)
        let chapterLessons = textbook.lessons(in: chapter)
        let isRead = progress.completed.contains(lesson.id)

        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header(lesson, chapter: chapter, lessonsInChapter: chapterLessons.count, isRead: isRead)
                if lesson.id == chapterLessons.first?.id {
                    ChapterOverview(chapter: chapter)
                    Rectangle().fill(palette.separator).frame(height: 1).accessibilityHidden(true)
                }
                reading(lesson)
                if let comparison = VisualFitLesson(rawValue: lesson.id) {
                    VisualFitComparison(lesson: comparison).id(lesson.id)
                }
                if lesson.id == chapterLessons.last?.id {
                    if let formulas = library.guide(for: chapter.domain)?.formulas, !formulas.isEmpty {
                        Panel {
                            VStack(alignment: .leading, spacing: 14) {
                                SectionTitle(title: "Chapter formulas")
                                ForEach(formulas, id: \.self) { FormulaRow(formula: $0) }
                            }
                        }
                    }
                    TextbookCallout(title: "Chapter \(lesson.chapterNumber) takeaways", symbol: "checklist", items: chapter.takeaways, chapter: chapter)
                }
                if let id = lesson.section.resourceID, let resource = library.resources.first(where: { $0.id == id }) {
                    VStack(alignment: .leading, spacing: 8) {
                        if let reason = lesson.section.resourceReason {
                            Text(reason)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(palette.text)
                        }
                        ResourceRow(resource: resource, showsChapterLinks: false)
                    }
                    .accessibilityIdentifier("reader.selectedResource")
                }
                if let id = lesson.section.trainerID, let trainer = Trainer(rawValue: id) {
                    NavigationLink { trainer.screen } label: {
                        LinkRow(title: trainer.title, subtitle: trainer.subtitle, symbol: trainer.symbol)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("reader.trainer")
                }
                LessonCheckpoint(lesson: lesson, exam: exam) { activeQuiz = $0 }
                if let related = lessons.first(where: { $0.id == lesson.section.relatedLessonID }) {
                    NavigationLink {
                        TextbookReaderView(exam: exam, lesson: related)
                    } label: {
                        LinkRow(title: related.section.heading, subtitle: "Related case lesson · Chapter \(related.chapterNumber)", symbol: "book.pages")
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("reader.relatedLesson")
                }
                notes(lesson)
                completion(lesson, isRead: isRead)
                chapterResources(chapter, number: lesson.chapterNumber)
                pager
            }
            .padding()
            .padding(.bottom, 12)
            .frame(maxWidth: 680)
            .frame(maxWidth: .infinity)
        }
        .id(currentID)
        .pettyScreen()
        .navigationTitle("Lesson \(index + 1) of \(lessons.count)")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { progress.open(lesson, exam: exam) }
        .onChange(of: currentID) { progress.open(self.lesson, exam: exam) }
        .sensoryFeedback(.success, trigger: markedRead)
        .modifier(LessonGlossary(exam: exam))
        .quizCover($activeQuiz)
    }

    private func header(_ lesson: TextbookLesson, chapter: TextbookChapter, lessonsInChapter: Int, isRead: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("CHAPTER \(lesson.chapterNumber) · LESSON \(lesson.number) OF \(lessonsInChapter)")
                .font(.caption.weight(.bold))
                .tracking(1.5)
                .foregroundStyle(palette.accent)
            Text(chapter.title)
                .font(.system(.subheadline, design: .serif).weight(.semibold))
                .foregroundStyle(palette.secondaryText)
            Text(lesson.section.heading)
                .font(.system(.largeTitle, design: .serif, weight: .bold))
                .foregroundStyle(palette.text)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("reader.heading")
            HStack(spacing: 12) {
                Label("\(lesson.minutes) min read", systemImage: "clock")
                if isRead {
                    Label("Read", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(palette.accent)
                        .accessibilityIdentifier("reader.readBadge")
                }
            }
            .font(.footnote.weight(.medium))
            .foregroundStyle(palette.secondaryText)
        }
    }

    @ViewBuilder
    private func reading(_ lesson: TextbookLesson) -> some View {
        RichText(text: lesson.section.body, glossary: GlossaryLinks.byExam[exam], domain: lesson.ref.domain)
            .font(.system(.body, design: .serif))
            .lineSpacing(5)
            .textSelection(.enabled)
        if let diagram = library.diagram(lesson.section.diagram) {
            DiagramCard(diagram: diagram)
        }
        if let sources = lesson.section.sources, !sources.isEmpty {
            SourceList(sources: sources)
        }
    }

    private func notes(_ lesson: TextbookLesson) -> some View {
        let target = NoteTarget.lesson(lesson.ref, exam: exam, heading: lesson.section.heading)
        return VStack(alignment: .leading, spacing: 8) {
            NotePreview(target: target)
            NoteButton(target: target)
                .font(.subheadline.weight(.semibold))
        }
    }

    @ViewBuilder
    private func completion(_ lesson: TextbookLesson, isRead: Bool) -> some View {
        if isRead {
            if next == nil { finished }
            Button {
                progress.setCompleted(lesson, false)
            } label: {
                Label("Mark as unread", systemImage: "arrow.uturn.backward")
                    .frame(maxWidth: .infinity, minHeight: 36)
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("reader.markUnread")
        } else {
            Button {
                progress.setCompleted(lesson, true)
                StudySettings.shared.recordStudy()
                markedRead += 1
                if let next { currentID = next.id }
            } label: {
                Label(next == nil ? "Mark read & finish" : "Mark read & continue", systemImage: "checkmark.circle")
                    .font(.headline)
                    .foregroundStyle(palette.onAccent)
                    .frame(maxWidth: .infinity, minHeight: 40)
            }
            .buttonStyle(.borderedProminent)
            .tint(palette.accent)
            .accessibilityIdentifier("reader.markRead")
        }
    }

    private var finished: some View {
        let firstUnread = lessons.first { !progress.completed.contains($0.id) }
        return Panel(padding: 18) {
            VStack(alignment: .leading, spacing: 10) {
                Label("End of the textbook", systemImage: "checkmark.seal.fill")
                    .font(.system(.title3, design: .serif, weight: .bold))
                    .foregroundStyle(palette.accent)
                    .accessibilityAddTraits(.isHeader)
                if let firstUnread {
                    Text("You’ve reached the last lesson, but some earlier lessons are still unread.")
                        .foregroundStyle(palette.text)
                    Button("Go to the first unread lesson") { currentID = firstUnread.id }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("reader.firstUnread")
                } else {
                    Text("You’ve read every lesson in the \(exam.shortLabel) textbook. Revisit your notes and use practice questions to check your understanding.")
                        .foregroundStyle(palette.text)
                    Button("Close lesson") { dismiss() }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("reader.backToContents")
                }
            }
            .font(.subheadline)
        }
        .accessibilityIdentifier("reader.finished")
    }

    @ViewBuilder
    private func chapterResources(_ chapter: TextbookChapter, number: Int) -> some View {
        let count = textbook.resources(in: chapter).count
        if count > 0 {
            Panel {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Chapter \(number) resources")
                        .font(.headline)
                        .foregroundStyle(palette.text)
                        .accessibilityAddTraits(.isHeader)
                    Text("\(count) library \(count == 1 ? "resource covers" : "resources cover") \(chapter.title). Explore the chapter’s videos and further reading.")
                        .font(.subheadline)
                        .foregroundStyle(palette.secondaryText)
                    NavigationLink {
                        ChapterResourcesView(chapter: chapter)
                    } label: {
                        Label("Watch & read for this chapter", systemImage: "play.rectangle.on.rectangle")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 36)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("reader.chapterResources")
                }
            }
        }
    }

    private var pager: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 10))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 10))
        return layout {
            if let previous {
                PagerButton(lesson: previous, current: lesson, forward: false) { currentID = previous.id }
                    .accessibilityIdentifier("reader.previous")
            }
            if let next {
                PagerButton(lesson: next, current: lesson, forward: true) { currentID = next.id }
                    .accessibilityIdentifier("reader.next")
            }
        }
    }
}

private struct PagerButton: View {
    let lesson: TextbookLesson
    let current: TextbookLesson
    let forward: Bool
    let action: () -> Void
    @Environment(\.palette) private var palette

    var body: some View {
        let unit = lesson.chapterID == current.chapterID ? "lesson" : "chapter"
        Button(action: action) {
            VStack(alignment: forward ? .trailing : .leading, spacing: 3) {
                Label(forward ? "Next \(unit)" : "Previous \(unit)", systemImage: forward ? "chevron.right" : "chevron.left")
                    .labelStyle(PagerLabelStyle(trailingIcon: forward))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(palette.accent)
                Text(lesson.section.heading)
                    .font(.system(.subheadline, design: .serif).weight(.semibold))
                    .foregroundStyle(palette.text)
                    .multilineTextAlignment(forward ? .trailing : .leading)
                    .lineLimit(3)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: forward ? .trailing : .leading)
            .background(palette.cardBackground, in: RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12).strokeBorder(palette.separator, lineWidth: 0.5)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct PagerLabelStyle: LabelStyle {
    let trailingIcon: Bool

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 4) {
            if !trailingIcon { configuration.icon }
            configuration.title
            if trailingIcon { configuration.icon }
        }
    }
}

struct LessonCheckpoint: View {
    let lesson: TextbookLesson
    let exam: ExamID
    let start: (QuizSession) -> Void
    @State private var matched: (ref: LessonRef, questions: [Question])?
    @Query private var stats: [QuestionStat]
    @Environment(\.palette) private var palette

    var body: some View {
        let authored = (lesson.section.checkpointIDs ?? []).compactMap(ContentLibrary.shared.question(id:))
        let related = matched.flatMap { $0.ref == lesson.ref ? $0.questions : nil } ?? []
        let pool = authored.isEmpty ? related : authored
        let count = authored.isEmpty ? min(3, pool.count) : authored.count
        VStack(alignment: .leading, spacing: 6) {
            if count > 0 {
                Button {
                    let picked = authored.isEmpty ? QuizBuilder.weakFirst(pool, count: count, history: stats.history) : authored
                    start(QuizSession(
                        config: QuizConfig(exam: exam, title: lesson.section.heading, domains: [lesson.ref.domain], count: count),
                        questions: picked,
                        flagged: stats.flaggedIDs
                    ))
                } label: {
                    Label("Check your understanding · \(count) \(count == 1 ? "question" : "questions")", systemImage: "checklist")
                        .frame(maxWidth: .infinity, minHeight: 36, alignment: .leading)
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("reader.practice")

                if !authored.isEmpty {
                    let history = stats.history
                    let seen = authored.compactMap { history[$0.id] }.filter { $0.seen > 0 }
                    if !seen.isEmpty {
                        Text("\(seen.count(where: \.lastWasCorrect)) correct on latest attempt · \(seen.count) of \(count) attempted")
                            .font(.caption)
                            .foregroundStyle(palette.secondaryText)
                    }
                }
            }
        }
        .task(id: lesson.ref) {
            guard authored.isEmpty else { return }
            let ref = lesson.ref
            let questions = await Task.detached(priority: .userInitiated) {
                LessonLinks.shared.questions(for: ref)
            }.value
            guard !Task.isCancelled else { return }
            matched = (ref, questions)
        }
    }
}
