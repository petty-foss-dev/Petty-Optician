import XCTest
@testable import PettyOptician

final class ToricANSITests: XCTestCase {
    private func toric(_ axis: Int, _ rotation: Int, _ direction: ToricRotationDirection) -> ToricRotationProblem {
        ToricRotationProblem(lens: SpheroCylinder(sphere: -2, cylinder: -1.25, axis: axis), rotation: rotation, direction: direction, design: .sixOClock, rightEye: true)
    }

    private func job(_ type: Z80Job.LensType, _ rx: SpheroCylinder, add: Double? = nil, height: Double? = nil) -> Z80Job {
        let lens = Z80Job.Lens(rx: rx, add: add, height: height)
        return Z80Job(
            type: type, ordered: [.od: lens, .os: lens], measured: [.od: lens, .os: lens],
            orderedPrism: nil, measuredPrism: nil,
            pd: type == .progressive ? [.od: 32, .os: 32] : [.od: 64],
            pdError: [.od: 0, .os: 0], prpHeightDifference: 0
        )
    }

    private func passes(_ job: Z80Job, _ id: String) -> Bool {
        job.items.first { $0.id == id }!.passes
    }

    // MARK: LARS

    func testLARSAddsLeftAndSubtractsRight() {
        XCTAssertEqual(toric(180, 10, .left).orderedAxis, 10)
        XCTAssertEqual(toric(90, 30, .left).orderedAxis, 120)
        XCTAssertEqual(toric(90, 15, .right).orderedAxis, 75)
    }

    func testLARSWrapsPast180AndZero() {
        XCTAssertEqual(toric(170, 20, .left).orderedAxis, 10)
        XCTAssertEqual(toric(175, 5, .left).orderedAxis, 180)
        XCTAssertEqual(toric(10, 20, .right).orderedAxis, 170)
        XCTAssertEqual(toric(20, 20, .right).orderedAxis, 180)
    }

    func testToricChoicesIncludeAnswerAndClassicErrors() {
        var rng = SystemRandomNumberGenerator()
        for _ in 0..<500 {
            let problem = ToricRotationProblem.random(using: &rng)
            let choices = problem.choices(using: &rng)
            XCTAssertEqual(choices.count, 4)
            XCTAssertEqual(Set(choices.map(\.axis)).count, 4)
            XCTAssertEqual(choices.filter { $0.mistake == nil }.map(\.axis), [problem.orderedAxis])
            let reversed = OpticsMath.compensatedToricAxis(problem.lens.axis, rotation: problem.rotation, toLeft: problem.direction == .right)
            XCTAssertTrue(choices.contains { $0.axis == reversed })
            XCTAssertTrue((5...30).contains(problem.rotation) && problem.rotation % 5 == 0)
        }
        XCTAssertTrue(toric(175, 10, .left).choices(using: &rng).contains { $0.axis == 185 })
    }

    // MARK: Z80.1 tolerances

    func testSphereTolerance() {
        XCTAssertEqual(Z80Tolerance.sphere(6.5, progressive: false), 0.13, accuracy: 1e-9)
        XCTAssertEqual(Z80Tolerance.sphere(-6.5, progressive: false), 0.13, accuracy: 1e-9)
        XCTAssertEqual(Z80Tolerance.sphere(6.75, progressive: false), 0.135, accuracy: 1e-9)
        XCTAssertEqual(Z80Tolerance.sphere(-8, progressive: false), 0.16, accuracy: 1e-9)
        XCTAssertEqual(Z80Tolerance.sphere(8, progressive: true), 0.16, accuracy: 1e-9)
        XCTAssertEqual(Z80Tolerance.sphere(-8.25, progressive: true), 0.165, accuracy: 1e-9)

        var j = job(.singleVision, SpheroCylinder(sphere: -2, cylinder: 0, axis: 180))
        j.measured[.od]!.rx.sphere = -2.13
        XCTAssertTrue(passes(j, "sphere.od"))
        j.measured[.od]!.rx.sphere = -2.14
        XCTAssertFalse(passes(j, "sphere.od"))

        XCTAssertTrue(Z80Tolerance.within(0.13, Z80Tolerance.sphere(6.75, progressive: false)))
        XCTAssertFalse(Z80Tolerance.within(0.14, Z80Tolerance.sphere(6.75, progressive: false)))
    }

