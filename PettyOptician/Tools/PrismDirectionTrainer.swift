import SwiftUI

enum PrismTrainerBase: String, CaseIterable, Sendable {
    case baseIn = "Base In", baseOut = "Base Out", baseUp = "Base Up", baseDown = "Base Down"

    var opposite: PrismTrainerBase {
        switch self {
        case .baseIn: .baseOut
        case .baseOut: .baseIn
        case .baseUp: .baseDown
        case .baseDown: .baseUp
        }
    }
}

enum PrismTrainerEye: String, CaseIterable, Sendable {
    case od = "OD", os = "OS"
}

struct PrismTrainerEffect: Equatable, Sendable {
    let amount: Double
    let base: PrismTrainerBase
    let power: Double
    let decentrationMM: Double
}

/// Pupil offsets are millimeters from the OC in the optician's front view: x toward the optician's right, y up.
struct PrismTrainerLens: Equatable, Sendable {
    var eye: PrismTrainerEye
    var rx: SpheroCylinder
    var pupilX: Double
    var pupilY: Double

    var horizontalPower: Double { OpticsMath.obliquePower(rx, meridian: 180) }
    var verticalPower: Double { OpticsMath.obliquePower(rx, meridian: 90) }

    var horizontalEffect: PrismTrainerEffect? {
        PrismDirectionTrainerView.horizontalBase(power: horizontalPower, eye: eye, pupilX: pupilX).map {
            PrismTrainerEffect(amount: OpticsMath.prenticePrism(decentrationMM: pupilX, power: horizontalPower), base: $0, power: horizontalPower, decentrationMM: abs(pupilX))
        }
    }

    var verticalEffect: PrismTrainerEffect? {
        PrismDirectionTrainerView.verticalBase(power: verticalPower, pupilY: pupilY).map {
            PrismTrainerEffect(amount: OpticsMath.prenticePrism(decentrationMM: pupilY, power: verticalPower), base: $0, power: verticalPower, decentrationMM: abs(pupilY))
        }
    }

    /// Base In positive.
    var signedHorizontal: Double {
        guard let effect = horizontalEffect else { return 0 }
        return effect.base == .baseIn ? effect.amount : -effect.amount
    }

    /// Base Up positive.
    var signedVertical: Double {
        guard let effect = verticalEffect else { return 0 }
        return effect.base == .baseUp ? effect.amount : -effect.amount
    }
}

struct PrismTrainerQuestion: Sendable {
    enum Kind: String, CaseIterable, Identifiable, Sendable {
        case single, horizontalPair, verticalPair

        var id: String { rawValue }

        var title: String {
            switch self {
            case .single: "Single lens"
            case .horizontalPair: "Net horizontal (OD + OS)"
            case .verticalPair: "Net vertical (OD + OS)"
            }
        }
    }

    let kind: Kind
    let lenses: [PrismTrainerLens]
    let prompt: String
    let answer: String
    let choices: [String]
    let explanation: String
}

struct PrismDirectionTrainerView: View {
    @State private var focus: PrismTrainerQuestion.Kind?
    @State private var question = Self.randomQuestion(kind: nil)
    @State private var picked: String?
    @State private var correctCount = 0
    @State private var attempts = 0
    @State private var showingHelp = false
    @Environment(\.palette) private var palette

    private static let sources = [
        SourceLink(title: "Eyecare Business: Understanding Prism", url: URL(string: "https://eyecarebusiness.com/issues/2012/october/part-1-understanding-prism/")!),
        SourceLink(title: "20/20 Magazine: Prism Made Easy", url: URL(string: "https://www.2020mag.com/article/prism-made-easy")!),
        SourceLink(title: "20/20 Magazine CE: The Many Facets of Prism in Ophthalmic Lenses, Part 2", url: URL(string: "https://www.2020mag.com/ce/the-many-facets-of-prism-2")!),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text(question.kind.title).font(.headline)
                    Spacer()
                    Picker("Question type", selection: $focus) {
                        Text("Mixed").tag(PrismTrainerQuestion.Kind?.none)
                        ForEach(PrismTrainerQuestion.Kind.allCases) { kind in
                            Text(kind.title).tag(Optional(kind))
                        }
                    }
                    .pickerStyle(.menu)
                }

                PrismLensPair(lenses: question.lenses)
                    .frame(maxWidth: 520)
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel("Front view of the lenses with optical centers and pupils marked")

                Text("Front view: you face the patient, so OD is on your left. N = nasal, T = temporal. ⊕ = optical center, ◉ = pupil. Offsets drawn at 2× scale.")
                    .font(.caption)
                    .foregroundStyle(palette.secondaryText)

