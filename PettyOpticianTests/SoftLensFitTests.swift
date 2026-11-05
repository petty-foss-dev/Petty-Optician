import XCTest
@testable import PettyOptician

final class SoftLensFitTests: XCTestCase {
    private let variations: [SoftLensCase.Variation] = [0.0, 0.5, 1].flatMap { amount in
        [0.0, 1].flatMap { timing in
            [SIMD2<Double>(-1, -1), [1, 1], [0, 0], [1, -1]].flatMap { offset in
                LensDecentration.allCases.map {
                    SoftLensCase.Variation(amount: amount, timing: timing, offset: offset, decentration: $0)
                }
            }
        }
    }

    private func cases(_ fit: SoftLensFit) -> [SoftLensCase] {
        variations.map { SoftLensCase(fit: fit, variation: $0) }
    }

    func testChoicesAreFourUniqueAndIncludeTheAnswer() {
        for fit in SoftLensFit.allCases {
            for _ in 0..<20 {
                let choices = SoftLensFitTrainerView.choices(for: fit)
                XCTAssertEqual(choices.count, 4)
                XCTAssertEqual(Set(choices).count, 4)
                XCTAssertTrue(choices.contains(fit))
            }
        }
    }

    func testBlinkMovementMatchesTheFit() {
        let good = cases(.good).map(\.movement)
        let tight = cases(.tight).map(\.movement)
        let loose = cases(.loose).map(\.movement)
        XCTAssertTrue(good.allSatisfy { (0.2...0.4).contains($0) })
        XCTAssertLessThan(tight.max()!, 0.1)
        XCTAssertGreaterThan(loose.min()!, 0.5)
        XCTAssertLessThan(tight.max()!, good.min()!)
        XCTAssertGreaterThan(loose.min()!, good.max()!)
    }

    func testBlinkLiftPeaksAtMovementAndSettlesToRest() {
        for fit in SoftLensFit.allCases {
            for lens in cases(fit) {
                let peak = stride(from: 0.0, to: lens.blinkInterval, by: 0.01).map { lens.blinkLift($0) }.max()!
                XCTAssertEqual(peak, lens.movement, accuracy: 1e-6)
                let settled = lens.scene(at: SoftLensCase.firstBlink + lens.blinkInterval - 0.01)
                XCTAssertEqual(settled.lens.x, lens.rest.x, accuracy: 1e-9)
                XCTAssertEqual(settled.lens.y, lens.rest.y, accuracy: 0.01)
                XCTAssertEqual(settled.upperLid, SoftLensCase.upperLidRest, accuracy: 1e-9)
            }
        }
    }

    func testPushUpResistanceAndRecoveryOrdering() {
        let good = cases(.good), tight = cases(.tight), loose = cases(.loose)
        XCTAssertLessThan(tight.map(\.pushUpLift).max()!, good.map(\.pushUpLift).min()!)
        XCTAssertGreaterThan(loose.map(\.pushUpLift).min()!, good.map(\.pushUpLift).max()!)
        XCTAssertLessThan(loose.map(\.recoveryTime).max()!, good.map(\.recoveryTime).min()!)
        XCTAssertLessThan(good.map(\.recoveryTime).max()!, tight.map(\.recoveryTime).min()!)
    }

    func testLooseRecoveryOvershootsWhileOthersReturnSmoothly() {
        for lens in cases(.loose) {
            let samples = stride(from: 0.0, to: lens.recoveryTau * 5, by: 0.01).map { lens.pushUp(SoftLensCase.holdEnd + $0).lift }
            XCTAssertLessThan(samples.min()!, 0)
        }
        for fit in [SoftLensFit.good, .tight, .decentered] {
            for lens in cases(fit) {
                let samples = stride(from: 0.0, to: lens.recoveryTau * 5, by: 0.01).map { lens.pushUp(SoftLensCase.holdEnd + $0).lift }
                XCTAssertTrue(zip(samples, samples.dropFirst()).allSatisfy { $0 >= $1 && $1 >= 0 })
            }
        }
    }

    func testPushUpEndsBackAtRest() {
        for fit in SoftLensFit.allCases {
            for lens in cases(fit) {
                let end = lens.pushUp(lens.pushUpDuration)
                XCTAssertEqual(end.lid, SoftLensCase.lowerLidRest, accuracy: 1e-9)
                XCTAssertLessThan(abs(end.lift), 0.02)
                XCTAssertTrue(lens.scene(at: 0, pushUpElapsed: 0.6).pushing)
            }
        }
    }

    func testDecenteredLensSettlesOffCenterExposingTheLimbus() {
        for lens in cases(.decentered) {
            let direction = lens.decentration!.direction
            XCTAssertTrue(lens.exposesLimbus)
            XCTAssertGreaterThan((lens.rest * direction).sum(), SoftLensCase.lensRadius - SoftLensCase.corneaRadius)
            XCTAssertEqual(lens.scene(at: 0.5).lens, lens.rest)
        }
        for fit in [SoftLensFit.good, .tight, .loose] {
            XCTAssertTrue(cases(fit).allSatisfy { !$0.exposesLimbus && $0.decentration == nil })
        }
        XCTAssertLessThan(cases(.good).map(\.offCenter).max()!, cases(.decentered).map(\.offCenter).min()!)
    }

    func testLooseLensRidesLow() {
        XCTAssertTrue(cases(.loose).allSatisfy { $0.rest.y > 0.4 })
    }
}
