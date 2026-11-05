import XCTest
@testable import EnveOptician

final class ContentTests: XCTestCase {
    private var library: ContentLibrary!

    override func setUpWithError() throws {
        library = try ContentLibrary.load(from: Bundle(for: QuizRecord.self))
    }

    func testBothExamsHaveDomains() {
        for exam in ExamID.allCases {
            XCTAssertFalse(library.domains(for: exam).isEmpty, "\(exam) has no domains")
        }
    }

    func testIdentifiersAreUnique() {
        for (name, ids) in [
            ("questions", library.questions.map(\.id)),
            ("flashcards", library.flashcards.map(\.id)),
            ("guides", library.guides.map(\.id)),
            ("resources", library.resources.map(\.id))
        ] {
            let duplicates = Dictionary(grouping: ids, by: { $0 }).filter { $0.value.count > 1 }.keys
            XCTAssertTrue(duplicates.isEmpty, "Duplicate \(name) ids: \(duplicates.sorted())")
        }
    }

    func testQuestionsAreWellFormed() {
        let validDomains = Set(library.exams.flatMap { $0.domains.map(\.id) })
        for q in library.questions {
            XCTAssertEqual(q.choices.count, 4, q.id)
            XCTAssertTrue(q.choices.indices.contains(q.answer), q.id)
            XCTAssertEqual(Set(q.choices).count, q.choices.count, "Repeated choice in \(q.id)")
            XCTAssertTrue((1...3).contains(q.difficulty), q.id)
            XCTAssertTrue(validDomains.contains(q.domain), "Unknown domain \(q.domain) in \(q.id)")
            XCTAssertTrue(q.domain.hasPrefix(q.exam.rawValue + "."), "Exam/domain mismatch in \(q.id)")
            XCTAssertFalse(q.explanation.isEmpty, q.id)
        }
    }

    func testCardsGuidesAndResourcesReferenceKnownDomains() {
        let validDomains = Set(library.exams.flatMap { $0.domains.map(\.id) })
        for card in library.flashcards {
            XCTAssertTrue(validDomains.contains(card.domain), card.id)
        }
        for guide in library.guides {
            XCTAssertTrue(validDomains.contains(guide.domain), guide.id)
            XCTAssertFalse(guide.sections.isEmpty, guide.id)
        }
        for resource in library.resources {
            XCTAssertFalse(resource.exams.isEmpty, resource.id)
            for domain in resource.domains ?? [] {
                XCTAssertTrue(validDomains.contains(domain), "\(resource.id): \(domain)")
            }
        }
    }

    func testDiagramReferencesResolve() {
        let known = Set(library.diagrams.map(\.id))
        XCTAssertFalse(known.isEmpty)
        for diagram in library.diagrams {
            XCTAssertFalse(diagram.sources?.isEmpty ?? true, "\(diagram.id) has no sources")
        }
        for q in library.questions {
            if let d = q.diagram { XCTAssertTrue(known.contains(d), "\(q.id): \(d)") }
        }
        for guide in library.guides {
            for section in guide.sections {
                if let d = section.diagram { XCTAssertTrue(known.contains(d), "\(guide.id): \(d)") }
            }
        }
    }

    func testImagesAreBundledAndCredited() {
        let validDomains = Set(library.exams.flatMap { $0.domains.map(\.id) })
        XCTAssertFalse(library.images.isEmpty)
        for image in library.images {
            XCTAssertNotNil(image.url, "\(image.file) missing from bundle")
            XCTAssertFalse(image.credit.isEmpty, image.id)
            XCTAssertTrue(image.license == "Public domain" || image.licenseURL != nil, image.id)
            for domain in image.domains { XCTAssertTrue(validDomains.contains(domain), "\(image.id): \(domain)") }
        }
    }

    func testEveryOfficialSectionHasAGuideAndQuestions() {
        for exam in library.exams {
            for domain in exam.domains {
                XCTAssertNotNil(library.guide(for: domain.id), domain.id)
                XCTAssertFalse(library.questions(for: exam.id, domain: domain.id).isEmpty, domain.id)
            }
        }
    }

    func testSearchFindsStandardsAndSynonyms() {
        XCTAssertFalse(library.search("ANSI", exam: .abo).sections.isEmpty)
        XCTAssertFalse(library.search("diagnosis", exam: .abo).questions.isEmpty)
        XCTAssertFalse(library.search("tear lens", exam: .ncle).questions.isEmpty)
    }

