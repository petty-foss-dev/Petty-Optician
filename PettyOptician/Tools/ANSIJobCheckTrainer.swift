import SwiftUI

/// ANSI Z80.1-2025 tolerances, applied to nominal values in minus-cylinder form.
enum Z80Tolerance {
    static let heightPerLens = 1.0
    static let heightPairDifference = 1.0
    static let horizontalImbalance = 0.67
    static let distancePD = 2.5
    static let monocularPD = 1.0
    static let verticalImbalance = 0.33
    static let prpHeightDifference = 1.0

    static func sphere(_ sphere: Double, progressive: Bool) -> Double {
        let limit = progressive ? 8.0 : 6.5
        guard abs(sphere) > limit + 1e-9 else { return progressive ? 0.16 : 0.13 }
        return abs(sphere) * 0.02
    }

    static func cylinder(_ cylinder: Double, progressive: Bool) -> Double {
        let c = abs(cylinder)
        if c <= 2 + 1e-9 { return progressive ? 0.16 : 0.13 }
        if c <= (progressive ? 3.5 : 4.5) + 1e-9 { return progressive ? 0.18 : 0.15 }
        return c * (progressive ? 0.05 : 0.04)
    }

    /// `nil` below 0.12 D, where the standard defines no axis tolerance.
    static func axis(cylinder: Double) -> Int? {
        switch abs(cylinder) {
        case ..<0.12: nil
        case ...0.25: 14
        case ...0.50: 7
        case ...0.75: 5
        case ...1.50: 3
        default: 2
        }
    }

    static func add(_ add: Double) -> Double { add <= 4 + 1e-9 ? 0.12 : 0.18 }

    static func prescribedPrism(_ prism: Double) -> Double { prism <= 6 + 1e-9 ? 0.33 : 0.5 }

    /// Up to ±2.75 D (±3.75 D for progressives) the limit is horizontal imbalance; above it, PRP placement.
    static func usesHorizontalImbalance(power: Double, progressive: Bool) -> Bool {
        abs(power) <= (progressive ? 3.75 : 2.75) + 1e-9
    }

    /// Up to ±3.375 D the limit is vertical imbalance; above it, the difference in PRP heights.
    static func usesVerticalImbalance(power: Double) -> Bool { abs(power) <= 3.375 + 1e-9 }

    static func within(_ deviation: Double, _ tolerance: Double) -> Bool { abs(deviation) <= tolerance + 1e-6 }
}

struct Z80Job: Sendable {
    enum LensType: CaseIterable, Sendable {
        case singleVision, linedMultifocal, progressive

        var title: String {
            switch self {
            case .singleVision: "Single vision"
            case .linedMultifocal: "Flat-top bifocal"
            case .progressive: "Progressive"
            }
        }

        var heightName: String { self == .progressive ? "Fitting cross height" : "Seg height" }
    }

    enum PrismBase: String, CaseIterable, Sendable {
        case baseIn = "BI", baseOut = "BO", baseUp = "BU", baseDown = "BD"

        var isHorizontal: Bool { self == .baseIn || self == .baseOut }
    }

    enum Eye: String, CaseIterable, Sendable {
        case od = "OD", os = "OS"
    }

    struct Lens: Sendable {
        var rx: SpheroCylinder
        var add: Double?
        var height: Double?
    }

    struct Prism: Sendable {
        var amount: Double
        var base: PrismBase
    }

    struct Item: Identifiable, Sendable {
        let id: String
        let title: String
        let ordered: String
        let measured: String
        let rule: String
        let passes: Bool
    }

    var type: LensType
    var ordered: [Eye: Lens]
    var measured: [Eye: Lens]
    /// Prescribed prism is ordered on OD only; it replaces the imbalance check in its meridian.
    var orderedPrism: Prism?
    var measuredPrism: Double?
    /// Binocular PD for single vision and bifocals, monocular PDs for progressives.
    var pd: [Eye: Double]
    /// Measured PRP (or fitting cross) displacement from the ordered PD, + = outward, in mm.
    var pdError: [Eye: Double]
    /// OD PRP height minus OS PRP height, in mm; both were ordered level.
    var prpHeightDifference: Double

