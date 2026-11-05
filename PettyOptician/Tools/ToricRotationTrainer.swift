import SwiftUI

enum ToricMarkDesign: CaseIterable, Sendable {
    case sixOClock, threeSixNine

    var title: String {
        switch self {
        case .sixOClock: "Single scribe mark at 6 o'clock"
        case .threeSixNine: "Marks at 3, 6 and 9 o'clock"
        }
    }
}

/// Direction the lens marks moved, as seen by the fitter facing the patient.
enum ToricRotationDirection: CaseIterable, Identifiable, Sendable {
    case left, right

    var id: Self { self }

    var title: String {
        switch self {
        case .left: "Left (clockwise)"
        case .right: "Right (counterclockwise)"
        }
    }
}

struct ToricAxisChoice: Identifiable, Hashable, Sendable {
    let axis: Int
    let mistake: String?

    var id: Int { axis }
}

struct ToricRotationProblem: Equatable, Sendable {
    var lens: SpheroCylinder
    var rotation: Int
    var direction: ToricRotationDirection
    var design: ToricMarkDesign
    var rightEye: Bool

    var orderedAxis: Int {
        OpticsMath.compensatedToricAxis(lens.axis, rotation: rotation, toLeft: direction == .left)
    }

    static func random<G: RandomNumberGenerator>(using rng: inout G) -> ToricRotationProblem {
        let axis: Int = switch Int.random(in: 0...9, using: &rng) {
        case 0...4: [160, 170, 180, 10, 20].randomElement(using: &rng)!
        case 5...7: Int.random(in: 8...10, using: &rng) * 10
        default: Int.random(in: 3...15, using: &rng) * 10
        }
        let lens = SpheroCylinder(
            sphere: Double(Int.random(in: -24...16, using: &rng)) * 0.25,
            cylinder: -Double(Int.random(in: 3...9, using: &rng)) * 0.25,
            axis: axis
        )
        return ToricRotationProblem(
            lens: lens,
            rotation: Int.random(in: 1...6, using: &rng) * 5,
            direction: ToricRotationDirection.allCases.randomElement(using: &rng)!,
            design: ToricMarkDesign.allCases.randomElement(using: &rng)!,
            rightEye: Bool.random(using: &rng)
        )
    }

    static func random() -> ToricRotationProblem {
        var rng = SystemRandomNumberGenerator()
        return random(using: &rng)
    }

    /// The correct axis plus three classic mistakes, shuffled.
    func choices<G: RandomNumberGenerator>(using rng: inout G) -> [ToricAxisChoice] {
        let toLeft = direction == .left
        let raw = lens.axis + (toLeft ? rotation : -rotation)
        var candidates = [
            ToricAxisChoice(axis: OpticsMath.compensatedToricAxis(lens.axis, rotation: rotation, toLeft: !toLeft), mistake: "LARS applied backwards, which is also what you get by judging the rotation from the patient's side."),
            ToricAxisChoice(axis: lens.axis, mistake: "Ordered the diagnostic lens axis without compensating for the rotation."),
        ]
        if raw > 180 || raw <= 0 {
            candidates.append(ToricAxisChoice(axis: abs(raw), mistake: "Forgot the 180° wrap: axes run 001 to 180, so subtract 180 above 180 and add 180 at 0 or below."))
        }
        candidates.append(ToricAxisChoice(axis: OpticsMath.compensatedToricAxis(lens.axis, rotation: rotation * 2, toLeft: toLeft), mistake: "Compensated twice the rotation."))
        candidates.append(ToricAxisChoice(axis: OpticsMath.compensatedToricAxis(lens.axis, rotation: rotation * 2, toLeft: !toLeft), mistake: "Applied LARS backwards and doubled the rotation."))

        var picked = [ToricAxisChoice(axis: orderedAxis, mistake: nil)]
        for candidate in candidates where picked.count < 4 && !picked.contains(where: { $0.axis == candidate.axis }) {
            picked.append(candidate)
        }
        return picked.shuffled(using: &rng)
    }
}

