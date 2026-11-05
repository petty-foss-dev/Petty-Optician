import SwiftUI

enum SoftLensFit: String, CaseIterable, Identifiable, Sendable {
    case good, tight, loose, decentered

    var id: String { rawValue }

    var title: String {
        switch self {
        case .good: "Good fit"
        case .tight: "Tight (steep) fit"
        case .loose: "Loose (flat) fit"
        case .decentered: "Decentered lens"
        }
    }

    var signs: String {
        switch self {
        case .good: "Centered with full corneal coverage and about 1 mm of lens overlapping the sclera all the way around. It moves 0.2–0.4 mm on the blink, pushes up smoothly and recenters smoothly. Vision is crisp and stable."
        case .tight: "Little or no movement on the blink (under about 0.1 mm). The lens resists push-up and drifts back slowly. The edge may indent the conjunctival vessels, with limbal or conjunctival redness. Vision can clear just after a blink, and the lens often feels comfortable at first."
        case .loose: "Excessive movement (over about 0.5 mm) and the lens drops after the blink, often riding low. Push-up is easy, with a quick or erratic recovery. The edge may stand off or flute. Vision is variable and worse just after the blink, and comfort is poorer."
        case .decentered: "The lens settles consistently off center, so its edge crosses onto the cornea and part of the limbus is left uncovered. Movement and push-up can look normal. Incomplete coverage causes lens awareness and can lead to desiccation staining."
        }
    }

    var action: String {
        switch self {
        case .good: "No change. Confirm coverage in all directions of gaze, comfort and a stable over-refraction."
        case .tight: "Loosen it: flatten the base curve (longer radius) and/or reduce the total diameter. Diameter usually changes a soft fit more than base curve; if neither works, try a different design or material."
        case .loose: "Tighten it: steepen the base curve (shorter radius) and/or increase the total diameter. If neither works, try a different design or material."
        case .decentered: "Increase the total diameter to restore full corneal coverage. When a displaced corneal apex is the cause, base curve changes do little for centration."
        }
    }
}

enum LensDecentration: String, CaseIterable, Sendable {
    case superior, nasal, temporal

    /// Examiner's view of a right eye: +x is the patient's nasal side, +y is down.
    nonisolated var direction: SIMD2<Double> {
        switch self {
        case .superior: [0, -1]
        case .nasal: [1, 0]
        case .temporal: [-1, 0]
        }
    }

    var oppositeSide: String {
        switch self {
        case .superior: "inferior"
        case .nasal: "temporal"
        case .temporal: "nasal"
        }
    }
}

struct SoftLensScene: Equatable, Sendable {
    var lens: SIMD2<Double>
    var upperLid: Double
    var lowerLid: Double
    var pushing: Bool
}

/// Soft-lens dynamics in millimetres, cornea-centered, +y down. Times are in seconds.
struct SoftLensCase: Sendable {
    struct Variation: Sendable {
        var amount = 0.5
        var timing = 0.5
        var offset = SIMD2<Double>(0, 0)
        var decentration = LensDecentration.temporal

        static func random() -> Variation {
            Variation(
                amount: .random(in: 0...1),
                timing: .random(in: 0...1),
                offset: [.random(in: -1...1), .random(in: -1...1)],
                decentration: LensDecentration.allCases.randomElement()!
            )
        }
    }

    static let lensRadius = 7.1
    static let corneaRadius = 5.9
    static let pupilRadius = 1.8
    static let upperLidRest = -4.6
    static let lowerLidRest = 8.4
    static let lidTravel = 1.6
    static let pushPhase = 0.5
    static let holdEnd = 0.9
    static let lidReturn = 0.3
    static let firstBlink = 1.0

    let fit: SoftLensFit
    let movement: Double
    let rest: SIMD2<Double>
    let pushFactor: Double
    let recoveryTau: Double
    let blinkInterval: Double
    let decentration: LensDecentration?