    var progressive: Bool { type == .progressive }

    var passes: Bool { items.allSatisfy(\.passes) }

    var items: [Item] {
        var items: [Item] = []
        for eye in Eye.allCases {
            let o = ordered[eye]!, m = measured[eye]!
            items.append(scalarItem("sphere.\(eye)", "Sphere \(eye.rawValue)", o.rx.sphere, m.rx.sphere, Z80Tolerance.sphere(o.rx.sphere, progressive: progressive), sphereRange(o.rx.sphere)))
            items.append(scalarItem("cylinder.\(eye)", "Cylinder \(eye.rawValue)", o.rx.cylinder, m.rx.cylinder, Z80Tolerance.cylinder(o.rx.cylinder, progressive: progressive), cylinderRange(o.rx.cylinder)))
            if let limit = Z80Tolerance.axis(cylinder: o.rx.cylinder) {
                let off = LensometerTrainerView.axisDifference(o.rx.axis, m.rx.axis)
                items.append(Item(
                    id: "axis.\(eye)", title: "Axis \(eye.rawValue)", ordered: Self.axisText(o.rx.axis), measured: Self.axisText(m.rx.axis),
                    rule: "Off \(off)°. Limit ±\(limit)° for \(Self.formatAbs(o.rx.cylinder)) D of cylinder (\(axisRange(o.rx.cylinder))).",
                    passes: off <= limit
                ))
            }
            if let add = o.add, let measuredAdd = m.add {
                items.append(scalarItem("add.\(eye)", "Add \(eye.rawValue)", add, measuredAdd, Z80Tolerance.add(add), add <= 4 ? "add up to 4.00 D" : "add over 4.00 D"))
            }
            if let height = o.height, let measuredHeight = m.height {
                let off = measuredHeight - height
                items.append(Item(
                    id: "height.\(eye)", title: "\(type.heightName) \(eye.rawValue)", ordered: Self.mm(height), measured: Self.mm(measuredHeight),
                    rule: "Off \(Self.mm(abs(off))). Limit ±1.0 mm per lens.",
                    passes: Z80Tolerance.within(off, Z80Tolerance.heightPerLens)
                ))
            }
        }
        if let odHeight = measured[.od]?.height, let osHeight = measured[.os]?.height {
            let difference = abs(odHeight - osHeight)
            items.append(Item(
                id: "height.pair", title: "\(type.heightName), pair", ordered: "Equal heights", measured: "OD \(Self.mm(odHeight)) / OS \(Self.mm(osHeight))",
                rule: "Pair differs by \(Self.mm(difference)). Limit 1.0 mm between the lenses.",
                passes: Z80Tolerance.within(difference, Z80Tolerance.heightPairDifference)
            ))
        }
        if let orderedPrism, let measuredPrism {
            let limit = Z80Tolerance.prescribedPrism(orderedPrism.amount)
            items.append(Item(
                id: "prism.od", title: "Prescribed prism OD", ordered: Self.prism(orderedPrism.amount, orderedPrism.base.rawValue), measured: Self.prism(measuredPrism, orderedPrism.base.rawValue),
                rule: "Off \(String(format: "%.2fΔ", abs(measuredPrism - orderedPrism.amount))). Limit ±\(limit == 0.5 ? "0.5" : "0.33")Δ for prescribed prism \(limit == 0.5 ? "over" : "up to") 6Δ (new in Z80.1-2025).",
                passes: Z80Tolerance.within(measuredPrism - orderedPrism.amount, limit)
            ))
        }
        if orderedPrism?.base.isHorizontal != true { items.append(horizontalItem) }
        if orderedPrism.map({ !$0.base.isHorizontal }) != true { items.append(verticalItem) }
        return items
    }

    var horizontalPowers: (od: Double, os: Double) {
        (OpticsMath.obliquePower(ordered[.od]!.rx, meridian: 180), OpticsMath.obliquePower(ordered[.os]!.rx, meridian: 180))
    }

