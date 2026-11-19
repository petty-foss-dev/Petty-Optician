import Combine
import Foundation

struct TextbookChapter: Decodable, Identifiable, Sendable {
    let id: String
    let exam: ExamID
    let domain: String
    let title: String
    let introduction: String
    let objectives: [String]
    let takeaways: [String]
    let lessonOrder: [Int]
    let sources: [SourceLink]?
}

struct TextbookLesson: Identifiable, Hashable, Sendable {
    let ref: LessonRef
    let chapterID: String
    let chapterNumber: Int
    let number: Int
    let section: GuideSection
    let contextWordCount: Int

    var id: String { "\(ref.domain)#\(ref.index)" }
    var minutes: Int { max(1, Int(ceil(Double(section.body.split { $0.isWhitespace }.count + contextWordCount) / 180))) }
}

struct Textbook: Sendable {
    static let shared: Textbook = {
        do {
            return try load(from: .main, library: .shared)
        } catch {
            fatalError("Bundled textbook failed to load: \(error)")
        }
    }()

    let chapters: [TextbookChapter]
    private let orderedLessons: [TextbookLesson]

    static func load(from bundle: Bundle, library: ContentLibrary) throws -> Textbook {
        guard let url = bundle.url(forResource: "textbook", withExtension: "json") else {
            throw ContentError.missingFile("textbook.json")
        }
        let chapters = try JSONDecoder().decode([TextbookChapter].self, from: Data(contentsOf: url))
        return try Textbook(chapters: chapters, library: library)
    }

    init(chapters: [TextbookChapter], library: ContentLibrary) throws {
        var lessons: [TextbookLesson] = []
        let domains = Set(library.exams.flatMap(\.domains).map(\.id))
        guard Set(chapters.map(\.id)).count == chapters.count,
              Set(chapters.map(\.domain)) == domains,
              chapters.count == domains.count else {
            throw TextbookError.invalidChapters
        }
        for exam in ExamID.allCases {
            for (chapterIndex, chapter) in chapters.filter({ $0.exam == exam }).enumerated() {
                guard let guide = library.guide(for: chapter.domain), guide.exam == exam,
                      !chapter.title.isEmpty, !chapter.introduction.isEmpty,
                      !chapter.objectives.isEmpty, !chapter.takeaways.isEmpty,
                      chapter.lessonOrder.count == guide.sections.count,
                      Set(chapter.lessonOrder) == Set(guide.sections.indices) else {
                    throw TextbookError.invalidLessons(chapter.id)
                }
                for (index, sourceIndex) in chapter.lessonOrder.enumerated() {
                    lessons.append(TextbookLesson(
                        ref: LessonRef(domain: chapter.domain, index: sourceIndex),
                        chapterID: chapter.id, chapterNumber: chapterIndex + 1,
                        number: index + 1, section: guide.sections[sourceIndex],
                        contextWordCount: (index == 0 ? ([chapter.introduction] + chapter.objectives).joined(separator: " ").split { $0.isWhitespace }.count : 0)
                            + (index == chapter.lessonOrder.count - 1 ? chapter.takeaways.joined(separator: " ").split { $0.isWhitespace }.count : 0)
                    ))
                }
            }
        }
        self.chapters = chapters
        orderedLessons = lessons
    }

    func number(of chapter: TextbookChapter) -> Int {
        chapters(for: chapter.exam).firstIndex { $0.id == chapter.id }! + 1
    }

    func chapters(for exam: ExamID) -> [TextbookChapter] { chapters.filter { $0.exam == exam } }

    func chapters(for resource: StudyResource, exam: ExamID? = nil) -> [TextbookChapter] {
        let domains = Set(resource.domains ?? [])
        return chapters.filter { chapter in
            resource.exams.contains(chapter.exam) && domains.contains(chapter.domain)
                && (exam == nil || chapter.exam == exam)
        }
    }

    func resources(in chapter: TextbookChapter, library: ContentLibrary = .shared) -> [StudyResource] {
        library.resources(for: chapter.exam, domain: chapter.domain)
    }

    func lessons(for exam: ExamID) -> [TextbookLesson] {
        let ids = Set(chapters(for: exam).map(\.id))
        return orderedLessons.filter { ids.contains($0.chapterID) }
    }

    func lesson(for ref: LessonRef) -> TextbookLesson? {
        orderedLessons.first { $0.ref == ref }
    }

    func lessons(for resource: StudyResource, exam: ExamID?) -> [TextbookLesson] {
        let candidates = exam.map { lessons(for: $0) } ?? orderedLessons
        return candidates.filter { $0.section.resourceID == resource.id }
    }

    func lessons(in chapter: TextbookChapter) -> [TextbookLesson] {
        orderedLessons.filter { $0.chapterID == chapter.id }
    }

    func chapter(for lesson: TextbookLesson) -> TextbookChapter {
        chapters.first { $0.id == lesson.chapterID }!
    }
}

enum TextbookError: Error {
    case invalidChapters
    case invalidLessons(String)
}

@MainActor
final class ReadingProgress: ObservableObject {
    static let shared = ReadingProgress()

    @Published private(set) var completed: Set<String> {
        didSet { defaults.set(completed.sorted(), forKey: Self.completedKey) }
    }
    @Published private var opened: [String: String] {
        didSet { defaults.set(opened, forKey: Self.openedKey) }
    }
    @Published private var completionDates: [String: Date] {
        didSet { defaults.set(completionDates, forKey: Self.completionDatesKey) }
    }
    private let defaults: UserDefaults
    private static let completedKey = "pettyoptician.textbook.completed"
    private static let completionDatesKey = "pettyoptician.textbook.completionDates"
    private static let openedKey = "pettyoptician.textbook.opened"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        completed = Set(defaults.stringArray(forKey: Self.completedKey) ?? [])
        completionDates = defaults.dictionary(forKey: Self.completionDatesKey) as? [String: Date] ?? [:]
        opened = defaults.dictionary(forKey: Self.openedKey) as? [String: String] ?? [:]
    }

    func lastOpened(for exam: ExamID) -> String? { opened[exam.rawValue] }

    func open(_ lesson: TextbookLesson, exam: ExamID) { opened[exam.rawValue] = lesson.id }

    func setCompleted(_ lesson: TextbookLesson, _ value: Bool, on date: Date = .now) {
        if value {
            if completed.insert(lesson.id).inserted {
                completionDates[lesson.id] = date
            }
        } else {
            completed.remove(lesson.id)
            completionDates.removeValue(forKey: lesson.id)
        }
    }

    func readLessons(in lessons: [TextbookLesson], on date: Date = .now) -> [TextbookLesson] {
        lessons.compactMap { lesson -> (TextbookLesson, Date)? in
            guard completed.contains(lesson.id), let stamp = completionDates[lesson.id],
                  Calendar.current.isDate(stamp, inSameDayAs: date) else { return nil }
            return (lesson, stamp)
        }.sorted { $0.1 > $1.1 }.map(\.0)
    }

    func resume(in lessons: [TextbookLesson], exam: ExamID) -> TextbookLesson? {
        if let last = lastOpened(for: exam), let index = lessons.firstIndex(where: { $0.id == last }) {
            if !completed.contains(last) { return lessons[index] }
            if let next = lessons.dropFirst(index + 1).first(where: { !completed.contains($0.id) }) { return next }
        }
        return lessons.first { !completed.contains($0.id) } ?? lessons.first
    }

    func reset() {
        completed = []
        completionDates = [:]
        opened = [:]
    }
}