    nonisolated init(fit: SoftLensFit, variation v: Variation) {
        func lerp(_ range: ClosedRange<Double>, _ t: Double) -> Double {
            range.lowerBound + (range.upperBound - range.lowerBound) * t
        }
        self.fit = fit
        blinkInterval = lerp(2.8...4.4, v.timing)
        switch fit {
        case .good, .decentered:
            movement = lerp(0.22...0.38, v.amount)
            pushFactor = lerp(0.85...0.95, v.amount)
            recoveryTau = lerp(0.35...0.55, v.timing)
            rest = fit == .good
                ? v.offset * 0.12
                : v.decentration.direction * lerp(1.45...1.85, v.amount) + v.offset * 0.1
        case .tight:
            movement = lerp(0...0.06, v.amount)
            pushFactor = lerp(0.18...0.32, v.amount)
            recoveryTau = lerp(1.1...1.6, v.timing)
            rest = v.offset * 0.08
        case .loose:
            movement = lerp(0.65...1.0, v.amount)
            pushFactor = lerp(1.1...1.2, v.amount)
            recoveryTau = lerp(0.14...0.2, v.timing)
            rest = [v.offset.x * 0.2, lerp(0.45...0.75, v.amount)]
        }
        decentration = fit == .decentered ? v.decentration : nil
    }

    static func random(_ fit: SoftLensFit) -> SoftLensCase {
        SoftLensCase(fit: fit, variation: .random())
    }

    nonisolated var offCenter: Double { length(rest) }

    nonisolated var exposesLimbus: Bool { offCenter > Self.lensRadius - Self.corneaRadius }

    nonisolated var pushUpLift: Double { pushFactor * Self.lidTravel }

    nonisolated var pushUpDuration: Double { Self.holdEnd + max(Self.lidReturn, recoveryTau * 5) }

    /// Seconds after release until the lens stays within 10% of its push-up displacement.
    nonisolated var recoveryTime: Double {
        var last = 0.0
        for step in 0..<Int(recoveryTau * 800) {
            let r = Double(step) / 100
            if abs(pushUp(Self.holdEnd + r).lift) > pushUpLift * 0.1 { last = r }
        }
        return last
    }

    nonisolated func lidClosure(_ s: Double) -> Double {
        switch s {
        case ..<0.1: ease(s / 0.1)
        case ..<0.15: 1
        default: 1 - ease((s - 0.15) / 0.2)
        }
    }

    /// Upward lens displacement `s` seconds into a blink: carried up as the lid opens, then settling.
    nonisolated func blinkLift(_ s: Double) -> Double {
        if s < 0.35 { return movement * ease((s - 0.12) / 0.23) }
        return movement * settle(s - 0.35, tau: fit == .tight ? 0.5 : 0.3)
    }

    /// Lower-lid margin and upward lens displacement `e` seconds after the push-up starts.
    nonisolated func pushUp(_ e: Double) -> (lid: Double, lift: Double) {
        let contact = Self.lensRadius + rest.y + 0.05
        let peakLid = contact - Self.lidTravel
        if e < Self.holdEnd {
            let lid = Self.lowerLidRest + (peakLid - Self.lowerLidRest) * ease(e / Self.pushPhase)
            return (lid, pushFactor * max(0, contact - lid))
        }
        let r = e - Self.holdEnd
        return (peakLid + (Self.lowerLidRest - peakLid) * ease(r / Self.lidReturn), pushUpLift * settle(r, tau: recoveryTau))
    }