    var verticalPowers: (od: Double, os: Double) {
        (OpticsMath.obliquePower(ordered[.od]!.rx, meridian: 90), OpticsMath.obliquePower(ordered[.os]!.rx, meridian: 90))
    }

    /// Prentice's rule; positive = base out.
    var horizontalImbalance: Double {
        Self.round2((pdError[.od]! * horizontalPowers.od + pdError[.os]! * horizontalPowers.os) / 10)
    }

    /// Prentice's rule with the eyes midway between the two PRP heights; positive = base up OD.
    var verticalImbalance: Double {
        Self.round2(prpHeightDifference / 20 * (verticalPowers.od + verticalPowers.os))
    }

    private var horizontalItem: Item {
        let powers = horizontalPowers
        let strongest = max(abs(powers.od), abs(powers.os))
        let imbalance = horizontalImbalance
        let imbalanceText = imbalance == 0 ? "no prism" : Self.prism(abs(imbalance), imbalance > 0 ? "BO" : "BI")
        let powerText = "Horizontal meridian OD \(OpticsMath.formatPower(powers.od)) / OS \(OpticsMath.formatPower(powers.os)) D"
        let ordered: String, measured: String, rule: String, passes: Bool
        if progressive {
            ordered = "Mono PD \(Self.mm(pd[.od]!)) / \(Self.mm(pd[.os]!))"
            measured = "\(Self.mm(pd[.od]! + pdError[.od]!)) / \(Self.mm(pd[.os]! + pdError[.os]!)) · \(imbalanceText)"
        } else {
            ordered = "PD \(Self.mm(pd[.od]!))"
            measured = "PD \(Self.mm(pd[.od]! + pdError[.od]! + pdError[.os]!)) · \(imbalanceText)"
        }
        if Z80Tolerance.usesHorizontalImbalance(power: strongest, progressive: progressive) {
            passes = Z80Tolerance.within(imbalance, Z80Tolerance.horizontalImbalance)
            rule = "\(powerText), within ±\(progressive ? "3.75" : "2.75") D, so the limit is 0.67Δ of horizontal imbalance: \(imbalanceText)."
        } else if progressive {
            passes = Z80Tolerance.within(pdError[.od]!, Z80Tolerance.monocularPD) && Z80Tolerance.within(pdError[.os]!, Z80Tolerance.monocularPD)
            rule = "\(powerText), over ±3.75 D, so each fitting cross must be within ±1.0 mm of its monocular PD: off \(Self.mm(abs(pdError[.od]!))) / \(Self.mm(abs(pdError[.os]!)))."
        } else {
            let off = pdError[.od]! + pdError[.os]!
            passes = Z80Tolerance.within(off, Z80Tolerance.distancePD)
            rule = "\(powerText), over ±2.75 D, so the PD must be within ±2.5 mm: off \(Self.mm(abs(off)))."
        }
        return Item(id: "horizontal", title: "Horizontal prism / PD", ordered: ordered, measured: measured, rule: rule, passes: passes)
    }

    private var verticalItem: Item {
        let powers = verticalPowers
        let strongest = max(abs(powers.od), abs(powers.os))
        let imbalance = verticalImbalance
        let imbalanceText = imbalance == 0 ? "no prism" : Self.prism(abs(imbalance), imbalance > 0 ? "BU OD" : "BD OD")
        let heightText = prpHeightDifference == 0 ? "PRPs level" : "OD PRP \(Self.mm(abs(prpHeightDifference))) \(prpHeightDifference > 0 ? "higher" : "lower")"
        let powerText = "Vertical meridian OD \(OpticsMath.formatPower(powers.od)) / OS \(OpticsMath.formatPower(powers.os)) D"
        let rule: String, passes: Bool
        if Z80Tolerance.usesVerticalImbalance(power: strongest) {
            passes = Z80Tolerance.within(imbalance, Z80Tolerance.verticalImbalance)
            rule = "\(powerText), within ±3.375 D, so the limit is 0.33Δ of vertical imbalance: \(imbalanceText)."
        } else {
            passes = Z80Tolerance.within(prpHeightDifference, Z80Tolerance.prpHeightDifference)
            rule = "\(powerText), over ±3.375 D, so the PRP heights may differ by no more than 1.0 mm: \(Self.mm(abs(prpHeightDifference)))."
        }
        return Item(id: "vertical", title: "Vertical prism", ordered: "PRPs level", measured: "\(heightText) · \(imbalanceText)", rule: rule, passes: passes)
    }

