import SwiftUI

enum TextbookRoute: Hashable {
    case chapter(String)
    case lesson(TextbookLesson)
    case guides
    case notes
}

@MainActor
struct ReadingState {
    let lessons: [TextbookLesson]
    let readCount: Int
    let minutesLeft: Int
    let hasStarted: Bool
    let next: TextbookLesson?

    init(exam: ExamID, progress: ReadingProgress) {
        let lessons = Textbook.shared.lessons(for: exam)
        let unread = lessons.filter { !progress.completed.contains($0.id) }
        self.lessons = lessons
        readCount = lessons.count - unread.count
        minutesLeft = unread.map(\.minutes).reduce(0, +)
        hasStarted = readCount > 0 || progress.lastOpened(for: exam) != nil
        next = unread.isEmpty ? nil : progress.resume(in: lessons, exam: exam) ?? unread.first
    }

    var isFinished: Bool { !lessons.isEmpty && next == nil }
}

struct TextbookView: View {
    @ObservedObject private var settings = StudySettings.shared
    @ObservedObject private var progress = ReadingProgress.shared
    @State private var showingBinder = false
    private let textbook = Textbook.shared
    private let library = ContentLibrary.shared

    var body: some View {
        let exam = settings.exam
        let state = ReadingState(exam: exam, progress: progress)
        let chapters = textbook.chapters(for: exam)

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    ExamSwitcher()
                    TextbookCover(exam: exam, state: state, chapterCount: chapters.count)
                    contents(chapters, exam: exam)
                    reference(exam)
                }
                .padding()
                .frame(maxWidth: 720)
                .frame(maxWidth: .infinity)
            }
            .tabScreen("Study")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: TextbookRoute.self) { route in
                switch route {
                case .chapter(let id):
                    if let chapter = textbook.chapters.first(where: { $0.id == id }) {
                        TextbookChapterView(chapter: chapter)
                    }
                case .lesson(let lesson):
                    TextbookReaderView(exam: textbook.chapter(for: lesson).exam, lesson: lesson)
                case .guides: StudyView()
                case .notes: NotesView()
                }
            }
        }
        .binderSheet($showingBinder)
    }

    private func contents(_ chapters: [TextbookChapter], exam: ExamID) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(title: "Contents", trailing: "\(chapters.count) chapters")
            if let outline = library.exam(exam)?.officialOutline, !outline.isEmpty {
                NavigationLink {
                    ScrollView {
                        ExamObjectivesList(exam: exam, outline: outline)
                            .padding()
                            .frame(maxWidth: 720)
                            .frame(maxWidth: .infinity)
                    }
                    .pettyScreen()
                    .navigationTitle("\(exam.shortLabel) exam objectives")
                    .navigationBarTitleDisplayMode(.inline)
                } label: {
                    LinkRow(title: "Exam objectives", subtitle: "Find a lesson, worked example and practice by exam topic", symbol: "list.bullet.clipboard")
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("textbook.objectives")
            }
            ForEach(Array(chapters.enumerated()), id: \.element.id) { index, chapter in
                let lessons = textbook.lessons(in: chapter)
                NavigationLink(value: TextbookRoute.chapter(chapter.id)) {
                    ChapterRow(
                        number: index + 1,
                        chapter: chapter,
                        read: lessons.count { progress.completed.contains($0.id) },
                        total: lessons.count,
                        minutes: lessons.map(\.minutes).reduce(0, +)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("textbook.chapter.\(chapter.id)")
            }
        }
    }

    private func reference(_ exam: ExamID) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(title: "Reference Shelf")
            NavigationLink(value: TextbookRoute.guides) {
                LinkRow(title: "Exam Guides", subtitle: "Browse by official exam section, with search, glossary, tables and formulas", symbol: "books.vertical")
            }
            .accessibilityIdentifier("textbook.guides")
            Button { showingBinder = true } label: {
                LinkRow(title: "Erin’s Study Binder", subtitle: "\(library.binderLessons.count { $0.exam == exam }) crash course pages with memory cues and recall checks", symbol: "book.closed")
            }
            .accessibilityIdentifier("textbook.binder")
            NavigationLink(value: TextbookRoute.notes) {
                LinkRow(title: "My Notes", subtitle: "Your notes on lessons, questions and binder pages", symbol: "note.text")
            }
            .accessibilityIdentifier("textbook.notes")
        }
        .buttonStyle(.plain)
    }
}