    /// `t` counts from the case start or the end of the last push-up; `pushUpElapsed` overrides blinking while the test runs.
    nonisolated func scene(at t: Double, pushUpElapsed: Double? = nil) -> SoftLensScene {
        if let e = pushUpElapsed {
            let p = pushUp(e)
            return SoftLensScene(lens: rest - [0, p.lift], upperLid: Self.upperLidRest, lowerLid: p.lid, pushing: true)
        }
        guard t >= Self.firstBlink else {
            return SoftLensScene(lens: rest, upperLid: Self.upperLidRest, lowerLid: Self.lowerLidRest, pushing: false)
        }
        let s = (t - Self.firstBlink).truncatingRemainder(dividingBy: blinkInterval)
        let closure = lidClosure(s)
        let meet = Self.lowerLidRest - 0.5
        return SoftLensScene(
            lens: rest - [0, blinkLift(s)],
            upperLid: Self.upperLidRest + (meet - Self.upperLidRest) * closure,
            lowerLid: Self.lowerLidRest - 0.5 * closure,
            pushing: false
        )
    }

    private nonisolated func settle(_ s: Double, tau: Double) -> Double {
        let decay = exp(-s / tau)
        return fit == .loose ? decay * cos(2 * .pi * s / (tau * 3.5)) : decay
    }
}

private nonisolated func ease(_ t: Double) -> Double {
    let c = min(1, max(0, t))
    return c * c * (3 - 2 * c)
}

private nonisolated func length(_ v: SIMD2<Double>) -> Double {
    (v * v).sum().squareRoot()
}

struct SoftLensFitTrainerView: View {
    @State private var fitCase = SoftLensCase.random(SoftLensFit.allCases.randomElement()!)
    @State private var look = EyeLook.random()
    @State private var start = Date()
    @State private var pushUpStart: Date?
    @State private var choices: [SoftLensFit] = []
    @State private var picked: SoftLensFit?
    @State private var correctCount = 0
    @State private var attempts = 0
    @Environment(\.palette) private var palette

    private static let sources = [
        SourceLink(title: "J&J Institute: Soft Contact Lens Fitting (Huntjens)", url: URL(string: "https://assets.contentstack.io/v3/assets/bltc6e7ece114c6734f/bltec0e7e17fbd58e5a/68230a94a66a229f1d16d701/2025PP05123_ECLP-MEA_07_SoftContactLensFitting.pdf")!),
        SourceLink(title: "SpecialEyes: Trouble-shooting the Fit of a Custom Soft Contact Lens", url: URL(string: "https://blog.specialeyesqc.com/trouble-shooting-the-fit-of-a-custom-soft-contact-lens")!),
        SourceLink(title: "DOCET (Aston University): Evaluating and Recording Soft Contact Lens Fit", url: URL(string: "https://docet.info/pluginfile.php/57078/mod_resource/content/1/Soft%20lens%20fit%20evaluation.pdf")!),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SoftLensEye(fitCase: fitCase, look: look, start: start, pushUpStart: pushUpStart)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .frame(maxWidth: 440)
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel("Simulated slit-lamp view of a soft contact lens on a right eye")

                HStack {
                    Text("Right eye, examiner's view")
                        .font(.caption)
                        .foregroundStyle(palette.secondaryText)
                    Spacer()
                    Button(action: startPushUp) {
                        Label("Push-up test", systemImage: "hand.point.up.left")
                    }
                    .buttonStyle(.bordered)
                    .tint(palette.accent)
                    .accessibilityIdentifier("softlens.pushup")
                }

                Text("Watch a few blinks, then run the push-up test. How does this soft lens fit?")
                    .font(.headline)

                VStack(spacing: 10) {
                    ForEach(choices) { choice in
                        Button { answer(choice) } label: {
                            HStack {
                                Text(choice.title).multilineTextAlignment(.leading)
                                Spacer()
                                if let picked {
                                    if choice == fitCase.fit {
                                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                                    } else if choice == picked {
                                        Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
                                    }
                                }
                            }
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(palette.text)
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(palette.cardBackground, in: RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                        .disabled(picked != nil)
                    }
                }

                if picked != nil {
                    Panel {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(fitCase.fit.title).font(.headline)
                            Label { Text(observation) } icon: { Image(systemName: "ruler") }
                                .font(.subheadline)
                            Label { Text(fitCase.fit.signs) } icon: { Image(systemName: "eye") }
                                .font(.subheadline)
                            Label { Text(fitCase.fit.action) } icon: { Image(systemName: "wrench.adjustable") }
                                .font(.subheadline)
                            Button("Next Eye", action: next)
                                .buttonStyle(.borderedProminent)
                                .accessibilityIdentifier("softlens.next")
                        }
                    }
                }

                Text("Score \(correctCount) / \(attempts)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(palette.secondaryText)

                Panel {
                    VStack(alignment: .leading, spacing: 10) {
                        RichText(text: """
                        - **Coverage and centration:** about 1 mm of lens should overlap the sclera all the way around. The scale bar is 1 mm.
                        - **Movement:** watch the lower edge against a conjunctival vessel just after each blink. About 0.2–0.4 mm is ideal.
                        - **Push-up:** a good lens moves up smoothly and recenters smoothly. Resistance with slow recovery means tight; easy push-up with quick or erratic recovery means loose. Tightness is often graded 0–100%, with about 50% ideal.

                        Simulated eye. Real movement varies with lens material and settling time, so judge all the signs together.
                        """)
                        .font(.caption)
                        SourceList(sources: Self.sources)
                    }
                }
            }
            .padding()
        }
        .pettyScreen()
        .navigationTitle("Soft Lens Fit")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { if choices.isEmpty { choices = Self.choices(for: fitCase.fit) } }
    }