    private func scalarItem(_ id: String, _ title: String, _ ordered: Double, _ measured: Double, _ tolerance: Double, _ range: String) -> Item {
        Item(
            id: id, title: title, ordered: OpticsMath.formatPower(ordered), measured: OpticsMath.formatPower(measured),
            rule: "Off \(Self.formatAbs(measured - ordered)) D. Limit ±\(Self.tolerance(tolerance)) D (\(range)).",
            passes: Z80Tolerance.within(measured - ordered, tolerance)
        )
    }

    private func sphereRange(_ sphere: Double) -> String {
        let limit = progressive ? "8.00" : "6.50"
        return abs(sphere) <= (progressive ? 8 : 6.5)
            ? "\(progressive ? "progressive " : "")sphere −\(limit) to +\(limit) D"
            : "2% of a sphere stronger than ±\(limit) D"
    }

    private func cylinderRange(_ cylinder: Double) -> String {
        let c = abs(cylinder), top = progressive ? 3.5 : 4.5
        let prefix = progressive ? "progressive " : ""
        if c <= 2 { return "\(prefix)cylinder 0.00 to 2.00 D" }
        if c <= top { return "\(prefix)cylinder over 2.00 to \(String(format: "%.2f", top)) D" }
        return "\(progressive ? "5" : "4")% of a \(prefix)cylinder over \(String(format: "%.2f", top)) D"
    }

    private func axisRange(_ cylinder: Double) -> String {
        switch abs(cylinder) {
        case ...0.25: "0.12 to 0.25 D"
        case ...0.50: "over 0.25 to 0.50 D"
        case ...0.75: "over 0.50 to 0.75 D"
        case ...1.50: "over 0.75 to 1.50 D"
        default: "over 1.50 D"
        }
    }

    static func round2(_ value: Double) -> Double { (value * 100).rounded() / 100 }
    static func axisText(_ axis: Int) -> String { String(format: "%03d", axis) }
    static func mm(_ value: Double) -> String { String(format: "%.1f mm", value) }
    static func prism(_ value: Double, _ base: String) -> String { String(format: "%.2fΔ %@", value, base) }
    static func formatAbs(_ value: Double) -> String { String(format: "%.2f", abs(value)) }

    static func tolerance(_ value: Double) -> String {
        var text = String(format: "%.4f", value)
        while text.hasSuffix("0"), text.split(separator: ".")[1].count > 2 { text.removeLast() }
        return text
    }
}

extension Z80Job {
    private enum Check: Hashable {
        case sphere(Eye), cylinder(Eye), axis(Eye), add(Eye), height(Eye), heightPair, prism, horizontal, vertical
    }

    static func random() -> Z80Job {
        var rng = SystemRandomNumberGenerator()
        return random(using: &rng)
    }

