import Foundation

/// Generates unlimited calculation questions from `OpticsMath`, with worked solutions and common-mistake distractors.
enum DrillGenerator {
    enum Kind: String, CaseIterable, Identifiable, Sendable {
        case prentice, transposition, sphericalEquivalent, vertex, blankSize, oblique, imbalance
        case keratometry, tearLens, toricAxis

        var id: String { rawValue }

        var title: String {
            switch self {
            case .prentice: "Prentice's rule"
            case .transposition: "Transposition"
            case .sphericalEquivalent: "Spherical equivalent"
            case .vertex: "Vertex compensation"
            case .blankSize: "Minimum blank size"
            case .oblique: "Oblique meridian power"
            case .imbalance: "Vertical imbalance"
            case .keratometry: "Keratometry conversion"
            case .tearLens: "RGP power (SAM-FAP)"
            case .toricAxis: "Toric rotation (LARS)"
            }
        }

        var exams: [ExamID] {
            switch self {
            case .prentice, .transposition, .blankSize, .oblique, .imbalance: [.abo]
            case .sphericalEquivalent, .vertex: [.abo, .ncle]
            case .keratometry, .tearLens, .toricAxis: [.ncle]
            }
        }

        func domain(for exam: ExamID) -> String {
            switch (self, exam) {
            case (.blankSize, _): "abo.dispensing"
            case (.toricAxis, _): "ncle.fitting"
            case (_, .ncle): "ncle.refraction"
            default: "abo.optics"
            }
        }
    }

    static let idPrefix = "drill-"

    static func kinds(for exam: ExamID) -> [Kind] { Kind.allCases.filter { $0.exams.contains(exam) } }

    static func make<G: RandomNumberGenerator>(_ kind: Kind, exam: ExamID, using rng: inout G) -> Question {
        let built: (stem: String, answer: String, distractors: [String], explanation: String) = switch kind {
        case .prentice: prentice(&rng)
        case .transposition: transposition(&rng)
        case .sphericalEquivalent: sphericalEquivalent(&rng)
        case .vertex: vertex(&rng)
        case .blankSize: blankSize(&rng)
        case .oblique: oblique(&rng)
        case .imbalance: imbalance(&rng)
        case .keratometry: keratometry(&rng)
        case .tearLens: tearLens(&rng)
        case .toricAxis: toricAxis(&rng)
        }
        var options = [built.answer]
        for candidate in built.distractors where !options.contains(candidate) && options.count < 4 {
            options.append(candidate)
        }
        var bump = 1
        while options.count < 4 {
            options.append("\(built.answer) (±\(bump))")
            bump += 1
        }
        options.shuffle(using: &rng)
        return Question(
            id: "\(idPrefix)\(kind.rawValue)-\(UInt32.random(in: 0...UInt32.max, using: &rng))",
            exam: exam,
            domain: kind.domain(for: exam),
            topic: kind.title,
            difficulty: 2,
            stem: built.stem,
            choices: options,
            answer: options.firstIndex(of: built.answer) ?? 0,
            explanation: built.explanation,
            source: nil,
            diagram: diagram(for: kind)
        )
    }

    static func quiz<G: RandomNumberGenerator>(exam: ExamID, kinds: [Kind], count: Int, using rng: inout G) -> [Question] {
        guard !kinds.isEmpty else { return [] }
        return (0..<count).map { _ in make(kinds.randomElement(using: &rng)!, exam: exam, using: &rng) }
    }

    private static func diagram(for kind: Kind) -> String? {
        switch kind {
        case .prentice, .imbalance: "prentice"
        case .transposition, .oblique: "optical-cross"
        case .vertex: "vertex-distance"
        case .blankSize: "boxing-system"
        case .tearLens: "tear-lens"
        default: nil
        }
    }

    // MARK: Builders

    private static func power<G: RandomNumberGenerator>(_ range: ClosedRange<Double>, step: Double = 0.25, nonZero: Bool = true, _ rng: inout G) -> Double {
        let steps = Int((range.upperBound - range.lowerBound) / step)
        while true {
            let value = range.lowerBound + Double(Int.random(in: 0...steps, using: &rng)) * step
            if !nonZero || value != 0 { return value }
        }
    }

