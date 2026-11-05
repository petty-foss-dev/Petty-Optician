import SwiftUI

/// Simplified manual-lensometer simulation: sphere lines focus at the axis-meridian power, cylinder lines at sphere + cylinder.
struct LensometerTrainerView: View {
    @State private var lens = Self.randomLens()
    @State private var wheel = 0.0
    @State private var axisWheel = 90.0
    @State private var answerSphere = 0.0
    @State private var answerCylinder = 0.0
    @State private var answerAxis = 90.0
    @State private var result: Bool?
    @State private var correctCount = 0
    @State private var attempts = 0
    @State private var showingHelp = false
    @Environment(\.palette) private var palette
    @Environment(\.bottomBarInset) private var bottomBarInset

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                LensometerTarget(lens: lens, wheel: wheel, axisWheel: axisWheel)
                    .frame(maxWidth: 360)
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel("Lensometer target")

                Panel {
                    VStack(spacing: 14) {
                        wheelRow(title: "Power wheel", value: OpticsMath.formatPower(wheel)) {
                            Slider(value: $wheel, in: -10...10, step: 0.25)
                        } minus: { wheel = max(-10, wheel - 0.25) } plus: { wheel = min(10, wheel + 0.25) }
                        wheelRow(title: "Axis wheel", value: String(format: "%03d°", Int(axisWheel))) {
                            Slider(value: $axisWheel, in: 1...180, step: 1)
                        } minus: { axisWheel = axisWheel <= 1 ? 180 : axisWheel - 1 } plus: { axisWheel = axisWheel >= 180 ? 1 : axisWheel + 1 }
                    }
                }

                Panel {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Record the reading").font(.headline)
                        Stepper(value: $answerSphere, in: -12...12, step: 0.25) { LabeledContent("Sphere", value: OpticsMath.formatPower(answerSphere)) }
                        Stepper(value: $answerCylinder, in: -6...6, step: 0.25) { LabeledContent("Cylinder", value: OpticsMath.formatPower(answerCylinder)) }
                        Stepper(value: $answerAxis, in: 1...180, step: 1) { LabeledContent("Axis", value: String(format: "%03d", Int(answerAxis))) }
                        HStack {
                            Button("Use wheel values") {
                                answerAxis = axisWheel
                                answerSphere = wheel
                            }
                            .buttonStyle(.bordered)
                            Spacer()
                            Button("Check", action: check)
                                .buttonStyle(.borderedProminent)
                                .accessibilityIdentifier("lensometer.check")
                        }
                        if let result {
                            Label(result ? "Correct" : "The lens reads \(rxText(lens))", systemImage: result ? "checkmark.seal.fill" : "xmark.octagon.fill")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(result ? .green : .red)
                            Text("Plus-cylinder form: \(rxText(OpticsMath.transpose(lens)))")
                                .font(.caption)
                                .foregroundStyle(palette.secondaryText)
                            Button("Next Lens", action: nextLens).buttonStyle(.borderedProminent)
                        }
                    }
                }

                Text("Score \(correctCount) / \(attempts)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(palette.secondaryText)

                DisclosureGroup("How to read it", isExpanded: $showingHelp) {
                    RichText(text: """
                    - Turn the **power wheel** until the thin **sphere lines** are sharp, then turn the **axis wheel** until they are straight and unbroken. Record that power as the sphere and the axis wheel as the axis.
                    - Keep turning the power wheel until the wide **cylinder lines** are sharp. The difference from the first reading is the cylinder.
                    - Going from the first focus toward more minus gives minus-cylinder form; you can record either form, since the trainer accepts both.
                    - If both sets of lines focus together, the lens is spherical.

                    This is a simplified simulation. Real instruments differ (crossed-line or corona targets), and the eyepiece must be focused first.
                    """)
                    .font(.subheadline)
                    .padding(.top, 8)
                }
                .tint(palette.accent)
            }
            .padding()
        }
        .safeAreaPadding(.bottom, bottomBarInset)
        .enveScreen()
        .navigationTitle("Lensometer Trainer")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func wheelRow<S: View>(title: String, value: String, @ViewBuilder slider: () -> S, minus: @escaping () -> Void, plus: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title).font(.subheadline.weight(.semibold))
                Spacer()
                Text(value).font(.headline.monospacedDigit()).foregroundStyle(palette.accent)
            }
            HStack(spacing: 10) {
                Button(action: minus) { Image(systemName: "minus.circle.fill").font(.title2) }
                slider()
                Button(action: plus) { Image(systemName: "plus.circle.fill").font(.title2) }
            }
            .buttonStyle(.plain)
            .foregroundStyle(palette.accent)
        }
    }

    private func check() {
        attempts += 1
        let entered = SpheroCylinder(sphere: answerSphere, cylinder: answerCylinder, axis: Int(answerAxis))
        result = Self.matches(entered, lens)
        if result == true { correctCount += 1 }
    }

    private func nextLens() {
        lens = Self.randomLens()
        result = nil
    }

    private func rxText(_ rx: SpheroCylinder) -> String {
        rx.cylinder == 0
            ? "\(OpticsMath.formatPower(rx.sphere)) DS"
            : "\(OpticsMath.formatPower(rx.sphere)) \(OpticsMath.formatPower(rx.cylinder)) × \(String(format: "%03d", rx.axis))"
    }

    static func randomLens() -> SpheroCylinder {
        let sphere = Double(Int.random(in: -24...16)) * 0.25
        let cylinder = Bool.random() && Bool.random() ? 0 : -Double(Int.random(in: 1...12)) * 0.25
        return SpheroCylinder(sphere: sphere, cylinder: cylinder, axis: Int.random(in: 1...36) * 5)
    }

    /// Accepts minus- or plus-cylinder form; axis within ±3°, ignored for spheres.
    nonisolated static func matches(_ entered: SpheroCylinder, _ lens: SpheroCylinder) -> Bool {
        let candidates = [lens, OpticsMath.transpose(lens)]
        return candidates.contains { target in
            abs(entered.sphere - target.sphere) < 0.01
                && abs(entered.cylinder - target.cylinder) < 0.01
                && (target.cylinder == 0 || axisDifference(entered.axis, target.axis) <= 3)
        }
    }

    nonisolated static func axisDifference(_ a: Int, _ b: Int) -> Int {
        let d = abs(a - b) % 180
        return min(d, 180 - d)
    }
}