    /// About 40% of jobs pass; the rest fail one or two checks, often by a single reading step.
    static func random<G: RandomNumberGenerator>(using rng: inout G) -> Z80Job {
        let type = LensType.allCases.randomElement(using: &rng)!
        let progressive = type == .progressive
        var od: SpheroCylinder, os: SpheroCylinder
        repeat {
            od = randomRx(progressive: progressive, using: &rng)
            os = SpheroCylinder(
                sphere: od.sphere + Double(Int.random(in: -3...3, using: &rng)) * 0.25,
                cylinder: min(0, od.cylinder + Double(Int.random(in: -2...2, using: &rng)) * 0.25),
                axis: wrapped(180 - od.axis + Int.random(in: -10...10, using: &rng))
            )
        } while !thresholdsAgree(od, os, progressive: progressive)

        let add: Double? = type == .singleVision ? nil
            : type == .linedMultifocal && Int.random(in: 0...7, using: &rng) == 0 ? Double(Int.random(in: 17...20, using: &rng)) * 0.25
            : Double(Int.random(in: 3...14, using: &rng)) * 0.25
        let height: Double? = switch type {
        case .singleVision: nil
        case .linedMultifocal: Double(Int.random(in: 32...44, using: &rng)) * 0.5
        case .progressive: Double(Int.random(in: 36...52, using: &rng)) * 0.5
        }
        let prism: Prism? = Int.random(in: 0...3, using: &rng) == 0
            ? Prism(amount: Double(Int.random(in: 1...20, using: &rng)) * 0.5, base: PrismBase.allCases.randomElement(using: &rng)!)
            : nil
        let pd: [Eye: Double] = progressive
            ? [.od: Double(Int.random(in: 56...72, using: &rng)) * 0.5, .os: Double(Int.random(in: 56...72, using: &rng)) * 0.5]
            : [.od: Double(Int.random(in: 112...144, using: &rng)) * 0.5]

        let ordered: [Eye: Lens] = [.od: Lens(rx: od, add: add, height: height), .os: Lens(rx: os, add: add, height: height)]
        var job = Z80Job(type: type, ordered: ordered, measured: ordered, orderedPrism: prism, measuredPrism: prism?.amount, pd: pd, pdError: [.od: 0, .os: 0], prpHeightDifference: 0)

        var checks: [Check] = []
        for eye in Eye.allCases {
            checks += [.sphere(eye), .cylinder(eye)]
            if Z80Tolerance.axis(cylinder: ordered[eye]!.rx.cylinder) != nil { checks.append(.axis(eye)) }
            if add != nil { checks.append(.add(eye)) }
            if height != nil { checks.append(.height(eye)) }
        }
        if height != nil { checks.append(.heightPair) }
        if prism != nil { checks.append(.prism) }
        if prism?.base.isHorizontal != true { checks.append(.horizontal) }
        if prism.map({ !$0.base.isHorizontal }) != true { checks.append(.vertical) }

        let failCount = Int.random(in: 0...9, using: &rng) < 4 ? 0 : Int.random(in: 0...3, using: &rng) == 0 ? 2 : 1
        let failing = Set(checks.shuffled(using: &rng).prefix(failCount))

        for check in checks {
            let fail = failing.contains(check)
            switch check {
            case .sphere(let eye):
                job.measured[eye]!.rx.sphere += offset(limit: Z80Tolerance.sphere(ordered[eye]!.rx.sphere, progressive: progressive), step: 0.01, fail: fail, using: &rng)
            case .cylinder(let eye):
                let delta = offset(limit: Z80Tolerance.cylinder(ordered[eye]!.rx.cylinder, progressive: progressive), step: 0.01, fail: fail, using: &rng)
                job.measured[eye]!.rx.cylinder = min(0, ordered[eye]!.rx.cylinder + (ordered[eye]!.rx.cylinder == 0 ? -abs(delta) : delta))
            case .axis(let eye):
                let limit = Double(Z80Tolerance.axis(cylinder: ordered[eye]!.rx.cylinder)!)
                job.measured[eye]!.rx.axis = wrapped(ordered[eye]!.rx.axis + Int(offset(limit: limit, step: 1, fail: fail, using: &rng)))
            case .add(let eye):
                job.measured[eye]!.add = add! + offset(limit: Z80Tolerance.add(add!), step: 0.01, fail: fail, using: &rng)
            case .prism:
                job.measuredPrism = prism!.amount + offset(limit: Z80Tolerance.prescribedPrism(prism!.amount), step: 0.01, fail: fail, using: &rng)
            case .height:
                break
            case .heightPair:
                let targets = (od: failing.contains(.height(.od)), os: failing.contains(.height(.os)), pair: fail)
                let grid = stride(from: -2.5, through: 2.5, by: 0.5).map { $0 }
                let pairs = grid.flatMap { r in grid.map { (r, $0) } }.filter { r, l in
                    !Z80Tolerance.within(r, Z80Tolerance.heightPerLens) == targets.od
                        && !Z80Tolerance.within(l, Z80Tolerance.heightPerLens) == targets.os
                        && !Z80Tolerance.within(r - l, Z80Tolerance.heightPairDifference) == targets.pair
                }
                let (r, l) = pairs.randomElement(using: &rng) ?? (0, 0)
                job.measured[.od]!.height = height! + r
                job.measured[.os]!.height = height! + l
            case .horizontal:
                let grid = progressive
                    ? stride(from: -3.0, through: 3.0, by: 0.5).flatMap { r in stride(from: -3.0, through: 3.0, by: 0.5).map { (r, $0) } }
                    : stride(from: -6.0, through: 6.0, by: 0.5).map { ($0 / 2, $0 / 2) }
                let candidates = grid.filter { r, l in
                    var trial = job
                    trial.pdError = [.od: r, .os: l]
                    return trial.horizontalItem.passes != fail
                }
                let (r, l) = candidates.randomElement(using: &rng) ?? (0, 0)
                job.pdError = [.od: r, .os: l]
            case .vertical:
                let candidates = stride(from: -3.0, through: 3.0, by: 0.5).filter { h in
                    var trial = job
                    trial.prpHeightDifference = h
                    return trial.verticalItem.passes != fail
                }
                job.prpHeightDifference = candidates.randomElement(using: &rng) ?? 0
            }
        }
        return job
    }