    private var observation: String {
        func mm(_ value: Double) -> String { value.formatted(.number.precision(.fractionLength(2))) }
        var parts = [
            fitCase.movement < 0.1
                ? "Barely moved on the blink (about \(mm(fitCase.movement)) mm)."
                : "Moved about \(mm(fitCase.movement)) mm on each blink.",
            "On push-up it rose \(mm(fitCase.pushUpLift)) mm for \(mm(SoftLensCase.lidTravel)) mm of lid travel and recentered in about \(fitCase.recoveryTime.formatted(.number.precision(.fractionLength(1)))) s.",
        ]
        if let decentration = fitCase.decentration {
            parts.append("It settled \(mm(fitCase.offCenter)) mm \(decentration.rawValue), uncovering the \(decentration.oppositeSide) limbus.")
        } else if fitCase.fit == .loose {
            parts.append("It rode \(mm(fitCase.rest.y)) mm low.")
        }
        return parts.joined(separator: " ")
    }

    private func startPushUp() {
        let now = Date()
        if let pushUpStart, now.timeIntervalSince(pushUpStart) < fitCase.pushUpDuration { return }
        pushUpStart = now
    }

    private func answer(_ choice: SoftLensFit) {
        picked = choice
        attempts += 1
        if choice == fitCase.fit { correctCount += 1 }
    }

    private func next() {
        fitCase = SoftLensCase.random(SoftLensFit.allCases.randomElement()!)
        look = EyeLook.random()
        start = Date()
        pushUpStart = nil
        picked = nil
        choices = Self.choices(for: fitCase.fit)
    }

    nonisolated static func choices(for fit: SoftLensFit) -> [SoftLensFit] {
        (SoftLensFit.allCases.filter { $0 != fit }.shuffled().prefix(3) + [fit]).shuffled()
    }
}

private struct EyeLook {
    struct Vessel {
        var points: [SIMD2<Double>]
        var width: Double
        var opacity: Double
    }

    var irisInner: Color
    var irisOuter: Color
    var vessels: [Vessel]

    static let irises: [(Color, Color)] = [
        (Color(red: 0.55, green: 0.36, blue: 0.16), Color(red: 0.3, green: 0.17, blue: 0.07)),
        (Color(red: 0.55, green: 0.68, blue: 0.8), Color(red: 0.25, green: 0.38, blue: 0.55)),
        (Color(red: 0.6, green: 0.55, blue: 0.28), Color(red: 0.3, green: 0.38, blue: 0.2)),
        (Color(red: 0.62, green: 0.66, blue: 0.68), Color(red: 0.34, green: 0.38, blue: 0.42)),
    ]