private struct LensometerTarget: View {
    let lens: SpheroCylinder
    let wheel: Double
    let axisWheel: Double

    var body: some View {
        Canvas { ctx, size in
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            let r = min(size.width, size.height) / 2
            let field = Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
            ctx.fill(field, with: .color(Color(red: 0.04, green: 0.1, blue: 0.07)))
            var clipped = ctx
            clipped.clip(to: field)

            let reticle = Color(red: 0.4, green: 0.85, blue: 0.5).opacity(0.35)
            for ring in [0.25, 0.5, 0.75] {
                let rr = r * ring
                clipped.stroke(Path(ellipseIn: CGRect(x: c.x - rr, y: c.y - rr, width: rr * 2, height: rr * 2)), with: .color(reticle), lineWidth: 0.8)
            }
            clipped.stroke(Path { $0.move(to: CGPoint(x: c.x - r, y: c.y)); $0.addLine(to: CGPoint(x: c.x + r, y: c.y)) }, with: .color(reticle), lineWidth: 0.8)
            clipped.stroke(Path { $0.move(to: CGPoint(x: c.x, y: c.y - r)); $0.addLine(to: CGPoint(x: c.x, y: c.y + r)) }, with: .color(reticle), lineWidth: 0.8)

            let mismatch = Double(LensometerTrainerView.axisDifference(Int(axisWheel), lens.axis))
            let misalignBlur = lens.cylinder == 0 ? 0 : mismatch * abs(lens.cylinder) * 0.12
            let sphereBlur = min(14, abs(wheel - lens.sphere) * 4 + misalignBlur)
            let cylinderBlur = min(14, abs(wheel - (lens.sphere + lens.cylinder)) * 4 + misalignBlur)
            let breakOffset = lens.cylinder == 0 ? 0 : sin(mismatch * .pi / 90) * r * 0.08 * min(1, abs(lens.cylinder))

            // Screen angles run clockwise; optical axes run counterclockwise from the 180 line.
            let angle = -axisWheel * .pi / 180
            let along = CGVector(dx: cos(angle), dy: sin(angle))
            let across = CGVector(dx: -along.dy, dy: along.dx)
            let target = Color(red: 0.55, green: 1.0, blue: 0.6)

            func point(_ a: Double, _ b: Double) -> CGPoint {
                CGPoint(x: c.x + along.dx * a + across.dx * b, y: c.y + along.dy * a + across.dy * b)
            }

            clipped.drawLayer { layer in
                layer.addFilter(.blur(radius: sphereBlur))
                for offset in [-0.08, 0, 0.08] {
                    let b = offset * r
                    layer.stroke(Path { $0.move(to: point(-0.85 * r, b - breakOffset)); $0.addLine(to: point(0, b - breakOffset)) }, with: .color(target), lineWidth: 1.6)
                    layer.stroke(Path { $0.move(to: point(0, b + breakOffset)); $0.addLine(to: point(0.85 * r, b + breakOffset)) }, with: .color(target), lineWidth: 1.6)
                }
            }
            clipped.drawLayer { layer in
                layer.addFilter(.blur(radius: cylinderBlur))
                for offset in [-0.12, 0, 0.12] {
                    let a = offset * r
                    layer.stroke(Path { $0.move(to: point(a, -0.6 * r)); $0.addLine(to: point(a, 0.6 * r)) }, with: .color(target), lineWidth: 5)
                }
            }
            ctx.stroke(field, with: .color(.black.opacity(0.6)), lineWidth: 6)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}