struct ToricRotationTrainerView: View {
    @State private var problem = ToricRotationProblem.random()
    @State private var choices: [ToricAxisChoice] = []
    @State private var selected: ToricAxisChoice?
    @State private var readAmount = 0
    @State private var readDirection = ToricRotationDirection.left
    @State private var checked = false
    @State private var correctCount = 0
    @State private var attempts = 0
    @State private var showingHelp = false
    @Environment(\.palette) private var palette

    private static let sources = [
        SourceLink(title: "Contact Lens Spectrum: Contact Lens Primer – Toric Soft Contact Lenses", url: URL(string: "https://www.clspectrum.com/issues/2001/may/contact-lens-primer")!),
        SourceLink(title: "Contact Lens Spectrum: Don't Forget to LARS (2025)", url: URL(string: "https://clspectrum.com/issues/2025/november_december/contact-lens-practice-pearls/")!),
        SourceLink(title: "Contact Lens Spectrum: Toric Soft Lenses and the Eyelids", url: URL(string: "https://clspectrum.com/issues/2009/february/prescribing-for-astigmatism/")!),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ToricEyeView(problem: problem, scale: palette.accent)
                    .frame(maxWidth: 420)
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel("Toric soft lens on the \(problem.rightEye ? "right" : "left") eye, seen from the fitter's side, with a protractor scale around the lower lens edge")

                Panel {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("\(problem.rightEye ? "OD" : "OS") diagnostic lens \(rxText(problem.lens))").font(.headline)
                        Text("\(problem.design.title). The lens has settled and the marks hold the same position through blinks. Scale ticks are 5° apart.")
                            .font(.subheadline)
                            .foregroundStyle(palette.secondaryText)
                    }
                }