    static func random() -> EyeLook {
        let iris = irises.randomElement()!
        let vessels = (0..<18).map { _ in
            var p = SIMD2<Double>((Bool.random() ? 1 : -1) * .random(in: 9...12), .random(in: -3...8.5))
            var direction = -p / length(p)
            var points = [p]
            let stop = Double.random(in: 6.3...8.5)
            while length(p) > stop, points.count < 20 {
                direction = direction * 0.65 - p / length(p) * 0.35 + SIMD2(.random(in: -0.5...0.5), .random(in: -0.5...0.5))
                direction /= length(direction)
                p += direction * 0.8
                points.append(p)
            }
            return Vessel(points: points, width: .random(in: 0.05...0.16), opacity: .random(in: 0.25...0.6))
        }
        return EyeLook(irisInner: iris.0, irisOuter: iris.1, vessels: vessels)
    }
}

private struct SoftLensEye: View {
    let fitCase: SoftLensCase
    let look: EyeLook
    let start: Date
    let pushUpStart: Date?

    private static let viewWidth = 22.0
    private static let viewHeight = 15.0
    private static let viewCenterY = 1.6

    var body: some View {
        TimelineView(.animation) { context in
            Canvas { ctx, size in
                draw(&ctx, size: size, scene: scene(at: context.date))
            }
        }
        .aspectRatio(Self.viewWidth / Self.viewHeight, contentMode: .fit)
    }

    private func scene(at date: Date) -> SoftLensScene {
        guard let pushUpStart else { return fitCase.scene(at: date.timeIntervalSince(start)) }
        let elapsed = date.timeIntervalSince(pushUpStart)
        return elapsed < fitCase.pushUpDuration
            ? fitCase.scene(at: 0, pushUpElapsed: elapsed)
            : fitCase.scene(at: elapsed - fitCase.pushUpDuration)
    }

    private func draw(_ ctx: inout GraphicsContext, size: CGSize, scene: SoftLensScene) {
        let scale = size.width / Self.viewWidth
        let origin = CGPoint(x: size.width / 2, y: size.height / 2 - Self.viewCenterY * scale)
        func pt(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: origin.x + x * scale, y: origin.y + y * scale) }
        func circle(_ x: Double, _ y: Double, _ r: Double) -> Path {
            Path(ellipseIn: CGRect(x: origin.x + (x - r) * scale, y: origin.y + (y - r) * scale, width: 2 * r * scale, height: 2 * r * scale))
        }
        let bounds = CGRect(origin: .zero, size: size)
        let center = pt(0, 0)
        let cornea = SoftLensCase.corneaRadius

        ctx.fill(Path(bounds), with: .radialGradient(
            Gradient(colors: [Color(red: 0.97, green: 0.94, blue: 0.92), Color(red: 0.86, green: 0.76, blue: 0.74)]),
            center: center, startRadius: cornea * scale, endRadius: 13 * scale
        ))

        for vessel in look.vessels {
            var path = Path()
            let points = vessel.points.map { pt($0.x, $0.y) }
            path.move(to: points[0])
            for i in 1..<max(1, points.count - 1) {
                path.addQuadCurve(to: CGPoint(x: (points[i].x + points[i + 1].x) / 2, y: (points[i].y + points[i + 1].y) / 2), control: points[i])
            }
            path.addLine(to: points[points.count - 1])
            ctx.stroke(path, with: .color(Color(red: 0.78, green: 0.16, blue: 0.18).opacity(vessel.opacity)), lineWidth: vessel.width * scale)
        }

