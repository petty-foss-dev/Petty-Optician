import XCTest
@testable import PettyOptician

final class LensComplicationTests: XCTestCase {
    func testEachComplicationHasExactlyOneCorrectNameAndAction() {
        var rng = SystemRandomNumberGenerator()
        for complication in LensComplication.allCases {
            for _ in 0..<50 {
                let names = complication.nameChoices(using: &rng)
                let actions = complication.actionChoices(using: &rng)
                XCTAssertEqual(names.filter { $0 == complication }.count, 1)
                XCTAssertEqual(actions.filter { $0 == complication.action }.count, 1)
            }
        }
    }

    func testChoicesAreFourUniqueAndIncludeTheAnswer() {
        var rng = SystemRandomNumberGenerator()
        for complication in LensComplication.allCases {
            for _ in 0..<50 {
                let names = complication.nameChoices(using: &rng)
                let actions = complication.actionChoices(using: &rng)
                XCTAssertEqual(names.count, 4)
                XCTAssertEqual(Set(names).count, 4)
                XCTAssertTrue(names.contains(complication))
                XCTAssertEqual(actions.count, 4)
                XCTAssertEqual(Set(actions).count, 4)
                XCTAssertTrue(actions.contains(complication.action))
            }
        }
    }

    func testDistractorPoolsNeverContainTheAnswer() {
        for complication in LensComplication.allCases {
            XCTAssertGreaterThanOrEqual(Set(complication.confusers).count, 3)
            XCTAssertEqual(Set(complication.confusers).count, complication.confusers.count)
            XCTAssertFalse(complication.confusers.contains(complication))
            XCTAssertGreaterThanOrEqual(Set(complication.actionDistractors).count, 3)
            XCTAssertEqual(Set(complication.actionDistractors).count, complication.actionDistractors.count)
            XCTAssertFalse(complication.actionDistractors.contains(complication.action))
        }
    }

    func testOnlyMicrobialKeratitisCallsForAnEmergency() {
        XCTAssertEqual(LensComplication.microbialKeratitis.action, .urgentReferral)
        XCTAssertTrue(LensComplication.microbialKeratitis.actionDistractors.contains(.promptReferral))
        XCTAssertTrue(LensComplication.microbialKeratitis.actionDistractors.contains(.patchOvernight))
        for complication in LensComplication.allCases where complication != .microbialKeratitis {
            XCTAssertNotEqual(complication.action, .urgentReferral)
            XCTAssertFalse(complication.actionDistractors.contains(.urgentReferral))
        }
    }

    func testNeverCorrectActionsExplainThemselves() {
        let answers = Set(LensComplication.allCases.map(\.action))
        for action in LensAction.allCases {
            XCTAssertEqual(action.pitfall == nil, answers.contains(action), action.rawValue)
        }
    }

    func testGradingAcceptsTheAnswerAndRejectsEverythingElse() {
        for complication in LensComplication.allCases {
            for grade in EfronGrade.allCases {
                let problem = LensProblemCase(complication: complication, grade: grade, rightEye: true, seed: 7)
                let right = problem.result(name: complication, grade: grade, action: complication.action)
                XCTAssertEqual(right, .init(name: true, grade: true, action: true))
                XCTAssertEqual(right.points, 3)
                for other in LensComplication.allCases where other != complication {
                    XCTAssertFalse(problem.result(name: other, grade: grade, action: complication.action).name)
                }
                for other in EfronGrade.allCases where other != grade {
                    XCTAssertFalse(problem.result(name: complication, grade: other, action: complication.action).grade)
                }
                for other in LensAction.allCases where other != complication.action {
                    let result = problem.result(name: complication, grade: grade, action: other)
                    XCTAssertFalse(result.action)
                    XCTAssertEqual(result.points, 2)
                }
            }
        }
    }

    func testDrawnSeverityGrowsWithEachGrade() {
        for complication in LensComplication.allCases {
            let magnitudes = EfronGrade.allCases.map { LesionSeverity(complication, grade: $0).magnitude }
            XCTAssertTrue(zip(magnitudes, magnitudes.dropFirst()).allSatisfy { $0 < $1 }, complication.rawValue)
            XCTAssertEqual(Set(EfronGrade.allCases.map { complication.gradeCue($0) }).count, 4)
        }
    }

    func testLesionSizesMatchTheTextbookCutoffs() {
        XCTAssertTrue(EfronGrade.allCases.allSatisfy { LesionSeverity(.clpu, grade: $0).lesionSize < 2 })
        XCTAssertTrue(EfronGrade.allCases.allSatisfy { LesionSeverity(.microbialKeratitis, grade: $0).lesionSize > 1 })
        XCTAssertGreaterThan(LesionSeverity(.papillaryConjunctivitis, grade: .severe).papillaSize, 1)
        XCTAssertEqual(LesionSeverity(.edema, grade: .trace).striae, 0)
        XCTAssertGreaterThan(LesionSeverity(.edema, grade: .severe).folds, 0)
        XCTAssertGreaterThan(LesionSeverity(.microbialKeratitis, grade: .severe).hypopyon, 0)
    }

    func testRandomCasesSkipThePreviousComplication() {
        var rng = SystemRandomNumberGenerator()
        for complication in LensComplication.allCases {
            for _ in 0..<30 {
                XCTAssertNotEqual(LensProblemCase.random(excluding: complication, using: &rng).complication, complication)
            }
        }
    }

    func testEveryComplicationHasHistoriesCuesAndSources() {
        for complication in LensComplication.allCases {
            XCTAssertFalse(complication.histories.isEmpty)
            XCTAssertFalse(complication.sources.isEmpty)
            for seed: UInt64 in 0..<4 {
                let problem = LensProblemCase(complication: complication, grade: .mild, rightEye: false, seed: seed)
                XCTAssertTrue(complication.histories.contains(problem.history))
            }
        }
    }
}
