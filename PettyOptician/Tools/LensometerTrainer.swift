import SwiftUI

/// Horizontal and vertical prism read separately, as they're recorded on an Rx; a zero component's base is ignored.
struct PrismReading: Equatable, Sendable {
    var horizontal = 0.0
    var horizontalBase = PrismTrainerBase.baseIn
    var vertical = 0.0
    var verticalBase = PrismTrainerBase.baseUp

    func matches(_ other: PrismReading) -> Bool {
        func same(_ a: Double, _ aBase: PrismTrainerBase, _ b: Double, _ bBase: PrismTrainerBase) -> Bool {
            abs(a - b) < 0.01 && (a < 0.01 || aBase == bBase)
        }
        return same(horizontal, horizontalBase, other.horizontal, other.horizontalBase)
            && same(vertical, verticalBase, other.vertical, other.verticalBase)
    }

    var label: String {
        let parts = [(horizontal, horizontalBase), (vertical, verticalBase)]
            .filter { $0.0 > 0 }
            .map { String(format: "%.2fΔ %@", $0.0, $0.1.rawValue) }
        return parts.isEmpty ? "No prism" : parts.joined(separator: " and ")
    }
}

struct LensometerPrism: Equatable, Sendable {
    let reading: PrismReading
    let eye: PrismTrainerEye

    /// In prism diopters on the reticle: x right, y down. Glasses sit temples-away, so OD is on the optician's left
    /// and nasal is to the right for OD, left for OS. The target moves toward the base.
    var displacement: CGVector {
        let nasal: Double = eye == .od ? 1 : -1
        let dx = reading.horizontal * (reading.horizontalBase == .baseIn ? nasal : -nasal)
        let dy = reading.vertical * (reading.verticalBase == .baseUp ? -1 : 1)
        return CGVector(dx: dx, dy: dy)
    }
}

struct LensometerTrainerView: View {
    @State private var lens = Self.randomLens()
    @State private var includesPrism = false
    @State private var prism: LensometerPrism?
    @State private var answerPrism = PrismReading()
    @State private var wheel = 0.0
    @State private var axisWheel = 90.0
    @State private var answerSphere = 0.0
    @State private var answerCylinder = 0.0
    @State private var answerAxis = 90.0
    @State private var result: Grade?
    @State private var correctCount = 0
    @State private var attempts = 0
    @State private var showingHelp = false
    @Environment(\.palette) private var palette

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Panel {
                    VStack(alignment: .leading, spacing: 6) {
                        Toggle("Prism", isOn: $includesPrism)
                            .font(.headline)
                            .accessibilityIdentifier("lensometer.prism.toggle")
                        Text(includesPrism ? "On: read power and axis, then horizontal and vertical prism." : "Off: practice sphere, cylinder and axis only.")
                            .font(.caption)
                            .foregroundStyle(palette.secondaryText)
                        Text("Changing mode starts a new lens.")
                            .font(.caption)
                            .foregroundStyle(palette.secondaryText)
                    }
                }

                if let prism {
                    Text(prism.eye == .od ? "OD · Right lens · nasal is →" : "OS · Left lens · nasal is ←")
                        .font(.subheadline.weight(.semibold))
                        .accessibilityIdentifier("lensometer.prism.eye")
                }

                LensometerTarget(lens: lens, prism: prism, wheel: wheel, axisWheel: axisWheel)
                    .frame(maxWidth: 360)
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel("Lensometer target")