        ctx.fill(circle(0, 0, cornea), with: .radialGradient(
            Gradient(colors: [look.irisInner, look.irisOuter]),
            center: center, startRadius: SoftLensCase.pupilRadius * scale, endRadius: cornea * scale
        ))
        for i in 0..<84 {
            let a = Double(i) / 84 * 2 * .pi + 0.03 * sin(Double(i) * 7.3)
            let shade = 0.1 + 0.12 * (0.5 + 0.5 * sin(Double(i) * 12.9898))
            var ray = Path()
            ray.move(to: pt(cos(a) * (SoftLensCase.pupilRadius + 0.2), sin(a) * (SoftLensCase.pupilRadius + 0.2)))
            ray.addLine(to: pt(cos(a) * (cornea - 0.4), sin(a) * (cornea - 0.4)))
            ctx.stroke(ray, with: .color(.black.opacity(shade)), lineWidth: 0.12 * scale)
        }
        ctx.stroke(circle(0, 0, 3.0), with: .color(.white.opacity(0.12)), lineWidth: 0.25 * scale)
        ctx.drawLayer { layer in
            layer.addFilter(.blur(radius: 0.2 * scale))
            layer.stroke(circle(0, 0, cornea - 0.1), with: .color(.black.opacity(0.55)), lineWidth: 0.45 * scale)
        }
        ctx.fill(circle(0, 0, SoftLensCase.pupilRadius), with: .color(.black))

        let lens = scene.lens
        let lensRadius = SoftLensCase.lensRadius
        ctx.fill(circle(lens.x, lens.y, lensRadius), with: .color(Color(red: 0.6, green: 0.78, blue: 0.95).opacity(0.07)))
        if fitCase.fit == .tight {
            ctx.drawLayer { layer in
                layer.addFilter(.blur(radius: 0.15 * scale))
                layer.stroke(circle(lens.x, lens.y, lensRadius + 0.3), with: .color(Color(red: 0.85, green: 0.2, blue: 0.2).opacity(0.3)), lineWidth: 0.5 * scale)
            }
            ctx.stroke(circle(lens.x, lens.y, lensRadius + 0.06), with: .color(Color(red: 0.5, green: 0.22, blue: 0.22).opacity(0.5)), lineWidth: 0.08 * scale)
        }
        var edge = Path()
        for i in 0...240 {
            let a = Double(i) / 240 * 2 * .pi
            let lower = (a - 0.1 * .pi) / (0.8 * .pi)
            let flute = fitCase.fit == .loose && (0...1).contains(lower) ? 0.15 * sin(a * 16) * sin(lower * .pi) : 0
            let p = pt(lens.x + cos(a) * (lensRadius + flute), lens.y + sin(a) * (lensRadius + flute))
            if i == 0 { edge.move(to: p) } else { edge.addLine(to: p) }
        }
        ctx.stroke(edge, with: .color(.white.opacity(0.55)), lineWidth: 0.09 * scale)
        ctx.stroke(circle(lens.x, lens.y, lensRadius - 0.07), with: .color(.black.opacity(0.12)), lineWidth: 0.04 * scale)

        ctx.drawLayer { layer in
            layer.addFilter(.blur(radius: 0.12 * scale))
            layer.fill(circle(1.2, -1.4, 0.35), with: .color(.white.opacity(0.9)))
        }

        let openness = min(1, max(0, (scene.lowerLid - scene.upperLid) / (SoftLensCase.lowerLidRest - SoftLensCase.upperLidRest)))
        let upperMargin = { (x: Double) in scene.upperLid + 0.03 * openness * x * x }
        let lowerMargin = { (x: Double) in scene.lowerLid - 0.012 * openness * x * x }
        let xs = stride(from: -12.0, through: 12.0, by: 0.5).map { $0 }
        let skin = Color(red: 0.87, green: 0.67, blue: 0.57)
        let skinShade = Color(red: 0.72, green: 0.52, blue: 0.44)

        var upperShadow = Path()
        upperShadow.addLines(xs.map { pt($0, upperMargin($0) + 0.4) })
        ctx.drawLayer { layer in
            layer.addFilter(.blur(radius: 0.4 * scale))
            layer.stroke(upperShadow, with: .color(.black.opacity(0.22)), lineWidth: 1.0 * scale)
        }

