import SwiftUI

struct CorneaReading: Equatable, Sendable {
    var flatK: Double
    var steepK: Double
    var flatAxis: Int

    var cylinder: Double { steepK - flatK }
    var steepAxis: Int { Self.normalized(flatAxis + 90) }

    nonisolated func power(atMeridian meridian: Double) -> Double {
        let delta = (meridian - Double(flatAxis)) * .pi / 180
        return flatK + cylinder * sin(delta) * sin(delta)
    }

    /// With-the-rule when the steep meridian is within 30° of vertical, against-the-rule within 30° of horizontal.
    var astigmatismType: String {
        guard cylinder > 0 else { return "Spherical cornea" }
        let fromVertical = LensometerTrainerView.axisDifference(steepAxis, 90)
        if fromVertical <= 30 { return "With-the-rule" }
        if fromVertical >= 60 { return "Against-the-rule" }
        return "Oblique"
    }

    nonisolated static func normalized(_ axis: Int) -> Int {
        let a = axis % 180
        return a == 0 ? 180 : a
    }
}

/// B&L-style one-position keratometer: plus signs measure the meridian on the axis wheel, minus signs the one 90° away.
struct KeratometerTrainerView: View {
    @State private var cornea = Self.randomCornea()
    @State private var axisWheel = 180.0
    @State private var horizontalDrum = 43.0
    @State private var verticalDrum = 43.0
    @State private var answerK1 = 43.0
    @State private var answerAxis = 180.0
    @State private var answerK2 = 43.0
    @State private var result: Bool?
    @State private var correctCount = 0
    @State private var attempts = 0
    @State private var showingHelp = false
    @Environment(\.palette) private var palette

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                KeratometerMires(cornea: cornea, axisWheel: axisWheel, horizontalDrum: horizontalDrum, verticalDrum: verticalDrum)
                    .frame(maxWidth: 360)
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel("Keratometer mires")

                Panel {
                    VStack(spacing: 14) {
                        control(title: "Axis wheel", value: axisText(Int(axisWheel)), range: 1...180, step: 1, value: $axisWheel, wraps: true)
                        control(title: "Horizontal drum (plus signs)", value: kText(horizontalDrum), range: 36...52, step: 0.125, value: $horizontalDrum)
                        control(title: "Vertical drum (minus signs)", value: kText(verticalDrum), range: 36...52, step: 0.125, value: $verticalDrum)
                    }
                }