                if includesPrism {
                    Text("The first ring is ½Δ, then each ring is 1Δ. Read where the lines cross, using the scale ticks for horizontal and vertical. The target shifts toward the base.")
                        .font(.caption)
                        .foregroundStyle(palette.secondaryText)
                }

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
                        if includesPrism {
                            prismRow("Horizontal", amount: $answerPrism.horizontal, base: $answerPrism.horizontalBase, options: [.baseIn, .baseOut], id: "horizontal")
                            prismRow("Vertical", amount: $answerPrism.vertical, base: $answerPrism.verticalBase, options: [.baseUp, .baseDown], id: "vertical")
                        }
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
                                .disabled(result != nil)
                        }
                        if let result {
                            gradeLine(result.power, "Power: \(rxText(lens))")
                            Text("Plus-cylinder form: \(rxText(OpticsMath.transpose(lens)))")
                                .font(.caption)
                                .foregroundStyle(palette.secondaryText)
                            if let prism {
                                gradeLine(result.prism, "Prism: \(prism.reading.label) (\(prism.eye.rawValue))")
                                    .accessibilityIdentifier("lensometer.prism.result")
                            }
                            Button("Next Lens", action: nextLens)
                                .buttonStyle(.borderedProminent)
                                .accessibilityIdentifier("lensometer.next")
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
                    - Turn **Prism** on to add prism at the reading point: horizontal, vertical, or both, 0.50–3.00Δ each. Focus the lines, then find where they cross. The first reticle ring is **½Δ** and each ring after it is **1Δ**.
                    - The target moves toward the **base**: up = Base Up, down = Base Down. Glasses sit with the temples away from you, so nasal is to the right for **OD** and to the left for **OS**. A nasal shift is Base In; a temporal shift is Base Out.
                    - When the target sits off both crosshair lines, the lens has prism in two directions. Read the horizontal and vertical parts separately on the tick scales and record both, e.g. 2.00Δ BI and 1.00Δ BU.
                    - With Prism off, the target is centered and only sphere, cylinder and axis are checked. Changing mode starts a new lens without changing your score.

                    This is a simplified simulation. Real instruments differ (crossed-line or corona targets), and the eyepiece must be focused first.
                    """)
                    .font(.subheadline)
                    .padding(.top, 8)
                    SourceList(sources: [
                        SourceLink(
                            title: "University of Iowa: Manual Lensometry",
                            url: URL(string: "https://webeye.ophth.uiowa.edu/eyeforum/video/Refraction/pdfs/PlusCylManualLensometry.pdf")!
                        ),
                        SourceLink(
                            title: "Moran CORE (University of Utah): Manual Lensometry",
                            url: URL(string: "https://morancore.utah.edu/wp-content/uploads/2025/11/Lensometry.pdf")!
                        ),
                        SourceLink(title: "20/20 Magazine: Prism Made Easy", url: URL(string: "https://www.2020mag.com/article/prism-made-easy")!)
                    ])
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 8)
                }
                .tint(palette.accent)
            }
            .padding()
        }
        .pettyScreen()
        .navigationTitle("Lensometer Trainer")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: includesPrism) { nextLens() }
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

    struct Grade: Equatable, Sendable {
        let power: Bool
        let prism: Bool
        var isCorrect: Bool { power && prism }
    }

    private func prismRow(_ title: String, amount: Binding<Double>, base: Binding<PrismTrainerBase>, options: [PrismTrainerBase], id: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Stepper(value: amount, in: 0...5, step: 0.5) {
                LabeledContent(title, value: String(format: "%.2fΔ", amount.wrappedValue))
            }
            .accessibilityIdentifier("lensometer.prism.\(id)")
            Picker("\(title) base", selection: base) {
                ForEach(options, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .disabled(amount.wrappedValue == 0)
        }
    }

    private func gradeLine(_ correct: Bool, _ text: String) -> some View {
        Label(text, systemImage: correct ? "checkmark.circle.fill" : "xmark.circle.fill")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(correct ? .green : .red)
    }

    private func check() {
        guard result == nil else { return }
        attempts += 1
        let entered = SpheroCylinder(sphere: answerSphere, cylinder: answerCylinder, axis: Int(answerAxis))
        let grade = Self.grade(entered, lens, reading: answerPrism, prism: prism)
        result = grade
        if grade.isCorrect { correctCount += 1 }
    }

    private func nextLens() {
        lens = Self.randomLens()
        prism = Self.randomPrism(enabled: includesPrism)
        answerPrism = PrismReading()
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

    /// Horizontal only, vertical only, or both, 0.50–3.00Δ per component.
    nonisolated static func randomPrism(enabled: Bool) -> LensometerPrism? {
        guard enabled else { return nil }
        func amount() -> Double { Double(Int.random(in: 1...6)) * 0.5 }
        let kind = Int.random(in: 0..<10)
        var reading = PrismReading()
        if kind < 7 {
            reading.horizontal = amount()
            reading.horizontalBase = Bool.random() ? .baseIn : .baseOut
        }
        if kind >= 4 {
            reading.vertical = amount()
            reading.verticalBase = Bool.random() ? .baseUp : .baseDown
        }
        return LensometerPrism(reading: reading, eye: PrismTrainerEye.allCases.randomElement()!)
    }

    nonisolated static func grade(_ entered: SpheroCylinder, _ lens: SpheroCylinder, reading: PrismReading, prism: LensometerPrism?) -> Grade {
        Grade(power: matches(entered, lens), prism: prism.map { reading.matches($0.reading) } ?? true)
    }

    // Accepts either cylinder form; axis within ±3°, ignored for spheres.
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
    /// Fraction of the field radius per prism diopter, so the 5Δ ring sits just inside the edge.
    static let ringSpacing = 0.18

    let lens: SpheroCylinder
    let prism: LensometerPrism?
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
            let perDiopter = r * LensometerTarget.ringSpacing
            for ring in [0.5, 1, 2, 3, 4, 5] {
                let rr = perDiopter * ring
                clipped.stroke(Path(ellipseIn: CGRect(x: c.x - rr, y: c.y - rr, width: rr * 2, height: rr * 2)), with: .color(reticle), lineWidth: ring < 1 ? 0.6 : 0.8)
                if prism != nil, ring >= 1 {
                    clipped.draw(Text("\(Int(ring))").font(.caption2).foregroundStyle(.white.opacity(0.7)), at: CGPoint(x: c.x + rr * 0.707 + 5, y: c.y - rr * 0.707 - 5))
                }
            }
            clipped.stroke(Path { $0.move(to: CGPoint(x: c.x - r, y: c.y)); $0.addLine(to: CGPoint(x: c.x + r, y: c.y)) }, with: .color(reticle), lineWidth: 0.8)
            clipped.stroke(Path { $0.move(to: CGPoint(x: c.x, y: c.y - r)); $0.addLine(to: CGPoint(x: c.x, y: c.y + r)) }, with: .color(reticle), lineWidth: 0.8)
            if prism != nil {
                // Half-diopter ticks on both crosshair lines for reading each component of an oblique shift.
                for step in 1...10 {
                    let d = perDiopter * Double(step) / 2
                    let half = step.isMultiple(of: 2) ? 5.0 : 3.0
                    for sign in [-1.0, 1.0] {
                        clipped.stroke(Path { $0.move(to: CGPoint(x: c.x + sign * d, y: c.y - half)); $0.addLine(to: CGPoint(x: c.x + sign * d, y: c.y + half)) }, with: .color(reticle), lineWidth: 1)
                        clipped.stroke(Path { $0.move(to: CGPoint(x: c.x - half, y: c.y + sign * d)); $0.addLine(to: CGPoint(x: c.x + half, y: c.y + sign * d)) }, with: .color(reticle), lineWidth: 1)
                    }
                }
            }

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

            let shift = prism?.displacement ?? .zero
            let targetCenter = CGPoint(x: c.x + shift.dx * perDiopter, y: c.y + shift.dy * perDiopter)
            func point(_ a: Double, _ b: Double) -> CGPoint {
                CGPoint(x: targetCenter.x + along.dx * a + across.dx * b, y: targetCenter.y + along.dy * a + across.dy * b)
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