        var lowerLid = Path()
        lowerLid.addLines(xs.map { pt($0, lowerMargin($0)) })
        lowerLid.addLine(to: CGPoint(x: bounds.maxX + 20, y: bounds.maxY + 20))
        lowerLid.addLine(to: CGPoint(x: bounds.minX - 20, y: bounds.maxY + 20))
        lowerLid.closeSubpath()
        ctx.fill(lowerLid, with: .linearGradient(Gradient(colors: [skin, skinShade]), startPoint: pt(0, scene.lowerLid), endPoint: pt(0, scene.lowerLid + 3)))
        var lowerRim = Path()
        lowerRim.addLines(xs.map { pt($0, lowerMargin($0)) })
        ctx.stroke(lowerRim, with: .color(Color(red: 0.86, green: 0.5, blue: 0.5)), lineWidth: 0.3 * scale)
        var meniscus = Path()
        meniscus.addLines(xs.map { pt($0, lowerMargin($0) - 0.18) })
        ctx.stroke(meniscus, with: .color(.white.opacity(0.4)), lineWidth: 0.1 * scale)

        if scene.pushing {
            let tip = Path(ellipseIn: CGRect(x: origin.x - 5 * scale, y: origin.y + (scene.lowerLid + 1.1) * scale, width: 10 * scale, height: 7 * scale))
            ctx.fill(tip, with: .radialGradient(
                Gradient(colors: [Color(red: 0.93, green: 0.72, blue: 0.64), Color(red: 0.78, green: 0.55, blue: 0.47)]),
                center: pt(0, scene.lowerLid + 3.5), startRadius: 0, endRadius: 5 * scale
            ))
            ctx.stroke(tip, with: .color(.black.opacity(0.15)), lineWidth: 0.1 * scale)
        }

        var upperLid = Path()
        upperLid.addLines(xs.map { pt($0, upperMargin($0)) })
        upperLid.addLine(to: CGPoint(x: bounds.maxX + 20, y: bounds.minY - 20))
        upperLid.addLine(to: CGPoint(x: bounds.minX - 20, y: bounds.minY - 20))
        upperLid.closeSubpath()
        ctx.fill(upperLid, with: .linearGradient(Gradient(colors: [skinShade, skin]), startPoint: pt(0, -6), endPoint: pt(0, scene.upperLid)))
        var lashes = Path()
        for x in stride(from: -10.6, through: 10.6, by: 0.35) {
            let base = pt(x, upperMargin(x))
            let reach = 1.1 + 0.35 * sin(x * 7.1)
            lashes.move(to: base)
            lashes.addQuadCurve(to: pt(x + x * 0.06, upperMargin(x) - reach), control: pt(x, upperMargin(x) - reach * 0.4))
        }
        ctx.stroke(lashes, with: .color(Color(red: 0.16, green: 0.11, blue: 0.08)), lineWidth: 0.08 * scale)
        var lashLine = Path()
        lashLine.addLines(xs.map { pt($0, upperMargin($0)) })
        ctx.stroke(lashLine, with: .color(Color(red: 0.3, green: 0.18, blue: 0.14)), lineWidth: 0.22 * scale)

        var bar = Path()
        bar.move(to: pt(-10.2, -5.3))
        bar.addLine(to: pt(-9.2, -5.3))
        for x in [-10.2, -9.2] {
            bar.move(to: pt(x, -5.5))
            bar.addLine(to: pt(x, -5.1))
        }
        ctx.stroke(bar, with: .color(.white), lineWidth: 1.5)
        ctx.draw(Text("1 mm").font(.caption2.weight(.semibold)).foregroundStyle(.white), at: pt(-8.9, -5.3), anchor: .leading)

        ctx.fill(Path(bounds), with: .radialGradient(
            Gradient(colors: [.clear, .black.opacity(0.45)]),
            center: center, startRadius: 8 * scale, endRadius: 15 * scale
        ))
    }
}