    func testCylinderTolerance() {
        XCTAssertEqual(Z80Tolerance.cylinder(-2, progressive: false), 0.13, accuracy: 1e-9)
        XCTAssertEqual(Z80Tolerance.cylinder(-2.25, progressive: false), 0.15, accuracy: 1e-9)
        XCTAssertEqual(Z80Tolerance.cylinder(-4.5, progressive: false), 0.15, accuracy: 1e-9)
        XCTAssertEqual(Z80Tolerance.cylinder(-4.75, progressive: false), 0.19, accuracy: 1e-9)
        XCTAssertEqual(Z80Tolerance.cylinder(-2, progressive: true), 0.16, accuracy: 1e-9)
        XCTAssertEqual(Z80Tolerance.cylinder(-3.5, progressive: true), 0.18, accuracy: 1e-9)
        XCTAssertEqual(Z80Tolerance.cylinder(-3.75, progressive: true), 0.1875, accuracy: 1e-9)

        var j = job(.singleVision, SpheroCylinder(sphere: -1, cylinder: -3, axis: 90))
        j.measured[.od]!.rx.cylinder = -3.15
        XCTAssertTrue(passes(j, "cylinder.od"))
        j.measured[.od]!.rx.cylinder = -3.16
        XCTAssertFalse(passes(j, "cylinder.od"))
    }

    func testAxisToleranceByCylinder() {
        XCTAssertNil(Z80Tolerance.axis(cylinder: -0.1))
        XCTAssertEqual(Z80Tolerance.axis(cylinder: -0.25), 14)
        XCTAssertEqual(Z80Tolerance.axis(cylinder: -0.5), 7)
        XCTAssertEqual(Z80Tolerance.axis(cylinder: -0.75), 5)
        XCTAssertEqual(Z80Tolerance.axis(cylinder: -1), 3)
        XCTAssertEqual(Z80Tolerance.axis(cylinder: -1.5), 3)
        XCTAssertEqual(Z80Tolerance.axis(cylinder: -1.75), 2)

        var j = job(.singleVision, SpheroCylinder(sphere: -1, cylinder: -1, axis: 178))
        j.measured[.od]!.rx.axis = 1
        XCTAssertTrue(passes(j, "axis.od"))
        j.measured[.od]!.rx.axis = 2
        XCTAssertFalse(passes(j, "axis.od"))
        XCTAssertFalse(job(.singleVision, SpheroCylinder(sphere: -1, cylinder: 0, axis: 180)).items.contains { $0.id == "axis.od" })
    }

    func testAddTolerance() {
        XCTAssertEqual(Z80Tolerance.add(4), 0.12, accuracy: 1e-9)
        XCTAssertEqual(Z80Tolerance.add(4.25), 0.18, accuracy: 1e-9)

        var j = job(.linedMultifocal, SpheroCylinder(sphere: 1, cylinder: 0, axis: 180), add: 2, height: 18)
        j.measured[.od]!.add = 2.12
        XCTAssertTrue(passes(j, "add.od"))
        j.measured[.od]!.add = 2.13
        XCTAssertFalse(passes(j, "add.od"))
    }

    func testPrescribedPrismTolerance() {
        XCTAssertEqual(Z80Tolerance.prescribedPrism(6), 0.33, accuracy: 1e-9)
        XCTAssertEqual(Z80Tolerance.prescribedPrism(6.5), 0.5, accuracy: 1e-9)

        var j = job(.singleVision, SpheroCylinder(sphere: 1, cylinder: 0, axis: 180))
        j.orderedPrism = Z80Job.Prism(amount: 3, base: .baseUp)
        j.measuredPrism = 3.33
        XCTAssertTrue(passes(j, "prism.od"))
        j.measuredPrism = 3.34
        XCTAssertFalse(passes(j, "prism.od"))
        XCTAssertFalse(j.items.contains { $0.id == "vertical" })
        XCTAssertTrue(j.items.contains { $0.id == "horizontal" })

        j.orderedPrism = Z80Job.Prism(amount: 8, base: .baseIn)
        j.measuredPrism = 8.5
        XCTAssertTrue(passes(j, "prism.od"))
        j.measuredPrism = 7.49
        XCTAssertFalse(passes(j, "prism.od"))
        XCTAssertFalse(j.items.contains { $0.id == "horizontal" })
    }