extension View {
    func binderSheet(_ isPresented: Binding<Bool>) -> some View {
        sheet(isPresented: isPresented) {
            StudyBinderView(showsCloseButton: true).presentationDragIndicator(.visible)
        }
    }
}

private struct TextbookCover: View {
    let exam: ExamID
    let state: ReadingState
    let chapterCount: Int
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("\(exam.shortLabel) BASIC · TEXTBOOK")
                .font(.caption.weight(.bold))
                .tracking(1.5)
                .foregroundStyle(palette.accent)
            Text(exam == .abo ? "Spectacle Dispensing" : "Contact Lens Dispensing")
                .font(.system(.largeTitle, design: .serif, weight: .bold))
                .foregroundStyle(palette.text)
                .accessibilityAddTraits(.isHeader)
            Text("\(chapterCount) chapters and \(state.lessons.count) lessons, taught in order from the first page.")
                .font(.system(.subheadline, design: .serif))
                .foregroundStyle(palette.secondaryText)

            Rectangle().fill(palette.separator).frame(height: 1).accessibilityHidden(true)

            ReadingProgressLine(read: state.readCount, total: state.lessons.count, minutesLeft: state.minutesLeft)

            if let target = state.next ?? state.lessons.first {
                if state.isFinished {
                    Label("You’ve read every lesson.", systemImage: "checkmark.seal.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(palette.accent)
                        .accessibilityIdentifier("textbook.finished")
                } else {
                    NextLessonCaption(lesson: target)
                }
                NavigationLink(value: TextbookRoute.lesson(target)) {
                    Label(callToAction, systemImage: state.isFinished ? "arrow.counterclockwise" : "book")
                        .font(.headline)
                        .foregroundStyle(palette.onAccent)
                        .frame(maxWidth: .infinity, minHeight: 36)
                }
                .buttonStyle(.borderedProminent)
                .tint(palette.accent)
                .accessibilityIdentifier(state.isFinished ? "textbook.review" : "textbook.resume")
            }

            Text("Reading progress is kept on this device. It tracks what you’ve read, not exam readiness.")
                .font(.caption)
                .foregroundStyle(palette.tertiaryText)
        }
        .padding(20)
        .padding(.leading, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.cardBackground)
        .overlay(alignment: .leading) {
            palette.accent.frame(width: 6).accessibilityHidden(true)
        }
        .clipShape(.rect(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18).strokeBorder(palette.separator, lineWidth: 0.5)
        }
    }

    private var callToAction: String {
        if state.isFinished { return "Review from the beginning" }
        return state.hasStarted ? "Continue reading" : "Start reading"
    }
}

private struct ReadingProgressLine: View {
    let read: Int
    let total: Int
    var minutesLeft: Int?
    @Environment(\.palette) private var palette

    var body: some View {
        ProgressView(value: Double(read), total: Double(max(total, 1))) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(read) of \(total) lessons read")
                Spacer()
                if let minutesLeft, minutesLeft > 0 {
                    Text("about \(minutesLeft) min left")
                }
            }
            .font(.footnote.weight(.medium))
            .foregroundStyle(palette.secondaryText)
        }
        .tint(palette.accent)
    }
}

