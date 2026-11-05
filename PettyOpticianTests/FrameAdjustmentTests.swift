import XCTest
@testable import PettyOptician

final class FrameAdjustmentTests: XCTestCase {
    func testEveryFaultHasFourUniqueChoicesIncludingTheFix() {
        XCTAssertEqual(Set(FrameFitFault.all).count, FrameFitFault.all.count)
        for fault in FrameFitFault.all {
            let choices = FrameAdjustmentTrainerView.choices(for: fault)
            XCTAssertEqual(choices.count, 4, "\(fault)")
            XCTAssertEqual(Set(choices.map(\.text)).count, 4, "\(fault) duplicate choices: \(choices)")
            XCTAssertTrue(choices.contains(fault.fix), "\(fault)")
            XCTAssertFalse(fault.distractors.contains(fault.fix), "\(fault)")
        }
    }

    func testSideDependentFaultsCoverBothSides() {
        for side in FrameFitSide.allCases {
            XCTAssertTrue(FrameFitFault.all.contains(.sitsHigher(side)))
            XCTAssertTrue(FrameFitFault.all.contains(.lensCloser(side)))
        }
    }

    func testHighSideTempleGoesUp() {
        XCTAssertEqual(FrameFitFault.sitsHigher(.right).fix, .raiseTemple(.right))
        XCTAssertEqual(FrameFitFault.sitsHigher(.left).fix, .raiseTemple(.left))
        XCTAssertEqual(FrameFitFault.sitsHigher(.right).distractors.first, .raiseTemple(.left))
        XCTAssertEqual(FrameFitFault.sitsHigher(.left).distractors.first, .raiseTemple(.right))

        let right = FrameFitAdjustment.raiseTemple(.right).text
        XCTAssertTrue(right.contains("right temple up"))
        XCTAssertTrue(right.contains("left temple down"))
        let left = FrameFitAdjustment.raiseTemple(.left).text
        XCTAssertTrue(left.contains("left temple up"))
        XCTAssertTrue(left.contains("right temple down"))
    }

    func testCloserLensTempleAngledIn() {
        XCTAssertEqual(FrameFitFault.lensCloser(.right).fix, .angleTempleIn(.right))
        XCTAssertEqual(FrameFitFault.lensCloser(.left).fix, .angleTempleIn(.left))
        XCTAssertEqual(FrameFitFault.lensCloser(.right).distractors.first, .angleTempleIn(.left))
        XCTAssertEqual(FrameFitFault.lensCloser(.left).distractors.first, .angleTempleIn(.right))

        let right = FrameFitAdjustment.angleTempleIn(.right).text
        XCTAssertTrue(right.contains("right temple in"))
        XCTAssertTrue(right.contains("left temple out"))
        XCTAssertTrue(FrameFitAdjustment.angleTempleIn(.left).text.contains("left temple in"))
    }

    func testDrawingRaisesThePatientsSideOnTheViewersLeft() {
        // Patient's right is drawn on the viewer's left; in both views a smaller y is higher or closer to the eye.
        let viewerLeft = CGPoint(x: 90, y: 150), viewerRight = CGPoint(x: 230, y: 150)
        for fault in [FrameFitFault.sitsHigher(.right), .lensCloser(.right)] {
            let t = FrameFitArt.tiltTransform(for: fault)
            XCTAssertLessThan(viewerLeft.applying(t).y, viewerRight.applying(t).y, "\(fault)")
        }
        for fault in [FrameFitFault.sitsHigher(.left), .lensCloser(.left)] {
            let t = FrameFitArt.tiltTransform(for: fault)
            XCTAssertGreaterThan(viewerLeft.applying(t).y, viewerRight.applying(t).y, "\(fault)")
        }
        XCTAssertEqual(FrameFitArt.tiltTransform(for: .sitsTooLow), .identity)
    }
}
