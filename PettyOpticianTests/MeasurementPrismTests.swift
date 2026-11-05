import XCTest
@testable import PettyOptician

final class MeasurementPrismTests: XCTestCase {
    private func patient() -> PDMeasurePatient {
        PDMeasurePatient(
            rightPD: 31, leftPD: 32.5, rightPupilHeight: 20, leftPupilHeight: 19.5, irisRadius: 6,
            eyeSize: 52, lensHeight: 34, bridge: 18, workingDistanceMM: 400
        )
    }

    private func lens(_ eye: PrismTrainerEye, _ power: Double, x: Double = 0, y: Double = 0, cylinder: Double = 0, axis: Int = 180) -> PrismTrainerLens {
        PrismTrainerLens(eye: eye, rx: SpheroCylinder(sphere: power, cylinder: cylinder, axis: axis), pupilX: x, pupilY: y)
    }

    func testToleranceScoring() {
        XCTAssertTrue(PDMeasureTrainerView.isWithin(31, of: 32, tolerance: 1))
        XCTAssertTrue(PDMeasureTrainerView.isWithin(33, of: 32, tolerance: 1))
        XCTAssertFalse(PDMeasureTrainerView.isWithin(30.5, of: 32, tolerance: 1))
        XCTAssertTrue(PDMeasureTrainerView.isWithin(60.4, of: 59.95, tolerance: 0.5))
        XCTAssertFalse(PDMeasureTrainerView.isWithin(60.5, of: 59.95, tolerance: 0.5))

        let targets = PDMeasureTrainerView.targets(for: .monocularPD, patient: patient())
        XCTAssertTrue(PDMeasureTrainerView.isCorrect([31.5, 32], targets: targets))
        XCTAssertFalse(PDMeasureTrainerView.isCorrect([31.5, 34], targets: targets))
        XCTAssertFalse(PDMeasureTrainerView.isCorrect([31.5], targets: targets))
    }

    func testTargetsFollowConventions() {
        let p = patient()
        XCTAssertEqual(PDMeasureTrainerView.targets(for: .binocularPD, patient: p).map(\.value), [63.5])
        XCTAssertEqual(PDMeasureTrainerView.targets(for: .bifocalSegHeight, patient: p).map(\.value), [14, 13.5])
        XCTAssertEqual(PDMeasureTrainerView.targets(for: .progressiveFittingHeight, patient: p).map(\.value), [20, 19.5])
        let near = PDMeasureTrainerView.targets(for: .nearPD, patient: p)
        XCTAssertEqual(near.first?.value ?? 0, OpticsMath.nearPD(distancePD: 63.5, workingDistanceMM: 400), accuracy: 1e-9)
        XCTAssertEqual(near.first?.value ?? 0, 63.5 * 400 / 427, accuracy: 1e-9)
        XCTAssertEqual(near.first?.tolerance, 0.5)
    }

    func testRulerMapping() {
        let scale = PDMeasureScale(size: CGSize(width: 312, height: 152))
        XCTAssertEqual(scale.pointsPerMM, 2, accuracy: 1e-9)
        let origin = scale.point(.zero)
        XCTAssertEqual(origin.x, 156, accuracy: 1e-9)
        XCTAssertEqual(origin.y, 108, accuracy: 1e-9)
        let up = scale.point(CGPoint(x: 10, y: 5))
        XCTAssertEqual(up.x - origin.x, 20, accuracy: 1e-9)
        XCTAssertEqual(origin.y - up.y, 10, accuracy: 1e-9)

        for mm in [CGPoint(x: -31.5, y: 20), CGPoint(x: 64, y: -12), CGPoint(x: 0.25, y: 47)] {
            let back = scale.mm(scale.point(mm))
            XCTAssertEqual(back.x, mm.x, accuracy: 1e-9)
            XCTAssertEqual(back.y, mm.y, accuracy: 1e-9)
        }

        XCTAssertEqual(PDMeasureScale.reading(31.26), 31.5)
        XCTAssertEqual(PDMeasureScale.reading(31.2), 31)
        XCTAssertEqual(PDMeasureScale.clamped(CGPoint(x: 200, y: -200)), CGPoint(x: 76, y: -20))
    }

    func testMarkerReadings() {
        let p = patient()
        let markers = [CGPoint(x: -31.1, y: 14.1), CGPoint(x: 32.4, y: 13.6)]
        XCTAssertEqual(PDMeasureTrainerView.answers(from: markers, task: .binocularPD, patient: p), [63.5])
        XCTAssertEqual(PDMeasureTrainerView.answers(from: markers, task: .monocularPD, patient: p), [31, 32.5])
        XCTAssertEqual(PDMeasureTrainerView.answers(from: markers, task: .bifocalSegHeight, patient: p), [14, 13.5])
        XCTAssertEqual(PDMeasureTrainerView.answers(from: [], task: .nearPD, patient: p), [63.5])
    }

    func testRandomPatientsFitTheFrame() {
        for _ in 0..<300 {
            let p = PDMeasureTrainerView.randomPatient()
            for (mono, height) in [(p.rightPD, p.rightPupilHeight), (p.leftPD, p.leftPupilHeight)] {
                XCTAssertGreaterThan(mono - p.irisRadius, p.bridge / 2)
                XCTAssertLessThan(mono + p.irisRadius, p.bridge / 2 + p.eyeSize)
                XCTAssertGreaterThan(height - p.irisRadius, 5)
                XCTAssertLessThan(height + p.irisRadius, p.lensHeight)
            }
            XCTAssertTrue((54...76).contains(p.binocularPD))
            for task in PDMeasureTask.allCases {
                let round = PDMeasureTrainerView.newRound(task: task)
                XCTAssertEqual(round.answers.count, PDMeasureTrainerView.targets(for: task, patient: round.patient).count)
            }
        }
    }