                Panel {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Read the rotation (your view)").font(.headline)
                        Picker("Direction", selection: $readDirection) {
                            ForEach(ToricRotationDirection.allCases) { Text($0.title).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        .disabled(checked)
                        Stepper(value: $readAmount, in: 0...45, step: 5) {
                            LabeledContent("Amount", value: "\(readAmount)°")
                        }
                        .disabled(checked)
                    }
                }

                Text("Axis to order").font(.headline)
                VStack(spacing: 10) {
                    ForEach(choices) { choice in
                        Button { selected = choice } label: {
                            HStack {
                                Text("\(rxPowers(problem.lens)) × \(axisText(choice.axis))").monospacedDigit()
                                Spacer()
                                if checked {
                                    if choice.axis == problem.orderedAxis {
                                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                                    } else if choice == selected {
                                        Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
                                    }
                                } else if choice == selected {
                                    Image(systemName: "largecircle.fill.circle").foregroundStyle(palette.accent)
                                }
                            }
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(palette.text)
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(palette.cardBackground, in: RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                        .disabled(checked)
                    }
                }

                if checked {
                    resultPanel
                } else {
                    Button("Check", action: check)
                        .buttonStyle(.borderedProminent)
                        .disabled(selected == nil)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .accessibilityIdentifier("toric.check")
                }

                Text("Score \(correctCount) / \(attempts)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(palette.secondaryText)

                DisclosureGroup("How to compensate", isExpanded: $showingHelp) {
                    RichText(text: """
                    - Judge the rotation **from your side**, facing the patient. Find how far the 6 o'clock mark sits from the bottom of the scale. On 3-6-9 designs the 3 and 9 marks turn by the same amount, so any of them can be read.
                    - **LARS**: mark moved to **your left**, add the rotation to the axis; to **your right**, subtract. From your view, left at the bottom is clockwise, so this is the same as **CAAS** (clockwise add, anticlockwise subtract).
                    - It works the same way for either eye. Axes run 001–180: subtract 180 from anything over 180, add 180 to anything at 0 or below, and write 180 rather than 000.
                    - Sphere and cylinder stay the same; only the axis changes, so the ordered lens settles in the same position as the diagnostic lens.
                    - A lens 15° off the refractive axis leaves an over-refraction cylinder about half the correcting cylinder, so even small errors matter at higher cylinder powers.

                    **Compensate or refit?** Let the lens settle, then watch it through blinks and in different gaze directions. Compensate only when the rotation is stable; stability matters more than the amount. Aim for under 10° of movement on a blink. If the position varies, the lens design is the problem, not the axis: change the base curve or the lens brand instead of compensating.
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
        .navigationTitle("Toric Rotation")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { if choices.isEmpty { load(problem) } }
    }

    private var resultPanel: some View {
        let readingRight = readAmount == problem.rotation && readDirection == problem.direction
        let axisRight = selected?.axis == problem.orderedAxis
        let sign = problem.direction == .left ? "+" : "−"
        return Panel {
            VStack(alignment: .leading, spacing: 10) {
                Label(
                    readingRight ? "Rotation read correctly" : "The lens is rotated \(problem.rotation)° \(problem.direction.title.lowercased())",
                    systemImage: readingRight ? "checkmark.seal.fill" : "xmark.octagon.fill"
                )
                .foregroundStyle(readingRight ? .green : .red)
                Label(
                    axisRight ? "Correct axis" : "Order axis \(axisText(problem.orderedAxis))",
                    systemImage: axisRight ? "checkmark.seal.fill" : "xmark.octagon.fill"
                )
                .foregroundStyle(axisRight ? .green : .red)
                if let mistake = selected?.mistake {
                    Text(mistake).font(.caption).foregroundStyle(palette.secondaryText)
                }
                Text("\(problem.direction == .left ? "Left add" : "Right subtract"): \(axisText(problem.lens.axis)) \(sign) \(problem.rotation) = \(axisText(problem.orderedAxis)). Order \(rxText(SpheroCylinder(sphere: problem.lens.sphere, cylinder: problem.lens.cylinder, axis: problem.orderedAxis))).")
                    .font(.caption)
                    .foregroundStyle(palette.secondaryText)
                Button("Next Lens", action: next).buttonStyle(.borderedProminent)
            }
            .font(.subheadline.weight(.semibold))
        }
    }

    private func check() {
        checked = true
        attempts += 1
        if readAmount == problem.rotation, readDirection == problem.direction, selected?.axis == problem.orderedAxis {
            correctCount += 1
        }
    }

    private func next() {
        load(.random())
    }

    private func load(_ newProblem: ToricRotationProblem) {
        var rng = SystemRandomNumberGenerator()
        problem = newProblem
        choices = newProblem.choices(using: &rng)
        selected = nil
        checked = false
        readAmount = 0
    }

    private func axisText(_ axis: Int) -> String { String(format: "%03d", axis) }
    private func rxPowers(_ rx: SpheroCylinder) -> String { "\(OpticsMath.formatPower(rx.sphere)) \(OpticsMath.formatPower(rx.cylinder))" }
    private func rxText(_ rx: SpheroCylinder) -> String { "\(rxPowers(rx)) × \(axisText(rx.axis))" }
}

private struct ToricEyeView: View {
    let problem: ToricRotationProblem
    let scale: Color

    var body: some View {
        Canvas { ctx, size in
            let c = CGPoint(x: size.width / 2, y: size.height * 0.46)
            let lensR = min(size.width / 5.2, size.height / 3.3)
            let irisR = lensR * 0.82
            let skin = Color(red: 0.86, green: 0.68, blue: 0.56)

            ctx.fill(Path(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 16), with: .color(skin))

            let leftCorner = CGPoint(x: c.x - lensR * 2.1, y: c.y)
            let rightCorner = CGPoint(x: c.x + lensR * 2.1, y: c.y)
            var opening = Path()
            opening.move(to: leftCorner)
            opening.addQuadCurve(to: rightCorner, control: CGPoint(x: c.x, y: c.y - lensR * 2.1))
            opening.addQuadCurve(to: leftCorner, control: CGPoint(x: c.x, y: c.y + lensR * 2.6))
            ctx.fill(opening, with: .color(Color(red: 0.96, green: 0.94, blue: 0.91)))

            var eye = ctx
            eye.clip(to: opening)

            // The patient's nose is on the fitter's right for OD and left for OS.
            let nasalX = problem.rightEye ? rightCorner.x - lensR * 0.3 : leftCorner.x + lensR * 0.3
            eye.fill(Path(ellipseIn: CGRect(x: nasalX - lensR * 0.22, y: c.y - lensR * 0.16, width: lensR * 0.44, height: lensR * 0.32)), with: .color(Color(red: 0.88, green: 0.55, blue: 0.55)))

            let iris = Path(ellipseIn: CGRect(x: c.x - irisR, y: c.y - irisR, width: irisR * 2, height: irisR * 2))
            eye.fill(iris, with: .radialGradient(
                Gradient(colors: [Color(red: 0.42, green: 0.3, blue: 0.16), Color(red: 0.28, green: 0.42, blue: 0.4), Color(red: 0.16, green: 0.22, blue: 0.22)]),
                center: c, startRadius: irisR * 0.3, endRadius: irisR
            ))
            eye.stroke(iris, with: .color(.black.opacity(0.45)), lineWidth: 2)
            let pupilR = irisR * 0.36
            eye.fill(Path(ellipseIn: CGRect(x: c.x - pupilR, y: c.y - pupilR, width: pupilR * 2, height: pupilR * 2)), with: .color(.black))
            eye.fill(Path(ellipseIn: CGRect(x: c.x + pupilR * 0.3, y: c.y - pupilR * 0.9, width: pupilR * 0.45, height: pupilR * 0.45)), with: .color(.white.opacity(0.85)))

            let lens = Path(ellipseIn: CGRect(x: c.x - lensR, y: c.y - lensR, width: lensR * 2, height: lensR * 2))
            eye.fill(lens, with: .color(.white.opacity(0.07)))
            eye.stroke(lens, with: .color(Color(red: 0.55, green: 0.62, blue: 0.66).opacity(0.9)), lineWidth: 1.3)

            func point(_ degrees: Double, _ radius: Double) -> CGPoint {
                let a = degrees * .pi / 180
                return CGPoint(x: c.x + cos(a) * radius, y: c.y + sin(a) * radius)
            }

            // Screen angles grow clockwise; 90° is 6 o'clock, so clockwise (fitter's left) rotation adds.
            let offset = Double(problem.direction == .left ? problem.rotation : -problem.rotation)
            let markAngles: [Double] = switch problem.design {
            case .sixOClock: [90]
            case .threeSixNine: [0, 90, 180]
            }
            for base in markAngles {
                let angle = base + offset
                eye.stroke(Path { $0.move(to: point(angle, lensR * 0.8)); $0.addLine(to: point(angle, lensR * 0.95)) }, with: .color(.black.opacity(0.75)), lineWidth: 2.2)
            }

            ctx.stroke(opening, with: .color(Color(red: 0.45, green: 0.3, blue: 0.24)), lineWidth: 3)

            var dash = Path()
            dash.move(to: c)
            dash.addLine(to: point(90, lensR * 1.02))
            ctx.stroke(dash, with: .color(scale.opacity(0.7)), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
            for degrees in stride(from: -45, through: 45, by: 5) {
                let major = degrees % 10 == 0
                let angle = 90 + Double(degrees)
                ctx.stroke(
                    Path { $0.move(to: point(angle, lensR * 1.03)); $0.addLine(to: point(angle, lensR * (degrees == 0 ? 1.18 : major ? 1.13 : 1.08))) },
                    with: .color(scale),
                    lineWidth: major ? 1.6 : 1
                )
                if major {
                    ctx.draw(
                        Text("\(abs(degrees))").font(.system(size: 10, weight: .semibold)).foregroundStyle(scale),
                        at: point(angle, lensR * 1.26)
                    )
                }
            }

            let caption = Color(red: 0.35, green: 0.22, blue: 0.18)
            ctx.draw(Text(problem.rightEye ? "Temporal" : "Nasal").font(.caption2.weight(.semibold)).foregroundStyle(caption), at: CGPoint(x: lensR * 0.55, y: size.height - 12), anchor: .leading)
            ctx.draw(Text(problem.rightEye ? "Nasal" : "Temporal").font(.caption2.weight(.semibold)).foregroundStyle(caption), at: CGPoint(x: size.width - lensR * 0.55, y: size.height - 12), anchor: .trailing)
            ctx.draw(Text("\(problem.rightEye ? "OD" : "OS") · fitter's view").font(.caption.weight(.bold)).foregroundStyle(caption), at: CGPoint(x: size.width / 2, y: 14))
        }
        .aspectRatio(1.4, contentMode: .fit)
    }
}