    private static func fmt(_ value: Double) -> String { OpticsMath.formatPower(value) }
    private static func nearPowers(_ v: Double) -> [String] { [0.25, -0.25, 0.5, -0.5, 0.75].map { fmt(v + $0) } }
    private static func nearPrism(_ v: Double) -> [String] { [0.5, 1, 1.5, 2].map { prism(v + $0) } }
    private static func nearAxis(_ a: Int) -> [String] {
        [5, -5, 10, -10].map { axis(OpticsMath.compensatedToricAxis(a, rotation: abs($0), toLeft: $0 > 0)) }
    }
    private static func prism(_ value: Double) -> String { String(format: "%.2fΔ", value) }
    private static func axis(_ value: Int) -> String { String(format: "%03d", value) }
    private static func rx(_ rx: SpheroCylinder) -> String { "\(fmt(rx.sphere)) \(fmt(rx.cylinder)) × \(axis(rx.axis))" }

    private static func prentice<G: RandomNumberGenerator>(_ rng: inout G) -> (String, String, [String], String) {
        let f = power(-8...8, step: 0.5, &rng)
        let mm = Double(Int.random(in: 2...10, using: &rng))
        let plus = f > 0
        let base = Bool.random(using: &rng)
        let direction = base ? "inward (nasally)" : "outward (temporally)"
        let delta = OpticsMath.prenticePrism(decentrationMM: mm, power: f)
        let baseDir = (plus == base) ? "base in" : "base out"
        let answer = "\(prism(delta)) \(baseDir)"
        let wrongBase = baseDir == "base in" ? "base out" : "base in"
        let stem = "A right lens of \(fmt(f)) D sphere has its optical center decentered \(Int(mm)) mm \(direction) from the pupil. What prism does the patient experience?"
        let explanation = """
        Prentice's rule: Δ = c × F, with c in centimeters. \(Int(mm)) mm = \(String(format: "%.1f", mm / 10)) cm, so Δ = \(String(format: "%.1f", mm / 10)) × \(String(format: "%.2f", abs(f))) = \(prism(delta)).

        A \(plus ? "plus" : "minus") lens has its base \(plus ? "toward" : "away from") the optical center. With the OC moved \(direction), the base is \(baseDir == "base in" ? "nasal (base in)" : "temporal (base out)").
        """
        return (stem, answer, ["\(prism(delta)) \(wrongBase)", "\(prism(delta * 10)) \(baseDir)", "\(prism(delta / 2)) \(baseDir)"]
            + nearPrism(delta).map { "\($0) \(baseDir)" }, explanation)
    }

    private static func randomRx<G: RandomNumberGenerator>(_ rng: inout G) -> SpheroCylinder {
        SpheroCylinder(
            sphere: power(-6...4, nonZero: false, &rng),
            cylinder: -power(0.25...4, &rng),
            axis: Int.random(in: 1...36, using: &rng) * 5
        )
    }

    private static func transposition<G: RandomNumberGenerator>(_ rng: inout G) -> (String, String, [String], String) {
        let original = randomRx(&rng)
        let t = OpticsMath.transpose(original)
        let stem = "Transpose \(rx(original)) to plus-cylinder form."
        let explanation = """
        1. New sphere = sphere + cylinder: \(fmt(original.sphere)) + (\(fmt(original.cylinder))) = \(fmt(t.sphere)).
        2. Change the cylinder sign: \(fmt(t.cylinder)).
        3. Change the axis by 90°: \(axis(original.axis)) → \(axis(t.axis)).

        Result: \(rx(t)).
        """
        return (stem, rx(t), [
            rx(SpheroCylinder(sphere: t.sphere, cylinder: t.cylinder, axis: original.axis)),
            rx(SpheroCylinder(sphere: original.sphere, cylinder: t.cylinder, axis: t.axis)),
            rx(SpheroCylinder(sphere: original.sphere - original.cylinder, cylinder: t.cylinder, axis: t.axis)),
            rx(SpheroCylinder(sphere: t.sphere + 0.25, cylinder: t.cylinder, axis: t.axis)),
            rx(SpheroCylinder(sphere: t.sphere - 0.25, cylinder: t.cylinder, axis: t.axis))
        ], explanation)
    }

    private static func sphericalEquivalent<G: RandomNumberGenerator>(_ rng: inout G) -> (String, String, [String], String) {
        let r = randomRx(&rng)
        let se = OpticsMath.sphericalEquivalent(sphere: r.sphere, cylinder: r.cylinder)
        let stem = "What is the spherical equivalent of \(rx(r))?"
        let explanation = "SE = sphere + ½ cylinder = \(fmt(r.sphere)) + ½(\(fmt(r.cylinder))) = \(fmt(se)). Spherical equivalent keeps the circle of least confusion on the retina, which is why it is used when fitting a spherical soft lens on a low-astigmatism eye."
        return (stem, fmt(se), [fmt(r.sphere + r.cylinder), fmt(r.sphere), fmt(r.sphere - r.cylinder / 2)] + nearPowers(se), explanation)
    }