private struct NextLessonCaption: View {
    let lesson: TextbookLesson
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Chapter \(lesson.chapterNumber) · Lesson \(lesson.number) · \(lesson.minutes) min")
                .font(.caption.weight(.semibold))
                .foregroundStyle(palette.secondaryText)
            Text(lesson.section.heading)
                .font(.system(.headline, design: .serif))
                .foregroundStyle(palette.text)
                .multilineTextAlignment(.leading)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct ChapterRow: View {
    let number: Int
    let chapter: TextbookChapter
    let read: Int
    let total: Int
    let minutes: Int
    @Environment(\.palette) private var palette

    var body: some View {
        let done = total > 0 && read == total
        Panel(padding: 14) {
            HStack(alignment: .top, spacing: 12) {
                Text("\(number)")
                    .font(.system(.title2, design: .serif, weight: .bold).monospacedDigit())
                    .foregroundStyle(palette.accent)
                    .frame(minWidth: 26, alignment: .leading)
                VStack(alignment: .leading, spacing: 6) {
                    Text(chapter.title)
                        .font(.system(.headline, design: .serif))
                        .foregroundStyle(palette.text)
                        .multilineTextAlignment(.leading)
                    Text(chapter.introduction)
                        .font(.subheadline)
                        .foregroundStyle(palette.secondaryText)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                    Label("\(read) of \(total) read · \(chapter.objectives.count) objectives · \(minutes) min",
                          systemImage: done ? "checkmark.circle.fill" : "text.book.closed")
                        .font(.caption)
                        .foregroundStyle(done ? palette.accent : palette.tertiaryText)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(palette.tertiaryText)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Chapter \(number), \(chapter.title)")
        .accessibilityValue("\(read) of \(total) lessons read")
    }
}

struct TextbookChapterView: View {
    let chapter: TextbookChapter
    @ObservedObject private var progress = ReadingProgress.shared
    @Environment(\.palette) private var palette
    private let textbook = Textbook.shared

    var body: some View {
        let lessons = textbook.lessons(in: chapter)
        let read = lessons.count { progress.completed.contains($0.id) }
        let number = lessons.first?.chapterNumber ?? 1

        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("\(chapter.exam.shortLabel) · CHAPTER \(number)")
                        .font(.caption.weight(.bold))
                        .tracking(1.5)
                        .foregroundStyle(palette.accent)
                    Text(chapter.title)
                        .font(.system(.largeTitle, design: .serif, weight: .bold))
                        .foregroundStyle(palette.text)
                        .accessibilityAddTraits(.isHeader)
                }

                ChapterOverview(chapter: chapter)

                if !lessons.isEmpty {
                    ReadingProgressLine(read: read, total: lessons.count)
                    start(lessons, read: read)
                    resources
                    lessonList(lessons)
                }
            }
            .padding()
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
        .pettyScreen()
        .navigationTitle("Chapter \(number)")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func start(_ lessons: [TextbookLesson], read: Int) -> some View {
        if let target = progress.resume(in: lessons, exam: chapter.exam) {
            let done = read == lessons.count
            NavigationLink {
                TextbookReaderView(exam: chapter.exam, lesson: target)
            } label: {
                Label(done ? "Review this chapter" : read == 0 ? "Start this chapter" : "Continue this chapter",
                      systemImage: done ? "arrow.counterclockwise" : "book")
                    .font(.headline)
                    .foregroundStyle(palette.onAccent)
                    .frame(maxWidth: .infinity, minHeight: 36)
            }
            .buttonStyle(.borderedProminent)
            .tint(palette.accent)
            .accessibilityIdentifier("chapter.resume")
        }
    }

    @ViewBuilder
    private var resources: some View {
        let count = textbook.resources(in: chapter).count
        if count > 0 {
            NavigationLink {
                ChapterResourcesView(chapter: chapter)
            } label: {
                LinkRow(title: "Watch & Read",
                        subtitle: "\(count) library \(count == 1 ? "resource" : "resources") for this chapter: videos, articles and practice",
                        symbol: "play.rectangle.on.rectangle")
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("chapter.resources")
        }
    }

    private func lessonList(_ lessons: [TextbookLesson]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionTitle(title: "Lessons", trailing: "\(lessons.count)")
            ForEach(lessons) { lesson in
                let isRead = progress.completed.contains(lesson.id)
                NavigationLink {
                    TextbookReaderView(exam: chapter.exam, lesson: lesson)
                } label: {
                    LessonRow(lesson: lesson, isRead: isRead)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("textbook.lesson.\(lesson.id)")
                .accessibilityValue(isRead ? "Read" : "Unread")
            }
        }
    }
}

private struct LessonRow: View {
    let lesson: TextbookLesson
    let isRead: Bool
    @Environment(\.palette) private var palette

    var body: some View {
        Panel(padding: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Image(systemName: isRead ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isRead ? palette.accent : palette.tertiaryText)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(lesson.number). \(lesson.section.heading)")
                        .font(.system(.headline, design: .serif))
                        .foregroundStyle(palette.text)
                        .multilineTextAlignment(.leading)
                    Text("\(lesson.minutes) min read")
                        .font(.caption)
                        .foregroundStyle(palette.secondaryText)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(palette.tertiaryText)
            }
        }
    }
}

struct ChapterOverview: View {
    let chapter: TextbookChapter

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            RichText(text: chapter.introduction)
                .font(.system(.body, design: .serif))
                .lineSpacing(4)
            TextbookCallout(title: "What you’ll learn", symbol: "target", items: chapter.objectives)
            if let sources = chapter.sources, !sources.isEmpty {
                SourceList(sources: sources)
            }
        }
    }
}

struct TextbookCallout: View {
    let title: String
    let symbol: String
    let items: [String]
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: symbol)
                .font(.headline)
                .foregroundStyle(palette.accent)
                .accessibilityAddTraits(.isHeader)
            RichText(text: items.map { "- \($0)" }.joined(separator: "\n"))
                .font(.subheadline)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.accent.opacity(0.09), in: RoundedRectangle(cornerRadius: 14))
    }
}