    private static func randomRx<G: RandomNumberGenerator>(progressive: Bool, using rng: inout G) -> SpheroCylinder {
        let strong = Int.random(in: 0...3, using: &rng) == 0
        let quarters = strong ? Int.random(in: progressive ? 33...44 : 27...40, using: &rng) : Int.random(in: 0...(progressive ? 32 : 26), using: &rng)
        let sphere = Double(quarters) * 0.25 * (Int.random(in: 0...2, using: &rng) == 0 ? 1 : -1)
        let cylinder: Double = switch Int.random(in: 0...9, using: &rng) {
        case 0...1: 0
        case 2...6: -Double(Int.random(in: 1...8, using: &rng)) * 0.25
        case 7...8: -Double(Int.random(in: 9...(progressive ? 14 : 18), using: &rng)) * 0.25
        default: -Double(Int.random(in: (progressive ? 15 : 19)...22, using: &rng)) * 0.25
        }
        return SpheroCylinder(sphere: sphere, cylinder: cylinder, axis: Int.random(in: 1...180, using: &rng))
    }

    /// Keeps both lenses on the same side of each prism threshold, so one rule clearly applies to the pair.
    private static func thresholdsAgree(_ od: SpheroCylinder, _ os: SpheroCylinder, progressive: Bool) -> Bool {
        let h = [OpticsMath.obliquePower(od, meridian: 180), OpticsMath.obliquePower(os, meridian: 180)]
        let v = [OpticsMath.obliquePower(od, meridian: 90), OpticsMath.obliquePower(os, meridian: 90)]
        let horizontalSides = Set(h.map { Z80Tolerance.usesHorizontalImbalance(power: $0, progressive: progressive) })
        let verticalSides = Set(v.map { Z80Tolerance.usesVerticalImbalance(power: $0) })
        // The 2020 quick-reference guide printed ±3.375 D for the progressive horizontal limit; skip powers where editions differ.
        let ambiguous = progressive && h.contains { abs($0) > 3.375 && abs($0) <= 3.75 }
        return horizontalSides.count == 1 && verticalSides.count == 1 && !ambiguous
    }

    /// A signed reading error: passing ones are often exactly at the limit, failing ones often a single step over.
    private static func offset<G: RandomNumberGenerator>(limit: Double, step: Double, fail: Bool, using rng: inout G) -> Double {
        let allowed = Int((limit / step + 1e-9).rounded(.down))
        let steps = if fail {
            allowed + (Int.random(in: 0...4, using: &rng) < 3 ? 1 : Int.random(in: 2...max(2, allowed / 2), using: &rng))
        } else {
            Int.random(in: 0...2, using: &rng) == 0 ? allowed : Int.random(in: 0...allowed, using: &rng)
        }
        return Double(steps) * step * (Bool.random(using: &rng) ? 1 : -1)
    }