    func testSegHeightPerLensAndPair() {
        var j = job(.linedMultifocal, SpheroCylinder(sphere: 1, cylinder: 0, axis: 180), add: 2, height: 18)
        j.measured[.od]!.height = 19
        XCTAssertTrue(passes(j, "height.od"))
        XCTAssertTrue(passes(j, "height.pair"))
        j.measured[.od]!.height = 19.5
        XCTAssertFalse(passes(j, "height.od"))

        j.measured[.od]!.height = 18.5
        j.measured[.os]!.height = 17
        XCTAssertTrue(passes(j, "height.od"))
        XCTAssertTrue(passes(j, "height.os"))
        XCTAssertFalse(passes(j, "height.pair"))
    }

    func testPowerRangeSelectsPrismRule() {
        XCTAssertTrue(Z80Tolerance.usesHorizontalImbalance(power: -2.75, progressive: false))
        XCTAssertFalse(Z80Tolerance.usesHorizontalImbalance(power: 3, progressive: false))
        XCTAssertTrue(Z80Tolerance.usesHorizontalImbalance(power: 3.75, progressive: true))
        XCTAssertFalse(Z80Tolerance.usesHorizontalImbalance(power: -4, progressive: true))
        XCTAssertTrue(Z80Tolerance.usesVerticalImbalance(power: -3.375))
        XCTAssertFalse(Z80Tolerance.usesVerticalImbalance(power: 3.5))
    }

    func testHorizontalImbalanceAndPD() {
        var low = job(.singleVision, SpheroCylinder(sphere: 2.5, cylinder: 0, axis: 180))
        low.pdError = [.od: 1.34, .os: 1.34]
        XCTAssertEqual(low.horizontalImbalance, 0.67, accuracy: 1e-9)
        XCTAssertTrue(passes(low, "horizontal"))
        low.pdError = [.od: 1.36, .os: 1.36]
        XCTAssertFalse(passes(low, "horizontal"))

        var high = job(.singleVision, SpheroCylinder(sphere: -4, cylinder: 0, axis: 180))
        high.pdError = [.od: 1.25, .os: 1.25]
        XCTAssertTrue(passes(high, "horizontal"))
        high.pdError = [.od: 1.5, .os: 1.5]
        XCTAssertFalse(passes(high, "horizontal"))

        var progressive = job(.progressive, SpheroCylinder(sphere: -5, cylinder: 0, axis: 180), add: 2, height: 20)
        progressive.pdError = [.od: 1, .os: -1]
        XCTAssertTrue(passes(progressive, "horizontal"))
        progressive.pdError = [.od: 1.5, .os: 0]
        XCTAssertFalse(passes(progressive, "horizontal"))
    }

    func testVerticalImbalanceAndPRPHeight() {
        var low = job(.singleVision, SpheroCylinder(sphere: 2, cylinder: 0, axis: 180))
        low.prpHeightDifference = 1.65
        XCTAssertEqual(low.verticalImbalance, 0.33, accuracy: 1e-9)
        XCTAssertTrue(passes(low, "vertical"))
        low.prpHeightDifference = -1.7
        XCTAssertFalse(passes(low, "vertical"))

        var high = job(.singleVision, SpheroCylinder(sphere: -5, cylinder: 0, axis: 180))
        high.prpHeightDifference = 1
        XCTAssertTrue(passes(high, "vertical"))
        high.prpHeightDifference = 1.5
        XCTAssertFalse(passes(high, "vertical"))
    }

    func testGeneratorProducesPassingAndFailingJobs() {
        var rng = SystemRandomNumberGenerator()
        var passing = 0, failing = 0
        for _ in 0..<500 {
            let generated = Z80Job.random(using: &rng)
            let items = generated.items
            XCTAssertEqual(Set(items.map(\.id)).count, items.count)
            XCTAssertEqual(generated.passes, items.allSatisfy(\.passes))
            if generated.passes { passing += 1 } else { failing += 1 }
        }
        XCTAssertGreaterThan(passing, 50)
        XCTAssertGreaterThan(failing, 50)
    }
}
