import XCTest
@testable import PettyOptician

final class TextbookTests: XCTestCase {
    private let library = ContentLibrary.shared

    func testBundledTextbookCoversEveryLessonExactlyOnce() throws {
        let textbook = try Textbook.load(from: Bundle(for: QuizRecord.self), library: library)
        for exam in ExamID.allCases {
            let expected = library.guides.filter { $0.exam == exam }.flatMap { guide in
                guide.sections.indices.map { LessonRef(domain: guide.domain, index: $0) }
            }
            let lessons = textbook.lessons(for: exam)
            XCTAssertEqual(Set(lessons.map(\.ref)), Set(expected))
            XCTAssertEqual(lessons.count, expected.count)
            XCTAssertEqual(Set(lessons.map(\.id)).count, expected.count)
            for (chapterIndex, chapter) in textbook.chapters(for: exam).enumerated() {
                for (index, lesson) in textbook.lessons(in: chapter).enumerated() {
                    XCTAssertEqual(lesson.chapterNumber, chapterIndex + 1)
                    XCTAssertEqual(lesson.number, index + 1)
                    XCTAssertEqual(lesson.section, library.guide(for: chapter.domain)!.sections[lesson.ref.index])
                    XCTAssertEqual(lesson.id, StudyNote.lessonTarget(lesson.ref))
                    XCTAssertEqual(textbook.chapter(for: lesson).id, chapter.id)
                    XCTAssertGreaterThan(lesson.minutes, 0)
                }
            }
        }
    }

    func testLibraryLinksAreBidirectionalAndRespectTheExam() {
        let textbook = Textbook.shared
        for chapter in textbook.chapters {
            let resources = textbook.resources(in: chapter, library: library)
            XCTAssertFalse(resources.isEmpty, chapter.id)
            for resource in resources {
                XCTAssertTrue(textbook.chapters(for: resource).contains { $0.id == chapter.id }, resource.id)
                XCTAssertTrue(textbook.chapters(for: resource, exam: chapter.exam).allSatisfy { $0.exam == chapter.exam })
                XCTAssertTrue(resource.domains?.contains(chapter.domain) == true)
                XCTAssertTrue(resource.exams.contains(chapter.exam))
            }
        }
        for resource in library.resources {
            let linked = textbook.chapters(for: resource)
            if resource.domains?.isEmpty ?? true {
                XCTAssertTrue(linked.isEmpty, "General resource must not be assigned to an arbitrary chapter")
            }
            for chapter in linked {
                XCTAssertTrue(textbook.resources(in: chapter, library: library).contains { $0.id == resource.id })
            }
        }
    }

    func testCuratedActivitiesResolveToTheirLessons() throws {
        let textbook = Textbook.shared
        let links = LessonLinks(library: library)
        var assigned = Set<String>()
        for exam in ExamID.allCases {
            let lessons = textbook.lessons(for: exam)
            for lesson in lessons {
                let section = lesson.section
                if let id = section.resourceID {
                    let resource = try XCTUnwrap(library.resources.first { $0.id == id }, lesson.id)
                    XCTAssertTrue(resource.exams.contains(exam), id)
                    XCTAssertFalse((section.resourceReason ?? "").isEmpty, lesson.id)
                    XCTAssertTrue(textbook.lessons(for: resource, exam: exam).contains(lesson))
                }
                if let id = section.trainerID {
                    XCTAssertEqual(Trainer(rawValue: id)?.exam, exam, lesson.id)
                }
                if let id = section.relatedLessonID {
                    XCTAssertTrue(lessons.contains { $0.id == id && $0.id != lesson.id }, lesson.id)
                }
                for id in section.checkpointIDs ?? [] {
                    XCTAssertTrue(assigned.insert(id).inserted, id)
                    let question = try XCTUnwrap(library.question(id: id), id)
                    XCTAssertEqual(question.exam, exam, id)
                    XCTAssertEqual(links.lesson(for: question), lesson.ref, id)
                    XCTAssertTrue(links.questions(for: lesson.ref).contains(question), id)
                }
            }
        }
        XCTAssertFalse(assigned.isEmpty)
    }

    @MainActor
    func testDailyReadingPreservesLegacyProgressAndCountsByExamAndDay() throws {
        let suite = "TextbookTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let yesterday = Date(timeIntervalSince1970: 1_700_000_000)
        let today = yesterday.addingTimeInterval(86_400)
        let abo = Textbook.shared.lessons(for: .abo)
        let ncle = Textbook.shared.lessons(for: .ncle)
        defaults.set([abo[0].id], forKey: "pettyoptician.textbook.completed")
        let progress = ReadingProgress(defaults: defaults)
        XCTAssertTrue(progress.completed.contains(abo[0].id))
        XCTAssertTrue(progress.readLessons(in: abo, on: today).isEmpty)
        progress.setCompleted(abo[1], true, on: yesterday)
        progress.setCompleted(abo[1], true, on: today)
        progress.setCompleted(ncle[0], true, on: today)
        progress.setCompleted(abo[2], true, on: today)
        let restored = ReadingProgress(defaults: defaults)
        XCTAssertEqual(restored.readLessons(in: abo, on: today), [abo[2]])
        XCTAssertEqual(restored.readLessons(in: abo, on: yesterday), [abo[1]])
        XCTAssertEqual(restored.readLessons(in: ncle, on: today), [ncle[0]])
        restored.setCompleted(abo[2], false)
        XCTAssertTrue(restored.readLessons(in: abo, on: today).isEmpty)
        restored.reset()
        XCTAssertTrue(ReadingProgress(defaults: defaults).readLessons(in: ncle, on: today).isEmpty)
    }