                Panel {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Record the K readings").font(.headline)
                        Stepper(value: $answerK1, in: 36...52, step: 0.125) { LabeledContent("First K", value: kText(answerK1)) }
                        Stepper(value: $answerAxis, in: 1...180, step: 1) { LabeledContent("@ axis", value: axisText(Int(answerAxis))) }
                        Stepper(value: $answerK2, in: 36...52, step: 0.125) {
                            LabeledContent("Second K", value: "\(kText(answerK2)) @ \(axisText(CorneaReading.normalized(Int(answerAxis) + 90)))")
                        }
                        HStack {
                            Button("Use drum values") {
                                answerK1 = horizontalDrum
                                answerAxis = axisWheel
                                answerK2 = verticalDrum
                            }
                            .buttonStyle(.bordered)
                            Spacer()
                            Button("Check", action: check)
                                .buttonStyle(.borderedProminent)
                                .accessibilityIdentifier("keratometer.check")
                        }
                        if let result {
                            Label(result ? "Correct" : "The cornea reads \(readingText(cornea))", systemImage: result ? "checkmark.seal.fill" : "xmark.octagon.fill")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(result ? .green : .red)
                            Text(summary(cornea))
                                .font(.caption)
                                .foregroundStyle(palette.secondaryText)
                            Button("Next Eye", action: nextCornea).buttonStyle(.borderedProminent)
                        }
                    }
                }

                Text("Score \(correctCount) / \(attempts)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(palette.secondaryText)

                DisclosureGroup("How to read it", isExpanded: $showingHelp) {
                    RichText(text: """
                    - Rotate the **axis wheel** until the two **plus signs** are in step (their horizontal bars line up). The instrument is now on the principal meridians.
                    - Turn the **horizontal drum** until the plus signs superimpose. That is the power of the meridian on the axis wheel.
                    - Turn the **vertical drum** until the **minus signs** superimpose. That is the power of the meridian 90° away; a one-position instrument needs no rotation.
                    - Record both meridians, e.g. **42.00 @ 180 / 43.50 @ 090**. Lower diopters = flatter; the difference is the corneal cylinder.
                    - Radius (mm) = 337.5 ÷ K. With-the-rule corneas are steepest near 090, against-the-rule near 180.

                    Simplified simulation: real mires must also be focused and centered on the reticle, and mire distortion signals an irregular cornea.
                    """)
                    .font(.subheadline)
                    .padding(.top, 8)
                    SourceList(sources: [SourceLink(title: "StatPearls: Keratometer", url: URL(string: "https://www.ncbi.nlm.nih.gov/books/NBK580516/")!)])
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 8)
                }
                .tint(palette.accent)
            }
            .padding()
        }
        .pettyScreen()
        .navigationTitle("Keratometer Trainer")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func control(title: String, value text: String, range: ClosedRange<Double>, step: Double, value: Binding<Double>, wraps: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title).font(.subheadline.weight(.semibold))
                Spacer()
                Text(text).font(.headline.monospacedDigit()).foregroundStyle(palette.accent)
            }
            HStack(spacing: 10) {
                Button {
                    value.wrappedValue = value.wrappedValue <= range.lowerBound ? (wraps ? range.upperBound : range.lowerBound) : value.wrappedValue - step
                } label: { Image(systemName: "minus.circle.fill").font(.title2) }
                Slider(value: value, in: range, step: step)
                Button {
                    value.wrappedValue = value.wrappedValue >= range.upperBound ? (wraps ? range.lowerBound : range.upperBound) : value.wrappedValue + step
                } label: { Image(systemName: "plus.circle.fill").font(.title2) }
            }
            .buttonStyle(.plain)
            .foregroundStyle(palette.accent)
        }
    }

    private func check() {
        attempts += 1
        result = Self.matches(k1: answerK1, axis: Int(answerAxis), k2: answerK2, cornea: cornea)
        if result == true { correctCount += 1 }
    }

    private func nextCornea() {
        cornea = Self.randomCornea()
        result = nil
    }

    private func kText(_ k: Double) -> String { String(format: "%.2f D", k) }
    private func axisText(_ axis: Int) -> String { String(format: "%03d", axis) }

    private func readingText(_ c: CorneaReading) -> String {
        c.cylinder == 0
            ? "\(String(format: "%.2f", c.flatK)) D in all meridians"
            : "\(String(format: "%.2f", c.flatK)) @ \(axisText(c.flatAxis)) / \(String(format: "%.2f", c.steepK)) @ \(axisText(c.steepAxis))"
    }

    private func summary(_ c: CorneaReading) -> String {
        let radii = c.cylinder == 0
            ? String(format: "%.2f mm", OpticsMath.radiusMM(diopters: c.flatK))
            : String(format: "%.2f / %.2f mm", OpticsMath.radiusMM(diopters: c.flatK), OpticsMath.radiusMM(diopters: c.steepK))
        guard c.cylinder > 0 else { return "Spherical cornea · radius \(radii)" }
        return "Corneal cylinder \(String(format: "%.2f", c.cylinder)) D · \(c.astigmatismType) · radii \(radii)"
    }

    nonisolated static func randomCornea() -> CorneaReading {
        let flat = 40 + Double(Int.random(in: 0...24)) * 0.25
        let cylinder = Int.random(in: 0...4) == 0 ? 0 : Double(Int.random(in: 1...12)) * 0.25
        let axis: Int = switch Int.random(in: 0...9) {
        case 0...5: CorneaReading.normalized(180 + Int.random(in: -3...3) * 5)
        case 6...7: 90 + Int.random(in: -3...3) * 5
        default: Int.random(in: 6...30) * 5
        }
        return CorneaReading(flatK: flat, steepK: flat + cylinder, flatAxis: cylinder == 0 ? 180 : axis)
    }

    /// Either meridian may be recorded first; powers within one drum step (0.125 D), axis within ±5°.
    nonisolated static func matches(k1: Double, axis: Int, k2: Double, cornea: CorneaReading) -> Bool {
        let tolerance = 0.13
        let candidates = [
            (cornea.flatK, cornea.flatAxis, cornea.steepK),
            (cornea.steepK, cornea.steepAxis, cornea.flatK),
        ]
        return candidates.contains { first, firstAxis, second in
            abs(k1 - first) <= tolerance
                && abs(k2 - second) <= tolerance
                && (cornea.cylinder == 0 || LensometerTrainerView.axisDifference(axis, firstAxis) <= 5)
        }
    }
}