    private static func vertex<G: RandomNumberGenerator>(_ rng: inout G) -> (String, String, [String], String) {
        let f = (Bool.random(using: &rng) ? 1 : -1) * power(4.5...10, step: 0.5, &rng)
        let compensated = OpticsMath.compensatedPower(f, moveMM: 12)
        let answer = OpticsMath.roundToQuarter(compensated)
        let wrongWay = OpticsMath.roundToQuarter(OpticsMath.compensatedPower(f, moveMM: -12))
        let stem = "A spectacle Rx of \(fmt(f)) D was refracted at a 12 mm vertex distance. What contact lens power (rounded to the nearest 0.25 D) corrects the eye?"
        let explanation = """
        Fc = F ÷ (1 − dF), d = 0.012 m (the lens moves 12 mm toward the eye).
        Fc = \(fmt(f)) ÷ (1 − 0.012 × \(fmt(f))) = \(String(format: "%.3f", compensated)) → \(fmt(answer)).

        \(f < 0 ? "Minus prescriptions need less minus at the cornea." : "Plus prescriptions need more plus at the cornea.") Compensate whenever a meridian exceeds ±4.00 D.
        """
        return (stem, fmt(answer), [fmt(f), fmt(wrongWay), fmt(answer + (f < 0 ? -0.25 : 0.25))] + nearPowers(answer), explanation)
    }

    private static func blankSize<G: RandomNumberGenerator>(_ rng: inout G) -> (String, String, [String], String) {
        let a = Double(Int.random(in: 46...56, using: &rng))
        let dbl = Double(Int.random(in: 15...20, using: &rng))
        let ed = a + Double(Int.random(in: 2...6, using: &rng))
        let framePD = a + dbl
        let pd = framePD - 2 * Double(Int.random(in: 2...6, using: &rng))
        let mbs = OpticsMath.minimumBlankSize(effectiveDiameter: ed, framePD: framePD, patientPD: pd)
        let mm = { (v: Double) in String(format: "%.0f mm", v) }
        let stem = "Frame: A = \(Int(a)), DBL = \(Int(dbl)), ED = \(Int(ed)). Patient PD = \(Int(pd)) mm. What is the minimum blank size?"
        let explanation = """
        Frame PD = A + DBL = \(Int(a)) + \(Int(dbl)) = \(Int(framePD)) mm.
        MBS = ED + (frame PD − PD) + 2 mm = \(Int(ed)) + (\(Int(framePD)) − \(Int(pd))) + 2 = \(mm(mbs)).

        The total decentration (frame PD − PD) counts once because each lens moves half of it, doubled for the diameter. The extra 2 mm allows for edging.
        """
        return (stem, mm(mbs), [mm(mbs - 2), mm(ed + (framePD - pd) / 2 + 2), mm(ed + 2 * (framePD - pd) + 2), mm(ed + 2), mm(mbs + 2), mm(mbs + 1), mm(mbs - 1)], explanation)
    }

    private static func oblique<G: RandomNumberGenerator>(_ rng: inout G) -> (String, String, [String], String) {
        let base = randomRx(&rng)
        let offset = [30, 45, 60].randomElement(using: &rng)!
        let meridian = (base.axis + offset - 1) % 180 + 1
        let result = OpticsMath.obliquePower(base, meridian: meridian)
        let theta = Double(offset) * .pi / 180
        let cosVersion = base.sphere + base.cylinder * pow(cos(theta), 2)
        let stem = "Using the sin² approximation, what is the power of \(rx(base)) in the \(meridian)° meridian?"
        let explanation = "θ is the angle between the meridian and the cylinder axis: \(offset)°. F = S + C sin²θ = \(fmt(base.sphere)) + (\(fmt(base.cylinder))) × \(String(format: "%.3f", pow(sin(theta), 2))) = \(fmt(result)). Full cylinder power lies 90° from the axis; none lies on the axis."
        return (stem, fmt(result), [fmt(cosVersion), fmt(base.sphere + base.cylinder), fmt(base.sphere)] + nearPowers(result), explanation)
    }