    func testHorizontalBaseDirection() {
        // Facing the patient: OD temporal is the optician's left (−x), OS temporal is the optician's right (+x).
        XCTAssertEqual(PrismDirectionTrainerView.horizontalBase(power: 4, eye: .od, pupilX: -3), .baseIn)
        XCTAssertEqual(PrismDirectionTrainerView.horizontalBase(power: 4, eye: .od, pupilX: 3), .baseOut)
        XCTAssertEqual(PrismDirectionTrainerView.horizontalBase(power: -4, eye: .od, pupilX: -3), .baseOut)
        XCTAssertEqual(PrismDirectionTrainerView.horizontalBase(power: -4, eye: .od, pupilX: 3), .baseIn)
        XCTAssertEqual(PrismDirectionTrainerView.horizontalBase(power: 4, eye: .os, pupilX: 3), .baseIn)
        XCTAssertEqual(PrismDirectionTrainerView.horizontalBase(power: 4, eye: .os, pupilX: -3), .baseOut)
        XCTAssertEqual(PrismDirectionTrainerView.horizontalBase(power: -4, eye: .os, pupilX: 3), .baseOut)
        XCTAssertEqual(PrismDirectionTrainerView.horizontalBase(power: -4, eye: .os, pupilX: -3), .baseIn)
        XCTAssertNil(PrismDirectionTrainerView.horizontalBase(power: 4, eye: .od, pupilX: 0))
        XCTAssertNil(PrismDirectionTrainerView.horizontalBase(power: 0, eye: .os, pupilX: 3))
    }

    func testVerticalBaseDirection() {
        for eye in PrismTrainerEye.allCases {
            XCTAssertEqual(lens(eye, 2, y: -5).verticalEffect?.base, .baseUp)
            XCTAssertEqual(lens(eye, 2, y: 5).verticalEffect?.base, .baseDown)
            XCTAssertEqual(lens(eye, -2, y: -5).verticalEffect?.base, .baseDown)
            XCTAssertEqual(lens(eye, -2, y: 5).verticalEffect?.base, .baseUp)
        }
        XCTAssertEqual(lens(.od, 2, y: -5).verticalEffect?.amount ?? 0, 1, accuracy: 1e-9)
    }

    func testPrenticeUsesMeridianPower() {
        let horizontal = lens(.od, -1, x: 4, cylinder: -2, axis: 90)
        XCTAssertEqual(horizontal.horizontalPower, -3, accuracy: 1e-9)
        XCTAssertEqual(horizontal.horizontalEffect?.amount ?? 0, 1.2, accuracy: 1e-9)
        XCTAssertEqual(horizontal.horizontalEffect?.base, .baseIn)

        let vertical = lens(.os, 1, y: -5, cylinder: -3, axis: 180)
        XCTAssertEqual(vertical.verticalPower, -2, accuracy: 1e-9)
        XCTAssertEqual(vertical.verticalEffect?.amount ?? 0, 1, accuracy: 1e-9)
        XCTAssertEqual(vertical.verticalEffect?.base, .baseDown)
    }

    func testNetHorizontalPrism() {
        let compounding = PrismDirectionTrainerView.netHorizontal(od: lens(.od, -2, x: -4), os: lens(.os, -3, x: 5))
        XCTAssertEqual(compounding, -2.3, accuracy: 1e-9)

        let canceling = PrismDirectionTrainerView.netHorizontal(od: lens(.od, 4, x: 2), os: lens(.os, 5, x: 1))
        XCTAssertEqual(canceling, -0.3, accuracy: 1e-9)
    }

    func testNetVerticalPrism() {
        let compounding = PrismDirectionTrainerView.netVertical(od: lens(.od, 2, y: -5), os: lens(.os, -1, y: -5))
        XCTAssertEqual(compounding, 1.5, accuracy: 1e-9)

        let canceling = PrismDirectionTrainerView.netVertical(od: lens(.od, 2, y: -5), os: lens(.os, 1, y: -5))
        XCTAssertEqual(canceling, 0.5, accuracy: 1e-9)

        let osLarger = PrismDirectionTrainerView.netVertical(od: lens(.od, -1, y: 5), os: lens(.os, -3, y: 5))
        XCTAssertEqual(osLarger, -1, accuracy: 1e-9)
    }

    func testChoicesAreUniqueAndContainAnswer() {
        XCTAssertEqual(Set(PrismDirectionTrainerView.choices(answer: "a", distractors: ["b", "a", "b", "c", "d", "e"])), ["a", "b", "c", "d"])
        for kind in PrismTrainerQuestion.Kind.allCases {
            for _ in 0..<200 {
                let question = PrismDirectionTrainerView.randomQuestion(kind: kind)
                XCTAssertEqual(question.kind, kind)
                XCTAssertEqual(question.choices.count, 4, question.prompt)
                XCTAssertEqual(Set(question.choices).count, 4, question.prompt)
                XCTAssertTrue(question.choices.contains(question.answer), question.prompt)
            }
        }
    }

    func testSingleLensAnswerMatchesRule() throws {
        for _ in 0..<200 {
            let question = PrismDirectionTrainerView.singleQuestion()
            let lens = try XCTUnwrap(question.lenses.first)
            let effect = try XCTUnwrap(lens.pupilX != 0 ? lens.horizontalEffect : lens.verticalEffect)
            XCTAssertEqual(question.answer, PrismDirectionTrainerView.label(effect.amount, effect.base))
            let towardOC = lens.pupilX != 0
                ? (effect.base == .baseIn) == ((lens.eye == .od) == (lens.pupilX < 0))
                : (effect.base == .baseUp) == (lens.pupilY < 0)
            XCTAssertEqual(towardOC, effect.power > 0)
        }
    }
}