    func testFoundationsPrecedeAppliedLessons() {
        let textbook = Textbook.shared
        for exam in ExamID.allCases {
            XCTAssertEqual(textbook.chapters(for: exam).first?.domain, "\(exam.rawValue).anatomy")
        }
        let optics = textbook.chapters.first { $0.domain == "abo.optics" }!
        XCTAssertEqual(textbook.lessons(in: optics).first?.section.heading, "Light, refraction, and index")
        let fitting = textbook.chapters.first { $0.domain == "ncle.fitting" }!
        XCTAssertEqual(textbook.lessons(in: fitting).first?.section.heading, "Selecting and evaluating soft lenses")
    }

    func testManifestRejectsMissingChaptersAndDuplicateLessons() throws {
        let chapters = Textbook.shared.chapters
        XCTAssertThrowsError(try Textbook(chapters: Array(chapters.dropLast()), library: library))
        let bundle = Bundle(for: QuizRecord.self)
        let data = try Data(contentsOf: XCTUnwrap(bundle.url(forResource: "textbook", withExtension: "json")))
        var manifest = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [[String: Any]])
        var order = try XCTUnwrap(manifest[0]["lessonOrder"] as? [Int])
        order[0] = order[1]
        manifest[0]["lessonOrder"] = order
        let invalid = try JSONDecoder().decode([TextbookChapter].self, from: JSONSerialization.data(withJSONObject: manifest))
        XCTAssertThrowsError(try Textbook(chapters: invalid, library: library))
    }

    func testChaptersHaveTeachingIntroductionsAndRecaps() {
        for chapter in Textbook.shared.chapters {
            XCTAssertGreaterThan(chapter.introduction.split { $0.isWhitespace }.count, 100, chapter.id)
            XCTAssertGreaterThanOrEqual(chapter.objectives.count, 3, chapter.id)
            XCTAssertGreaterThanOrEqual(chapter.takeaways.count, 3, chapter.id)
            XCTAssertTrue((chapter.objectives + chapter.takeaways).allSatisfy { !$0.isEmpty })
        }
    }

    @MainActor
    func testOpeningDoesNotCompleteAndProgressSurvivesRelaunch() throws {
        let suite = "TextbookTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let lessons = Textbook.shared.lessons(for: .abo)
        let progress = ReadingProgress(defaults: defaults)
        XCTAssertEqual(progress.resume(in: lessons, exam: .abo)?.id, lessons[0].id)
        progress.open(lessons[3], exam: .abo)
        XCTAssertTrue(progress.completed.isEmpty)
        XCTAssertEqual(progress.resume(in: lessons, exam: .abo)?.id, lessons[3].id)
        progress.setCompleted(lessons[3], true)
        let reloaded = ReadingProgress(defaults: defaults)
        XCTAssertEqual(reloaded.completed, [lessons[3].id])
        XCTAssertEqual(reloaded.lastOpened(for: .abo), lessons[3].id)
        XCTAssertEqual(reloaded.resume(in: lessons, exam: .abo)?.id, lessons[4].id)
    }

    @MainActor
    func testExamBookmarksStayIndependent() throws {
        let suite = "TextbookTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let progress = ReadingProgress(defaults: defaults)
        let abo = Textbook.shared.lessons(for: .abo)
        let ncle = Textbook.shared.lessons(for: .ncle)
        progress.open(abo[2], exam: .abo)
        progress.open(ncle[5], exam: .ncle)
        progress.setCompleted(abo[0], true)
        XCTAssertEqual(progress.resume(in: abo, exam: .abo)?.id, abo[2].id)
        XCTAssertEqual(progress.resume(in: ncle, exam: .ncle)?.id, ncle[5].id)
        XCTAssertTrue(ncle.allSatisfy { !progress.completed.contains($0.id) })
    }

    @MainActor
    func testResumeFindsEarlierGapsAndCompletedTrackCanBeReviewed() throws {
        let suite = "TextbookTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let progress = ReadingProgress(defaults: defaults)
        let lessons = Textbook.shared.lessons(for: .abo)
        let last = try XCTUnwrap(lessons.last)
        progress.open(last, exam: .abo)
        progress.setCompleted(last, true)
        XCTAssertEqual(progress.resume(in: lessons, exam: .abo)?.id, lessons[0].id)
        lessons.forEach { progress.setCompleted($0, true) }
        XCTAssertEqual(progress.resume(in: lessons, exam: .abo)?.id, lessons[0].id)
        progress.setCompleted(lessons[2], false)
        XCTAssertEqual(progress.resume(in: lessons, exam: .abo)?.id, lessons[2].id)
        progress.reset()
        let reloaded = ReadingProgress(defaults: defaults)
        XCTAssertTrue(reloaded.completed.isEmpty)
        XCTAssertNil(reloaded.lastOpened(for: .abo))
        XCTAssertEqual(reloaded.resume(in: lessons, exam: .abo)?.id, lessons[0].id)
    }
}