    func testMockExamMatchesPublishedLength() throws {
        for exam in library.exams {
            let mock = QuizBuilder.mockExam(exam, library: library)
            let available = library.questions(for: exam.id).count
            XCTAssertEqual(mock.count, min(exam.totalQuestions ?? 100, available))
            XCTAssertEqual(Set(mock.map(\.id)).count, mock.count)
        }
    }
}

final class OpticsMathTests: XCTestCase {
    func testTransposition() {
        let result = OpticsMath.transpose(SpheroCylinder(sphere: -2.00, cylinder: -1.50, axis: 180))
        XCTAssertEqual(result, SpheroCylinder(sphere: -3.50, cylinder: 1.50, axis: 90))
        XCTAssertEqual(OpticsMath.transpose(SpheroCylinder(sphere: 1, cylinder: 2, axis: 45)).axis, 135)
    }

    func testPrentice() {
        XCTAssertEqual(OpticsMath.prenticePrism(decentrationMM: 5, power: -4), 2, accuracy: 1e-9)
    }

    func testVertexCompensationToContactLens() {
        XCTAssertEqual(OpticsMath.compensatedPower(-6, moveMM: 12), -5.597, accuracy: 0.001)
        XCTAssertEqual(OpticsMath.compensatedPower(8, moveMM: 12), 8.850, accuracy: 0.001)
        XCTAssertEqual(OpticsMath.roundToQuarter(-5.597), -5.5)
    }

    func testObliqueMeridian() {
        let rx = SpheroCylinder(sphere: 1, cylinder: -2, axis: 90)
        XCTAssertEqual(OpticsMath.obliquePower(rx, meridian: 90), 1, accuracy: 1e-9)
        XCTAssertEqual(OpticsMath.obliquePower(rx, meridian: 180), -1, accuracy: 1e-9)
        XCTAssertEqual(OpticsMath.obliquePower(rx, meridian: 60), 0.5, accuracy: 1e-9)
    }

    func testKeratometry() {
        XCTAssertEqual(OpticsMath.keratometricDiopters(radiusMM: 7.5), 45, accuracy: 1e-9)
        XCTAssertGreaterThan(OpticsMath.tearLensPower(baseCurveMM: 7.7, flatKMM: 7.85), 0)
    }

    func testBlankSizeAndNearPD() {
        XCTAssertEqual(OpticsMath.minimumBlankSize(effectiveDiameter: 52, framePD: 68, patientPD: 62), 60)
        XCTAssertEqual(OpticsMath.nearPD(distancePD: 64, workingDistanceMM: 400), 59.95, accuracy: 0.01)
    }

    func testFormatting() {
        XCTAssertEqual(OpticsMath.formatPower(-0.25), "−0.25")
        XCTAssertEqual(OpticsMath.formatPower(2), "+2.00")
        XCTAssertEqual(OpticsMath.formatPower(0), "0.00")
    }
}

final class CardSchedulerTests: XCTestCase {
    private let fresh = CardScheduler.State(ease: CardScheduler.startingEase, intervalDays: 0, reps: 0, lapses: 0)

    func testGoodProgression() {
        let first = CardScheduler.next(fresh, grade: .good)
        XCTAssertEqual(first.intervalDays, 1)
        let second = CardScheduler.next(first, grade: .good)
        XCTAssertEqual(second.intervalDays, 3)
        let third = CardScheduler.next(second, grade: .good)
        XCTAssertEqual(third.intervalDays, 7.5, accuracy: 1e-9)
    }

    func testAgainResetsAndLowersEase() {
        let learned = CardScheduler.next(CardScheduler.next(fresh, grade: .good), grade: .good)
        let lapsed = CardScheduler.next(learned, grade: .again)
        XCTAssertEqual(lapsed.reps, 0)
        XCTAssertEqual(lapsed.lapses, 1)
        XCTAssertLessThan(lapsed.ease, learned.ease)
    }

    func testEaseFloor() {
        var state = fresh
        for _ in 0..<20 { state = CardScheduler.next(state, grade: .again) }
        XCTAssertEqual(state.ease, CardScheduler.minimumEase)
    }
}