    private static func wrapped(_ axis: Int) -> Int {
        let a = ((axis % 180) + 180) % 180
        return a == 0 ? 180 : a
    }
}

struct ANSIJobCheckView: View {
    @State private var job = Z80Job.random()
    @State private var calls: [String: Bool] = [:]
    @State private var overallCall: Bool?
    @State private var checked = false
    @State private var correctCount = 0
    @State private var attempts = 0
    @State private var showingHelp = false
    @Environment(\.palette) private var palette

    private static let sources = [
        SourceLink(title: "The Vision Council: ANSI ASC Z80.1-2025 – What's New?", url: URL(string: "https://www.visionexpo.com/content/dam/sitebuilder/rna/vision-expo-west/2025/docs/handouts/24O4-ANSI-ASC-Z80.1-2025-Whats-New-Contact%20Lenses.pdf.coredownload.539609178.1-2025-Whats-New-Contact%20Lenses.pdf")!),
        SourceLink(title: "Quick Reference Guide – ANSI Z80.1-2020 (The Vision Council)", url: URL(string: "https://static1.squarespace.com/static/653bcec2d9b772215a6dbf4e/t/65b923f7c62f3a4e69702b6b/1706632183988/ANSI_Z80-1-2020_QuickReferenceGuide.pdf")!),
        SourceLink(title: "20/20 Magazine: How OAA Member Feedback Shaped Z80.1", url: URL(string: "https://www.2020mag.com/article/being-involved-in-our-profession-can-make-a-difference")!),
    ]

    var body: some View {
        let items = job.items
        return ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                orderPanel

                Text("As measured: pass or fail each check").font(.headline)
                ForEach(items) { item in
                    itemRow(item)
                }

                Panel {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Whole job").font(.headline)
                        callButtons(selection: overallCall) { overallCall = $0 }
                        if checked {
                            Label(
                                job.passes ? "The job passes" : "The job fails: \(items.filter { !$0.passes }.map(\.title).joined(separator: ", "))",
                                systemImage: overallCall == job.passes ? "checkmark.seal.fill" : "xmark.octagon.fill"
                            )
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(overallCall == job.passes ? .green : .red)
                            Text("\(items.filter { calls[$0.id] == $0.passes }.count) of \(items.count) checks called correctly.")
                                .font(.caption)
                                .foregroundStyle(palette.secondaryText)
                            Button("Next Job", action: next).buttonStyle(.borderedProminent)
                        } else {
                            Button("Check", action: check)
                                .buttonStyle(.borderedProminent)
                                .disabled(overallCall == nil || items.contains { calls[$0.id] == nil })
                                .frame(maxWidth: .infinity, alignment: .trailing)
                                .accessibilityIdentifier("ansi.check")
                        }
                    }
                }