private struct KeratometerMires: View {
    let cornea: CorneaReading
    let axisWheel: Double
    let horizontalDrum: Double
    let verticalDrum: Double

    var body: some View {
        Canvas { ctx, size in
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            let r = min(size.width, size.height) / 2
            let field = Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
            ctx.fill(field, with: .color(Color(red: 0.06, green: 0.05, blue: 0.03)))
            var clipped = ctx
            clipped.clip(to: field)

            let ring = r * 0.2
            let perDiopter = ring * 0.22
            let hGap = max(-ring * 0.9, min(ring * 1.4, (horizontalDrum - cornea.power(atMeridian: axisWheel)) * perDiopter))
            let vGap = max(-ring * 0.9, min(ring * 1.4, (verticalDrum - cornea.power(atMeridian: axisWheel + 90)) * perDiopter))
            let misalignment = (axisWheel - Double(cornea.flatAxis)) * .pi / 90
            let step = sin(misalignment) * cornea.cylinder * ring * 0.18

            // Measured from 180 so the plus mire sits right and the minus mire above, as on a B&L; screen y runs down.
            let angle = -(axisWheel - 180) * .pi / 180
            let along = CGVector(dx: cos(angle), dy: sin(angle))
            let across = CGVector(dx: sin(angle), dy: -cos(angle))
            func point(_ origin: CGPoint, _ a: Double, _ b: Double) -> CGPoint {
                CGPoint(x: origin.x + along.dx * a + across.dx * b, y: origin.y + along.dy * a + across.dy * b)
            }

            let center = point(c, -ring * 0.9, -ring * 0.9)
            let plusCircle = point(center, ring * 2 + hGap, step)
            let minusCircle = point(center, -step, ring * 2 + vGap)
            let mire = Color(red: 1.0, green: 0.86, blue: 0.55)

            for origin in [center, plusCircle, minusCircle] {
                clipped.stroke(Path(ellipseIn: CGRect(x: origin.x - ring, y: origin.y - ring, width: ring * 2, height: ring * 2)), with: .color(mire), lineWidth: 2.5)
            }

            let arm = ring * 0.22
            func plusSign(_ at: CGPoint) {
                clipped.stroke(Path { $0.move(to: point(at, -arm, 0)); $0.addLine(to: point(at, arm, 0)) }, with: .color(mire), lineWidth: 2.5)
                clipped.stroke(Path { $0.move(to: point(at, 0, -arm)); $0.addLine(to: point(at, 0, arm)) }, with: .color(mire), lineWidth: 2.5)
            }
            func minusSign(_ at: CGPoint) {
                clipped.stroke(Path { $0.move(to: point(at, -arm * 1.3, 0)); $0.addLine(to: point(at, arm * 1.3, 0)) }, with: .color(mire), lineWidth: 3)
            }
            plusSign(point(center, ring, 0))
            plusSign(point(plusCircle, -ring, 0))
            minusSign(point(center, 0, ring))
            minusSign(point(minusCircle, 0, -ring))

            let reticle = Color.white.opacity(0.35)
            clipped.stroke(Path { $0.move(to: point(center, -ring * 0.5, 0)); $0.addLine(to: point(center, ring * 0.5, 0)) }, with: .color(reticle), lineWidth: 0.8)
            clipped.stroke(Path { $0.move(to: point(center, 0, -ring * 0.5)); $0.addLine(to: point(center, 0, ring * 0.5)) }, with: .color(reticle), lineWidth: 0.8)
            ctx.stroke(field, with: .color(.black.opacity(0.6)), lineWidth: 6)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}