struct TextbookContinueCard: View {
    let exam: ExamID
    let openContents: () -> Void
    let startCheck: (QuizSession) -> Void
    @ObservedObject private var progress = ReadingProgress.shared
    @Environment(\.palette) private var palette

    var body: some View {
        let state = ReadingState(exam: exam, progress: progress)
        let readToday = progress.readLessons(in: state.lessons)
        if let target = state.next ?? state.lessons.first {
            Panel(padding: 18) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("TODAY’S \(exam.shortLabel) LESSON")
                        .font(.caption.weight(.bold))
                        .tracking(1.5)
                        .foregroundStyle(palette.accent)
                    if state.isFinished {
                        Text("You’ve read every lesson")
                            .font(.system(.title3, design: .serif, weight: .bold))
                            .foregroundStyle(palette.text)
                    } else {
                        NextLessonCaption(lesson: target)
                    }
                    if !readToday.isEmpty {
                        Label("\(readToday.count) \(readToday.count == 1 ? "lesson" : "lessons") read today", systemImage: "checkmark.circle.fill")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(palette.accent)
                    }
                    ReadingProgressLine(read: state.readCount, total: state.lessons.count)
                    NavigationLink {
                        TextbookReaderView(exam: exam, lesson: target)
                    } label: {
                        Label(state.isFinished ? "Review from the beginning" : state.hasStarted ? "Continue reading" : "Start reading",
                              systemImage: state.isFinished ? "arrow.counterclockwise" : "book")
                            .font(.headline)
                            .foregroundStyle(palette.onAccent)
                            .frame(maxWidth: .infinity, minHeight: 36)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(palette.accent)
                    .accessibilityIdentifier("today.reading")
                    let checkLesson = readToday.first ?? target
                    if checkLesson != target {
                        Text("Review · \(checkLesson.section.heading)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(palette.text)
                    }
                    LessonCheckpoint(lesson: checkLesson, exam: exam, start: startCheck)
                    Button("Open table of contents", action: openContents)
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .accessibilityIdentifier("today.contents")
                }
            }
        }
    }
}
