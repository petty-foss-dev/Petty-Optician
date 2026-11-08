import XCTest
@testable import PettyOptician

final class LensChoiceTests: XCTestCase {
    private func named(_ id: String) -> LensChoiceCase {
        LensChoice.cases.first { $0.id == id }!
    }

    private func idealGrade(_ lensCase: LensChoiceCase) -> LensChoiceResult {
        LensChoice.grade(
            lensCase, material: lensCase.bestMaterial!, design: lensCase.bestDesign!,
            treatments: Set(lensCase.packageTreatments), frame: lensCase.bestFrame!
        )
    }

    func testAtLeastFifteenCasesWithUniqueIDs() {
        XCTAssertGreaterThanOrEqual(LensChoice.cases.count, 15)
        XCTAssertEqual(Set(LensChoice.cases.map(\.id)).count, LensChoice.cases.count)
    }

    func testEveryOptionIsJudgedWithAReason() {
        for lensCase in LensChoice.cases {
            XCTAssertEqual(Set(lensCase.materials.keys), Set(LensMaterial.allCases), lensCase.id)
            XCTAssertEqual(Set(lensCase.designs.keys), Set(LensDesign.allCases), lensCase.id)
            XCTAssertEqual(Set(lensCase.treatments.keys), Set(LensTreatment.allCases), lensCase.id)
            XCTAssertEqual(Set(lensCase.frames.keys), Set(FrameAdvice.allCases), lensCase.id)
            let reasons = lensCase.materials.values.map(\.reason) + lensCase.designs.values.map(\.reason)
                + lensCase.frames.values.map(\.reason) + lensCase.treatments.values.map(\.reason)
            XCTAssertTrue(reasons.allSatisfy { !$0.isEmpty }, lensCase.id)
        }
    }

    func testExactlyOneBestMaterialDesignAndFrame() {
        for lensCase in LensChoice.cases {
            XCTAssertEqual(lensCase.materials.values.filter { $0.rating == .best }.count, 1, lensCase.id)
            XCTAssertEqual(lensCase.designs.values.filter { $0.rating == .best }.count, 1, lensCase.id)
            XCTAssertEqual(lensCase.frames.values.filter { $0.rating == .best }.count, 1, lensCase.id)
        }
    }

    func testIntendedPackageGradesBest() {
        for lensCase in LensChoice.cases {
            let result = idealGrade(lensCase)
            XCTAssertEqual(result.overall, .best, lensCase.id)
            XCTAssertEqual(result.items.count, 3 + LensTreatment.allCases.count, lensCase.id)
            XCTAssertFalse(result.sources.isEmpty, lensCase.id)
        }
    }

    func testObviouslyWrongPicksGradePoor() {
        let child = named("child-soccer")
        XCTAssertEqual(child.materials[.cr39]?.rating, .poor)
        XCTAssertEqual(child.materials[.crownGlass]?.rating, .poor)
        let childResult = LensChoice.grade(child, material: .cr39, design: .svAspheric, treatments: [.scratchCoat, .antiReflective, .uv], frame: .smaller)
        XCTAssertEqual(childResult.overall, .poor)
        XCTAssertEqual(childResult.items.first { $0.id == "material" }?.rating, .poor)

        let safety = named("machinist-safety")
        let safetyResult = LensChoice.grade(safety, material: .crownGlass, design: .svSpherical, treatments: [.scratchCoat], frame: .asChosen)
        XCTAssertEqual(safetyResult.overall, .poor)

        XCTAssertEqual(named("rimless-drill").materials[.cr39]?.rating, .poor)
        XCTAssertEqual(named("chromatic-poly").materials[.polycarbonate]?.rating, .poor)
        XCTAssertEqual(named("high-minus").frames[.asChosen]?.rating, .poor)
        XCTAssertEqual(named("aphakic-high-plus").designs[.svSpherical]?.rating, .poor)
    }

    func testImpactCriticalCasesRequirePolyOrTrivex() {
        for id in ["child-soccer", "toddler-plus", "accommodative-esotropia", "machinist-safety", "monocular"] {
            let lensCase = named(id)
            XCTAssertTrue([LensMaterial.polycarbonate, .trivex].contains(lensCase.bestMaterial!), id)
            for material in [LensMaterial.cr39, .highIndex167, .highIndex174, .crownGlass] {
                XCTAssertEqual(lensCase.materials[material]?.rating, .poor, "\(id) \(material)")
            }
        }
    }

    func testSunAndScreenTreatmentRules() {
        let pilot = named("pilot-sun")
        XCTAssertEqual(LensChoice.grade(pilot, material: .trivex, design: .svSpherical, treatments: [.sunTint, .uv, .polarized], frame: .asChosen).overall, .poor)
        XCTAssertEqual(pilot.treatments[.photochromic]?.rating(selected: true), .poor)

        let driver = named("driving-photochromic")
        XCTAssertEqual(driver.treatments[.polarized]?.rating(selected: false), .poor)
        XCTAssertEqual(driver.treatments[.photochromic]?.rating(selected: true), .acceptable)

        XCTAssertEqual(named("computer-occupational").treatments[.polarized]?.rating(selected: true), .poor)
        XCTAssertEqual(named("aphakic-high-plus").treatments[.uv]?.rating(selected: false), .poor)
    }

    func testNoAddCasesRejectMultifocals() {
        for lensCase in LensChoice.cases where !lensCase.rx.contains("Add") {
            for design in [LensDesign.progressive, .occupational, .flatTop, .executive] {
                XCTAssertEqual(lensCase.designs[design]?.rating, .poor, "\(lensCase.id) \(design)")
            }
        }
    }

    func testTreatmentAdviceRatings() {
        let cases: [(TreatmentRule.Advice, LensRating, LensRating)] = [
            (.essential, .best, .poor),
            (.recommended, .best, .acceptable),
            (.optional, .best, .best),
            (.unnecessary, .acceptable, .best),
            (.avoid, .poor, .best),
        ]
        for (advice, on, off) in cases {
            let rule = TreatmentRule(advice: advice, reason: "r", source: .materials)
            XCTAssertEqual(rule.rating(selected: true), on)
            XCTAssertEqual(rule.rating(selected: false), off)
        }
    }
}