                Text(question.prompt)
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(spacing: 10) {
                    ForEach(question.choices, id: \.self) { choice in
                        Button { answer(choice) } label: {
                            HStack {
                                Text(choice).multilineTextAlignment(.leading)
                                Spacer()
                                if let picked {
                                    if choice == question.answer {
                                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                                    } else if choice == picked {
                                        Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
                                    }
                                }
                            }
                            .font(.subheadline.weight(.medium).monospacedDigit())
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
                            Text(question.answer).font(.headline)
                            RichText(text: question.explanation).font(.subheadline)
                            Button("Next Question", action: next)
                                .buttonStyle(.borderedProminent)
                                .accessibilityIdentifier("prism.next")
                        }
                    }
                }

                Text("Score \(correctCount) / \(attempts)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(palette.secondaryText)

                DisclosureGroup("The rules", isExpanded: $showingHelp) {
                    RichText(text: """
                    - **Prentice's rule:** Δ = c × D, with c the distance from the optical center to the pupil in **centimeters** (mm ÷ 10) and D the lens power.
                    - **Plus lenses** are two prisms base to base, so the base is always **toward the optical center**. **Minus lenses** are two prisms apex to apex, so the base is always **away from the optical center**.
                    - **In** is the nasal side and **out** is the temporal side for each eye. Facing the patient, nasal is to your right on OD and to your left on OS, so the same left/right shift reads as opposite bases in the two eyes.
                    - Horizontal prism uses the power in the 180 meridian and vertical prism the power in the 090 meridian. A cylinder adds its power 90° from its axis: −1.00 −2.00 × 090 is −3.00 D in the 180 meridian.
                    - **Compounding** (add): Base In with Base In, Base Out with Base Out, or Base Up before one eye with Base Down before the other.
                    - **Canceling** (subtract): Base In with Base Out, or the same vertical base before both eyes. The net base follows the larger prism.
                    - Net vertical prism is relative, so 1.00Δ Base Up OD is the same imbalance as 1.00Δ Base Down OS.

                    Spheres and cylinders at axis 090 or 180 only, so each question stays in a principal meridian.
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
        .navigationTitle("Prism & Base")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: focus) { next() }
    }

    private func answer(_ choice: String) {
        picked = choice
        attempts += 1
        if choice == question.answer { correctCount += 1 }
    }

    private func next() {
        question = Self.randomQuestion(kind: focus)
        picked = nil
    }

    /// Plus: base toward the OC. Minus: base away from it. For OD (on the optician's left) nasal is toward the optician's right.
    nonisolated static func horizontalBase(power: Double, eye: PrismTrainerEye, pupilX: Double) -> PrismTrainerBase? {
        guard power != 0, pupilX != 0 else { return nil }
        let pupilNasal = (eye == .od) == (pupilX > 0)
        let baseNasal = power > 0 ? !pupilNasal : pupilNasal
        return baseNasal ? .baseIn : .baseOut
    }

    nonisolated static func verticalBase(power: Double, pupilY: Double) -> PrismTrainerBase? {
        guard power != 0, pupilY != 0 else { return nil }
        let baseUp = power > 0 ? pupilY < 0 : pupilY > 0
        return baseUp ? .baseUp : .baseDown
    }

    /// Base In positive.
    nonisolated static func netHorizontal(od: PrismTrainerLens, os: PrismTrainerLens) -> Double {
        od.signedHorizontal + os.signedHorizontal
    }

    /// Base Up OD positive; Base Up before OS counts as Base Down OD.
    nonisolated static func netVertical(od: PrismTrainerLens, os: PrismTrainerLens) -> Double {
        od.signedVertical - os.signedVertical
    }

    nonisolated static func choices(answer: String, distractors: [String]) -> [String] {
        var picked = [answer]
        for distractor in distractors where !picked.contains(distractor) && picked.count < 4 {
            picked.append(distractor)
        }
        return picked.shuffled()
    }

    nonisolated static func randomQuestion(kind: PrismTrainerQuestion.Kind?) -> PrismTrainerQuestion {
        switch kind ?? PrismTrainerQuestion.Kind.allCases.randomElement()! {
        case .single: singleQuestion()
        case .horizontalPair: horizontalPairQuestion()
        case .verticalPair: verticalPairQuestion()
        }
    }

    /// Half-diopter steps with whole-mm offsets keep every Prentice result exact to 0.05Δ, so shown sums add up.
    nonisolated static func randomSphere(max: Int) -> Double {
        let halves = Int.random(in: 1...(max * 2))
        return Double(Bool.random() ? halves : -halves) / 2
    }

    nonisolated static func singleQuestion() -> PrismTrainerQuestion {
        let eye = PrismTrainerEye.allCases.randomElement()!
        let horizontal = Bool.random()
        var rx = SpheroCylinder(sphere: randomSphere(max: 8), cylinder: 0, axis: 180)
        if Int.random(in: 0..<10) < 3 {
            rx.cylinder = -Double(Int.random(in: 1...6)) / 2
            rx.axis = Bool.random() ? 90 : 180
        }
        let mm = Double(Int.random(in: 2...8)) * (Bool.random() ? 1 : -1)
        let lens = PrismTrainerLens(eye: eye, rx: rx, pupilX: horizontal ? mm : 0, pupilY: horizontal ? 0 : mm)
        guard let effect = horizontal ? lens.horizontalEffect : lens.verticalEffect else { return singleQuestion() }

        var distractors = [label(effect.amount, effect.base.opposite)]
        if rx.cylinder != 0 {
            let other = PrismTrainerLens(eye: eye, rx: SpheroCylinder(sphere: horizontal ? lens.verticalPower : lens.horizontalPower, cylinder: 0, axis: 180), pupilX: lens.pupilX, pupilY: lens.pupilY)
            if let wrongMeridian = horizontal ? other.horizontalEffect : other.verticalEffect {
                distractors.append(label(wrongMeridian.amount, wrongMeridian.base))
            }
        }
        distractors += [label(effect.amount * 10, effect.base), label(effect.amount * 10, effect.base.opposite)]

        let meridianNote = rx.cylinder == 0 ? "" : " \(horizontal ? "Horizontal" : "Vertical") prism uses the power in the \(horizontal ? "180" : "090") meridian, which is \(OpticsMath.formatPower(effect.power)) D for \(rxText(rx))."
        let answer = label(effect.amount, effect.base)
        return PrismTrainerQuestion(
            kind: .single,
            lenses: [lens],
            prompt: "\(eye.rawValue) \(rxText(rx)), pupil as drawn. What prism does the patient look through?",
            answer: answer,
            choices: choices(answer: answer, distractors: distractors),
            explanation: eyeLine(lens, effect, horizontal: horizontal) + meridianNote
        )
    }

    nonisolated static func horizontalPairQuestion() -> PrismTrainerQuestion {
        let odPower = randomSphere(max: 6)
        let osPower = Int.random(in: 0..<10) < 6 ? abs(randomSphere(max: 6)) * (odPower > 0 ? 1 : -1) : randomSphere(max: 6)
        let odX = Double(Int.random(in: 2...6)) * (Bool.random() ? 1 : -1)
        // Half the time both pupils sit on the same side (both nasal or both temporal), as with a PD error.
        let osSign: Double = Bool.random() ? (odX > 0 ? -1 : 1) : (Bool.random() ? 1 : -1)
        let od = PrismTrainerLens(eye: .od, rx: SpheroCylinder(sphere: odPower, cylinder: 0, axis: 180), pupilX: odX, pupilY: 0)
        let os = PrismTrainerLens(eye: .os, rx: SpheroCylinder(sphere: osPower, cylinder: 0, axis: 180), pupilX: Double(Int.random(in: 2...6)) * osSign, pupilY: 0)
        let net = netHorizontal(od: od, os: os)
        guard abs(net) > 0.005, let odEffect = od.horizontalEffect, let osEffect = os.horizontalEffect else { return horizontalPairQuestion() }

        let base: PrismTrainerBase = net > 0 ? .baseIn : .baseOut
        let compounding = odEffect.base == osEffect.base
        let wrongOperation = compounding ? abs(odEffect.amount - osEffect.amount) : odEffect.amount + osEffect.amount
        let answer = label(abs(net), base)
        let rule = compounding
            ? "Both lenses give \(odEffect.base.rawValue), which compounds: \(prismText(odEffect.amount)) + \(prismText(osEffect.amount)) = \(prismText(abs(net))) \(base.rawValue)."
            : "\(odEffect.base.rawValue) with \(osEffect.base.rawValue) cancels: subtract, \(prismText(max(odEffect.amount, osEffect.amount))) − \(prismText(min(odEffect.amount, osEffect.amount))) = \(prismText(abs(net))), and the larger prism sets the base: \(base.rawValue)."
        return PrismTrainerQuestion(
            kind: .horizontalPair,
            lenses: [od, os],
            prompt: "OD \(rxText(od.rx)), OS \(rxText(os.rx)), pupils as drawn. What is the net horizontal prism?",
            answer: answer,
            choices: choices(answer: answer, distractors: [
                label(abs(net), base.opposite),
                wrongOperation < 0.005 ? "No net prism" : label(wrongOperation, base),
                label(abs(net) * 10, base),
                label(abs(net) * 10, base.opposite),
            ]),
            explanation: [eyeLine(od, odEffect, horizontal: true), eyeLine(os, osEffect, horizontal: true), rule].joined(separator: "\n\n")
        )
    }

    nonisolated static func verticalPairQuestion() -> PrismTrainerQuestion {
        let reading = Bool.random()
        let shared = -Double(Int.random(in: 3...8))
        func offset() -> Double { Double(Int.random(in: 2...5)) * (Bool.random() ? 1 : -1) }
        let od = PrismTrainerLens(eye: .od, rx: SpheroCylinder(sphere: randomSphere(max: 6), cylinder: 0, axis: 180), pupilX: 0, pupilY: reading ? shared : offset())
        let os = PrismTrainerLens(eye: .os, rx: SpheroCylinder(sphere: randomSphere(max: 6), cylinder: 0, axis: 180), pupilX: 0, pupilY: reading ? shared : offset())
        let net = netVertical(od: od, os: os)
        guard abs(net) > 0.005, let odEffect = od.verticalEffect, let osEffect = os.verticalEffect else { return verticalPairQuestion() }

        let compounding = odEffect.base != osEffect.base
        let wrongOperation = compounding ? abs(odEffect.amount - osEffect.amount) : odEffect.amount + osEffect.amount
        let answer = verticalLabel(abs(net), upOD: net > 0)
        let rule = compounding
            ? "\(odEffect.base.rawValue) OD with \(osEffect.base.rawValue) OS compounds: \(prismText(odEffect.amount)) + \(prismText(osEffect.amount)) = \(prismText(abs(net)))."
            : "\(odEffect.base.rawValue) before both eyes cancels: subtract, \(prismText(max(odEffect.amount, osEffect.amount))) − \(prismText(min(odEffect.amount, osEffect.amount))) = \(prismText(abs(net))), with the base of the larger prism."
        return PrismTrainerQuestion(
            kind: .verticalPair,
            lenses: [od, os],
            prompt: "OD \(rxText(od.rx)), OS \(rxText(os.rx)), pupils as drawn\(reading ? " (reading below the OCs)" : ""). What is the net vertical prism?",
            answer: answer,
            choices: choices(answer: answer, distractors: [
                verticalLabel(abs(net), upOD: net < 0),
                wrongOperation < 0.005 ? "No net prism" : verticalLabel(wrongOperation, upOD: net > 0),
                verticalLabel(abs(net) * 10, upOD: net > 0),
                verticalLabel(abs(net) * 10, upOD: net < 0),
            ]),
            explanation: [eyeLine(od, odEffect, horizontal: false), eyeLine(os, osEffect, horizontal: false), rule + " Net vertical prism is relative: \(answer)."].joined(separator: "\n\n")
        )
    }

    nonisolated static func prismText(_ amount: Double) -> String { String(format: "%.2fΔ", amount) }

    nonisolated static func label(_ amount: Double, _ base: PrismTrainerBase) -> String { "\(prismText(amount)) \(base.rawValue)" }

    nonisolated static func verticalLabel(_ amount: Double, upOD: Bool) -> String {
        "\(prismText(amount)) \(upOD ? "BU OD (= BD OS)" : "BD OD (= BU OS)")"
    }

    nonisolated static func rxText(_ rx: SpheroCylinder) -> String {
        rx.cylinder == 0
            ? "\(OpticsMath.formatPower(rx.sphere)) DS"
            : "\(OpticsMath.formatPower(rx.sphere)) \(OpticsMath.formatPower(rx.cylinder)) × \(String(format: "%03d", rx.axis))"
    }

    nonisolated static func eyeLine(_ lens: PrismTrainerLens, _ effect: PrismTrainerEffect, horizontal: Bool) -> String {
        let place: String
        if horizontal {
            let nasal = (lens.eye == .od) == (lens.pupilX > 0)
            place = nasal ? "nasal of (in from)" : "temporal of (out from)"
        } else {
            place = lens.pupilY > 0 ? "above" : "below"
        }
        let rule = effect.power > 0 ? "plus power, base toward the OC" : "minus power, base away from the OC"
        return "**\(lens.eye.rawValue):** pupil \(Int(effect.decentrationMM)) mm \(place) the OC. Prentice: \(String(format: "%.1f", effect.decentrationMM / 10)) cm × \(String(format: "%.2f", abs(effect.power))) D = \(prismText(effect.amount)); \(rule): **\(effect.base.rawValue)**."
    }
}

private struct PrismLensPair: View {
    let lenses: [PrismTrainerLens]
    @Environment(\.palette) private var palette

    private static let span = CGSize(width: 124, height: 70)
    private static let radius = 24.0
    private static let zoom = 2.0

    var body: some View {
        Canvas { ctx, size in
            let ppm = size.width / Self.span.width
            let mid = CGPoint(x: size.width / 2, y: size.height / 2)
            let ink = palette.text
            func p(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: mid.x + x * ppm, y: mid.y - y * ppm) }
            func circle(_ x: Double, _ y: Double, _ r: Double) -> Path {
                Path(ellipseIn: CGRect(x: mid.x + (x - r) * ppm, y: mid.y - (y + r) * ppm, width: 2 * r * ppm, height: 2 * r * ppm))
            }
            func segment(_ a: CGPoint, _ b: CGPoint) -> Path { Path { $0.move(to: a); $0.addLine(to: b) } }
            func label(_ text: String, _ at: CGPoint, size: CGFloat, color: Color, weight: Font.Weight = .regular) {
                ctx.draw(Text(text).font(.system(size: size, weight: weight)).foregroundStyle(color), at: at)
            }
            let small = max(9, 3.2 * ppm)
            let r = Self.radius

            let bridge = Path {
                $0.move(to: p(-5, 12))
                $0.addQuadCurve(to: p(5, 12), control: p(0, 16))
            }
            ctx.stroke(bridge, with: .color(ink.opacity(0.6)), lineWidth: 1.5 * ppm)

            let bar = 5 * Self.zoom
            ctx.stroke(segment(p(-bar / 2, -20), p(bar / 2, -20)), with: .color(ink), lineWidth: 1.2)
            for end in [-bar / 2, bar / 2] {
                ctx.stroke(segment(p(end, -18.8), p(end, -21.2)), with: .color(ink), lineWidth: 1.2)
            }
            label("5 mm", p(0, -24), size: small, color: palette.secondaryText)

            for eye in PrismTrainerEye.allCases {
                let cx = eye == .od ? -28.0 : 28.0
                let lens = lenses.first { $0.eye == eye }
                let outline = circle(cx, 0, r)
                ctx.fill(outline, with: .color(palette.accent.opacity(lens == nil ? 0.02 : 0.08)))
                ctx.stroke(outline, with: .color(ink.opacity(lens == nil ? 0.25 : 0.8)), lineWidth: 0.6 * ppm)
                label(eye.rawValue, p(cx, r + 4.5), size: max(11, 3.8 * ppm), color: lens == nil ? palette.tertiaryText : ink, weight: .bold)
                let nasalSide: Double = eye == .od ? 1 : -1
                label("N", p(cx + nasalSide * (r - 3.5), 0), size: small, color: palette.secondaryText, weight: .semibold)
                label("T", p(cx - nasalSide * (r - 3.5), 0), size: small, color: palette.secondaryText, weight: .semibold)
                guard let lens else { continue }

                let px = cx + lens.pupilX * Self.zoom, py = lens.pupilY * Self.zoom
                ctx.stroke(segment(p(cx, 0), p(px, py)), with: .color(palette.accent.opacity(0.8)), style: StrokeStyle(lineWidth: max(1, 0.35 * ppm), dash: [3, 3]))
                let distance = Int(max(abs(lens.pupilX), abs(lens.pupilY)))
                let dimension = lens.pupilY == 0 ? p((cx + px) / 2, -5.5) : p(cx + 9, py / 2)
                label("\(distance) mm", dimension, size: small, color: palette.accent, weight: .semibold)

                ctx.stroke(circle(cx, 0, 1.2), with: .color(palette.accent), lineWidth: 1.5)
                ctx.stroke(segment(p(cx - 2.5, 0), p(cx + 2.5, 0)), with: .color(palette.accent), lineWidth: 1.5)
                ctx.stroke(segment(p(cx, -2.5), p(cx, 2.5)), with: .color(palette.accent), lineWidth: 1.5)

                ctx.stroke(circle(px, py, 2.8), with: .color(ink), lineWidth: 1.2)
                ctx.fill(circle(px, py, 1.3), with: .color(ink))

                label(PrismDirectionTrainerView.rxText(lens.rx), p(cx, -r - 4.5), size: small, color: ink, weight: .medium)
            }
        }
        .aspectRatio(Self.span.width / Self.span.height, contentMode: .fit)
        .background(palette.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(palette.separator, lineWidth: 0.5))
    }
}