    private static func imbalance<G: RandomNumberGenerator>(_ rng: inout G) -> (String, String, [String], String) {
        let od = power(-6...6, step: 0.5, &rng)
        var os = power(-6...6, step: 0.5, &rng)
        while os == od { os = power(-6...6, step: 0.5, &rng) }
        let drop = 10.0
        let r = OpticsMath.prenticePrism(decentrationMM: drop, power: od)
        let l = OpticsMath.prenticePrism(decentrationMM: drop, power: os)
        let same = (od > 0) == (os > 0)
        let result = same ? abs(r - l) : r + l
        let stem = "OD \(fmt(od)) D sphere, OS \(fmt(os)) D sphere, single-vision lenses. What vertical imbalance does the patient meet reading 10 mm below the optical centers?"
        let explanation = """
        Prentice at 1.0 cm: OD = 1.0 × \(String(format: "%.2f", abs(od))) = \(prism(r)); OS = 1.0 × \(String(format: "%.2f", abs(os))) = \(prism(l)).
        \(same ? "Both lenses are the same sign, so the prism bases point the same way: subtract." : "The lenses are opposite in sign (antimetropia), so the bases are opposite: add.")
        Imbalance = \(prism(result)).
        """
        return (stem, prism(result), [prism(same ? r + l : abs(r - l)), prism(result * 10)] + nearPrism(result), explanation)
    }

    private static func keratometry<G: RandomNumberGenerator>(_ rng: inout G) -> (String, String, [String], String) {
        let radius = 7.2 + Double(Int.random(in: 0...24, using: &rng)) * 0.05
        let k = OpticsMath.keratometricDiopters(radiusMM: radius)
        let d = { (v: Double) in String(format: "%.2f D", v) }
        let stem = String(format: "A keratometer reads a corneal radius of %.2f mm. What is the keratometric power?", radius)
        let explanation = String(format: "K (D) = 337.5 ÷ r (mm) = 337.5 ÷ %.2f = %.2f D. The constant 337.5 comes from the keratometric index 1.3375.", radius, k)
        return (stem, d(k), [d(376 / radius), d(k + 0.5), d(k - 0.75), d(k + 1), d(k - 0.25)], explanation)
    }

    private static func tearLens<G: RandomNumberGenerator>(_ rng: inout G) -> (String, String, [String], String) {
        let sphere = power(-3.75...3.75, &rng)
        let flatK = 42 + Double(Int.random(in: 0...16, using: &rng)) * 0.25
        let steeper = Bool.random(using: &rng)
        let deltaD = Double(Int.random(in: 1...3, using: &rng)) * 0.25
        let bcD = flatK + (steeper ? deltaD : -deltaD)
        let bc = OpticsMath.radiusMM(diopters: bcD)
        let result = OpticsMath.roundToQuarter(OpticsMath.rigidLensPower(sphere: sphere, vertexMM: 0, baseCurveMM: bc, flatKDiopters: flatK))
        let tear = bcD - flatK
        let stem = String(format: "Rx %@ D sphere (no vertex compensation needed). Flat K = %.2f D. The RGP base curve is %.2f D (%@ than K). What lens power should be ordered?", fmt(sphere), flatK, bcD, steeper ? "steeper" : "flatter")
        let explanation = """
        Tear lens = base curve − flat K = \(String(format: "%.2f", bcD)) − \(String(format: "%.2f", flatK)) = \(fmt(tear)) D.
        SAM-FAP: \(steeper ? "steeper adds minus" : "flatter adds plus"). CL power = Rx − tear lens = \(fmt(sphere)) − (\(fmt(tear))) = \(fmt(result)).
        """
        return (stem, fmt(result), [fmt(sphere + tear), fmt(sphere), fmt(result + (steeper ? -0.25 : 0.25))] + nearPowers(result), explanation)
    }

    private static func toricAxis<G: RandomNumberGenerator>(_ rng: inout G) -> (String, String, [String], String) {
        let rxAxis = Int.random(in: 1...18, using: &rng) * 10
        let rotation = [5, 10, 15, 20].randomElement(using: &rng)!
        let left = Bool.random(using: &rng)
        let result = OpticsMath.compensatedToricAxis(rxAxis, rotation: rotation, toLeft: left)
        let opposite = OpticsMath.compensatedToricAxis(rxAxis, rotation: rotation, toLeft: !left)
        let stem = "A diagnostic toric soft lens with axis \(axis(rxAxis)) settles with its marking rotated \(rotation)° to the \(left ? "left" : "right") (as you face the patient). What axis should be ordered?"
        let explanation = "LARS: Left Add, Right Subtract. Rotation to the \(left ? "left adds" : "right subtracts"): \(axis(rxAxis)) \(left ? "+" : "−") \(rotation) = \(axis(result)). Order the compensated axis in the same lens design; the lens will rotate the same way on the eye."
        return (stem, axis(result), [axis(opposite), axis(rxAxis), axis(OpticsMath.compensatedToricAxis(result, rotation: 90, toLeft: true))] + nearAxis(result), explanation)
    }
}