                Text("Score \(correctCount) / \(attempts)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(palette.secondaryText)

                DisclosureGroup("Z80.1-2025 tolerances used", isExpanded: $showingHelp) {
                    RichText(text: """
                    Write the order in minus-cylinder form and pick each tolerance from the **ordered** value. Sphere and cylinder are each toleranced separately; the 2005 edition's strongest-meridian method is no longer used.

                    - **Sphere**: −6.50 to +6.50 D ±0.13 D; stronger ±2%. Progressives: −8.00 to +8.00 D ±0.16 D; stronger ±2%.
                    - **Cylinder**: up to 2.00 D ±0.13 D; over 2.00 to 4.50 D ±0.15 D; over 4.50 D ±4%. Progressives: ±0.16 D, ±0.18 D over 2.00 to 3.50 D, ±5% over 3.50 D.
                    - **Axis** by cylinder: 0.12–0.25 D ±14°; to 0.50 D ±7°; to 0.75 D ±5°; to 1.50 D ±3°; over 1.50 D ±2°. Under 0.12 D it is not defined. Count across 180: 178 to 002 is 4°.
                    - **Add**: up to 4.00 D ±0.12 D; over 4.00 D ±0.18 D.
                    - **Prescribed prism** (new in 2025): up to 6Δ ±0.33Δ; over 6Δ ±0.5Δ.
                    - **Vertical**, up to ±3.375 D in the vertical meridian: ≤0.33Δ imbalance; above that, PRP heights differ ≤1.0 mm.
                    - **Horizontal**, single vision and multifocal up to ±2.75 D: ≤0.67Δ imbalance; above that, PD within ±2.5 mm. Progressives up to ±3.75 D: ≤0.67Δ; above that, each fitting cross within ±1.0 mm of its monocular PD.
                    - **Seg / fitting cross height**: ±1.0 mm per lens, and the pair may differ by no more than 1.0 mm.

                    In this trainer, imbalance is Prentice's rule with the eyes midway between the two PRPs, and prescribed prism (OD only) replaces the imbalance check in its meridian.
                    """)
                    .font(.subheadline)
                    .padding(.top, 8)
                    SourceList(sources: Self.sources)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 8)
                }
                .tint(palette.accent)
            }
            .padding()
        }
        .pettyScreen()
        .navigationTitle("ANSI Job Check")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var orderPanel: some View {
        Panel {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Ordered").font(.headline)
                    Spacer()
                    Chip(text: job.type.title, selected: true)
                }
                ForEach(Z80Job.Eye.allCases, id: \.self) { eye in
                    Text(orderLine(eye)).font(.subheadline.monospacedDigit())
                }
                if let prism = job.orderedPrism {
                    Text("Prism OD \(Z80Job.prism(prism.amount, prism.base.rawValue))").font(.subheadline.monospacedDigit())
                }
                Text(job.progressive
                     ? "Monocular PD \(Z80Job.mm(job.pd[.od]!)) / \(Z80Job.mm(job.pd[.os]!))"
                     : "Distance PD \(Z80Job.mm(job.pd[.od]!))")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(palette.secondaryText)
            }
        }
    }

    private func itemRow(_ item: Z80Job.Item) -> some View {
        Panel(padding: 12) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text(item.title).font(.subheadline.weight(.semibold))
                    Spacer()
                    if checked {
                        Image(systemName: calls[item.id] == item.passes ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(calls[item.id] == item.passes ? .green : .red)
                    }
                }
                Text("Ordered \(item.ordered)").font(.caption.monospacedDigit()).foregroundStyle(palette.secondaryText)
                Text("Measured \(item.measured)").font(.caption.monospacedDigit()).foregroundStyle(palette.text)
                callButtons(selection: calls[item.id]) { calls[item.id] = $0 }
                if checked {
                    Text("\(item.passes ? "PASS" : "FAIL"). \(item.rule)")
                        .font(.caption)
                        .foregroundStyle(item.passes ? palette.secondaryText : .red)
                }
            }
        }
    }

    private func callButtons(selection: Bool?, set: @escaping (Bool) -> Void) -> some View {
        HStack(spacing: 8) {
            Button { set(true) } label: { Chip(text: "Pass", symbol: "checkmark", selected: selection == true) }
            Button { set(false) } label: { Chip(text: "Fail", symbol: "xmark", selected: selection == false) }
        }
        .buttonStyle(.plain)
        .disabled(checked)
    }

    private func orderLine(_ eye: Z80Job.Eye) -> String {
        let lens = job.ordered[eye]!
        var line = "\(eye.rawValue) \(OpticsMath.formatPower(lens.rx.sphere))"
        if lens.rx.cylinder != 0 {
            line += " \(OpticsMath.formatPower(lens.rx.cylinder)) × \(Z80Job.axisText(lens.rx.axis))"
        } else {
            line += " DS"
        }
        if let add = lens.add { line += "  Add \(OpticsMath.formatPower(add))" }
        if let height = lens.height { line += "  Ht \(Z80Job.mm(height))" }
        return line
    }

    private func check() {
        checked = true
        attempts += 1
        if overallCall == job.passes, job.items.allSatisfy({ calls[$0.id] == $0.passes }) {
            correctCount += 1
        }
    }

    private func next() {
        job = .random()
        calls = [:]
        overallCall = nil
        checked = false
    }
}
