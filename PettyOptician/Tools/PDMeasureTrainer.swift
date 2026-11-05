import SwiftUI

enum PDMeasureTask: String, CaseIterable, Identifiable, Sendable {
    case binocularPD, monocularPD, bifocalSegHeight, progressiveFittingHeight, nearPD

    var id: String { rawValue }

    var title: String {
        switch self {
        case .binocularPD: "Binocular PD"
        case .monocularPD: "Monocular PDs"
        case .bifocalSegHeight: "Bifocal seg height"
        case .progressiveFittingHeight: "Progressive fitting height"
        case .nearPD: "Near PD"
        }
    }

    var usesMarkers: Bool { self != .nearPD }
    var measuresHeight: Bool { self == .bifocalSegHeight || self == .progressiveFittingHeight }
}

/// Drawing space is millimeters: x from the frame's bridge center toward the optician's right, y up from the deepest point of the lens.
struct PDMeasurePatient: Equatable, Sendable {
    var rightPD: Double
    var leftPD: Double
    var rightPupilHeight: Double
    var leftPupilHeight: Double
    var irisRadius: Double
    var eyeSize: Double
    var lensHeight: Double
    var bridge: Double
    var workingDistanceMM: Double

    var binocularPD: Double { rightPD + leftPD }
    var nearPD: Double { OpticsMath.nearPD(distancePD: binocularPD, workingDistanceMM: workingDistanceMM) }
    var rightSegHeight: Double { rightPupilHeight - irisRadius }
    var leftSegHeight: Double { leftPupilHeight - irisRadius }
    var lensCenterOffset: Double { bridge / 2 + eyeSize / 2 }

    /// Facing the patient, the right eye (OD) is on the optician's left.
    var rightPupil: CGPoint { CGPoint(x: -rightPD, y: rightPupilHeight) }
    var leftPupil: CGPoint { CGPoint(x: leftPD, y: leftPupilHeight) }
}

struct PDMeasureTarget: Equatable, Sendable {
    let label: String
    let value: Double
    let tolerance: Double
}

struct PDMeasureRound: Equatable, Sendable {
    var patient: PDMeasurePatient
    var task: PDMeasureTask
    var markers: [CGPoint]
    var answers: [Double]
}

/// Maps the millimeter drawing space onto the canvas; the rule reads to the nearest 0.5 mm.
struct PDMeasureScale: Equatable, Sendable {
    static let bounds = CGRect(x: -78, y: -22, width: 156, height: 76)

    var size: CGSize

    var pointsPerMM: CGFloat { size.width / Self.bounds.width }

    func point(_ mm: CGPoint) -> CGPoint {
        CGPoint(x: (mm.x - Self.bounds.minX) * pointsPerMM, y: (Self.bounds.maxY - mm.y) * pointsPerMM)
    }

    func mm(_ point: CGPoint) -> CGPoint {
        CGPoint(x: point.x / pointsPerMM + Self.bounds.minX, y: Self.bounds.maxY - point.y / pointsPerMM)
    }

    func rect(x: Double, y: Double, width: Double, height: Double) -> CGRect {
        let origin = point(CGPoint(x: x, y: y + height))
        return CGRect(x: origin.x, y: origin.y, width: width * pointsPerMM, height: height * pointsPerMM)
    }

    static func clamped(_ mm: CGPoint) -> CGPoint {
        let inner = bounds.insetBy(dx: 2, dy: 2)
        return CGPoint(x: min(inner.maxX, max(inner.minX, mm.x)), y: min(inner.maxY, max(inner.minY, mm.y)))
    }

    static func reading(_ mm: Double) -> Double { (mm * 2).rounded() / 2 }
}

struct PDMeasureTrainerView: View {
    @State private var focus: PDMeasureTask?
    @State private var round = Self.newRound(task: PDMeasureTask.allCases.randomElement()!)
    @State private var result: Bool?
    @State private var correctCount = 0
    @State private var attempts = 0
    @State private var showingHelp = false
    @Environment(\.palette) private var palette

    private static let sources = [
        SourceLink(title: "Community Eye Health Journal: Pupillary distance and the optical centre", url: URL(string: "https://pmc.ncbi.nlm.nih.gov/articles/PMC11141121/")!),
        SourceLink(title: "ABDO: The Fitting of Spectacle Lenses (M. Jalie)", url: URL(string: "https://www.abdo.org.uk/wp-content/uploads/2019/12/Mo-Jalie-Article-on-FIT.pdf")!),
        SourceLink(title: "Essilor: Varilux Fitting & Dispensing Guide", url: URL(string: "https://essilorpro.com/content/dam/essilor-pro/product-resources/varilux/LVAR201326_Varilux_Fitting_N_Dispensing_Guide_LR.pdf")!),
    ]

    private var targets: [PDMeasureTarget] { Self.targets(for: round.task, patient: round.patient) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text(round.task.title).font(.headline)
                    Spacer()
                    Picker("Task", selection: $focus) {
                        Text("Mixed").tag(PDMeasureTask?.none)
                        ForEach(PDMeasureTask.allCases) { task in
                            Text(task.title).tag(Optional(task))
                        }
                    }
                    .pickerStyle(.menu)
                }

                Text(instruction)
                    .font(.subheadline)
                    .foregroundStyle(palette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                PDMeasureScene(
                    patient: round.patient,
                    task: round.task,
                    markers: $round.markers,
                    revealed: result == nil ? [] : Self.revealPoints(for: round.task, patient: round.patient),
                    locked: result != nil
                )
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
                .accessibilityLabel("Front view of a patient wearing a frame, with a millimeter rule")

                Text("You face the patient, so OD (right eye) is on your left. Drag anywhere near a marker to move it.")
                    .font(.caption)
                    .foregroundStyle(palette.secondaryText)

                Panel {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Record the measurement").font(.headline)
                        ForEach(Array(targets.enumerated()), id: \.offset) { index, target in
                            Stepper(value: $round.answers[index], in: Self.answerRange(for: round.task), step: 0.5) {
                                LabeledContent(target.label, value: mmText(round.answers[index]))
                            }
                            .disabled(result != nil)
                        }
                        HStack {
                            Spacer()
                            Button("Check", action: check)
                                .buttonStyle(.borderedProminent)
                                .disabled(result != nil)
                                .accessibilityIdentifier("pdmeasure.check")
                        }
                        if let result {
                            Label(result ? "Within tolerance" : "Outside tolerance", systemImage: result ? "checkmark.seal.fill" : "xmark.octagon.fill")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(result ? .green : .red)
                            ForEach(Array(targets.enumerated()), id: \.offset) { index, target in
                                resultRow(target, entered: round.answers[index])
                            }
                            Text(explanation)
                                .font(.caption)
                                .foregroundStyle(palette.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                            Button("Next Patient", action: next).buttonStyle(.borderedProminent)
                        }
                    }
                }

                Text("Score \(correctCount) / \(attempts)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(palette.secondaryText)

                DisclosureGroup("How to measure", isExpanded: $showingHelp) {
                    RichText(text: """
                    - Sit directly in front of the patient, about arm's length away, with your eyes level with theirs. Rest the rule on the bridge of the nose so the scale sits in the spectacle plane; a tilted head or a rule viewed from above, below or off to the side reads wrong (parallax).
                    - **Binocular PD:** close your right eye and have the patient look into your open left eye. Set 0 on the center of the right pupil. Keep the rule still, close your left eye, have the patient look into your open right eye, and read the center of the left pupil. Each eye then looks straight ahead, as for distance.
                    - If the pupil is hard to see in a dark iris, measure from the temporal edge of the right iris to the nasal edge of the left iris. A light beside your open eye gives a corneal reflex that is easy to center.
                    - **Monocular PDs** run from each pupil center to the center of the nose (the frame bridge). Use them for progressives, bifocals, high powers and asymmetric faces.
                    - **Bifocal seg height:** with the frame adjusted and worn where the patient wears it, mark the lower edge of the iris, which usually lines up with the lower lid margin, and measure up from the lowest point of the lens.
                    - **Progressive fitting height:** mark the pupil center and measure up from the deepest point of the lens, not the outside of the frame. In a zyl frame, measure to the lowest point of the bevel.
                    - **Near PD** = distance PD × l ÷ (l + 27), where l is the working distance from the spectacle plane and 27 mm is the spectacle plane to the eye's center of rotation.
                    - Take the measurement twice; if the patient moves or loses fixation on your open eye, the readings will not agree.

                    Tolerances here: measurements score within **±1 mm**, the near PD calculation within **±0.5 mm**. The drawing is to scale and the rule reads to the nearest 0.5 mm. In this drawing the lower lid margin sits exactly at the lower edge of the iris.
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
        .navigationTitle("PD & Seg Height")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: round.markers) { _, markers in
            round.answers = Self.answers(from: markers, task: round.task, patient: round.patient)
        }
        .onChange(of: focus) { next() }
    }

    private var instruction: String {
        switch round.task {
        case .binocularPD:
            "Drag the R and L markers onto the center of each pupil (the corneal reflex). The rule reads the distance between them."
        case .monocularPD:
            "Drag each marker onto the pupil center. Each monocular PD reads from 0 at the center of the bridge."
        case .bifocalSegHeight:
            "Flat-top bifocal: drag each marker to the lower lid margin. The side rules read up from 0 at the deepest point of the lens."
        case .progressiveFittingHeight:
            "Progressive: drag each marker to the pupil center. The side rules read up from 0 at the deepest point of the lens."
        case .nearPD:
            "Distance PD is \(mmText(round.patient.binocularPD)). The working distance is \(Int(round.patient.workingDistanceMM / 10)) cm from the spectacle plane. Calculate the near PD."
        }
    }

    private var explanation: String {
        let p = round.patient
        return switch round.task {
        case .binocularPD:
            "OD \(mmText(p.rightPD)) + OS \(mmText(p.leftPD)) = \(mmText(p.binocularPD)). The frame PD (A + DBL) is \(mmText(p.eyeSize + p.bridge)), so the optical centers are decentered \(mmText(abs(p.eyeSize + p.bridge - p.binocularPD))) \(p.eyeSize + p.bridge >= p.binocularPD ? "in" : "out") in total from the box centers."
        case .monocularPD:
            p.rightPD == p.leftPD
                ? "This face is symmetric: both eyes sit \(mmText(p.rightPD)) from the bridge center."
                : "This face is asymmetric by \(mmText(abs(p.rightPD - p.leftPD))); a binocular PD split in half would misplace both optical centers."
        case .bifocalSegHeight:
            "The segment top goes at the lower lid margin, \(mmText(p.irisRadius)) below the pupil center here. Measured from the lowest point of the lens, not the frame."
        case .progressiveFittingHeight:
            "The fitting cross goes at the pupil center. Confirm the design's minimum fitting height before ordering."
        case .nearPD:
            "Near PD = \(mmText(p.binocularPD)) × \(Int(p.workingDistanceMM)) ÷ (\(Int(p.workingDistanceMM)) + 27) = \(String(format: "%.2f", p.nearPD)) mm."
        }
    }

    private func resultRow(_ target: PDMeasureTarget, entered: Double) -> some View {
        let ok = Self.isWithin(entered, of: target.value, tolerance: target.tolerance)
        return HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: ok ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(ok ? .green : .red)
            VStack(alignment: .leading, spacing: 2) {
                Text(target.label).font(.subheadline.weight(.semibold))
                Text("You \(mmText(entered)) · actual \(mmText(target.value)) · error \(String(format: "%+.1f", entered - target.value)) mm")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(palette.secondaryText)
            }
        }
    }

    private func check() {
        attempts += 1
        result = Self.isCorrect(round.answers, targets: targets)
        if result == true { correctCount += 1 }
    }

    private func next() {
        round = Self.newRound(task: focus ?? PDMeasureTask.allCases.randomElement()!)
        result = nil
    }

    private func mmText(_ value: Double) -> String { String(format: "%.1f mm", value) }

    nonisolated static func answerRange(for task: PDMeasureTask) -> ClosedRange<Double> {
        switch task {
        case .binocularPD: 20...90
        case .monocularPD: 5...45
        case .bifocalSegHeight, .progressiveFittingHeight: 0...45
        case .nearPD: 40...80
        }
    }

    nonisolated static func randomPatient() -> PDMeasurePatient {
        let eyeSize = Double(Int.random(in: 48...56))
        let lensHeight = Double(Int.random(in: 30...min(40, Int(eyeSize) - 12)))
        let rightPD = Double(Int.random(in: 56...72)) / 2
        let asymmetry = [0, 0, 0, 0, 0.5, -0.5, 1, -1, 1.5, -1.5, 2, -2].randomElement()!
        let rightHeight = lensHeight / 2 + Double(Int.random(in: 0...10)) / 2
        return PDMeasurePatient(
            rightPD: rightPD,
            leftPD: rightPD + asymmetry,
            rightPupilHeight: rightHeight,
            leftPupilHeight: rightHeight + [0, 0, 0, 0.5, -0.5, 1, -1].randomElement()!,
            irisRadius: [5.5, 6].randomElement()!,
            eyeSize: eyeSize,
            lensHeight: lensHeight,
            bridge: Double(Int.random(in: 15...21)),
            workingDistanceMM: [250, 330, 350, 400].randomElement()!
        )
    }

    nonisolated static func newRound(task: PDMeasureTask) -> PDMeasureRound {
        let patient = randomPatient()
        let markers = task.usesMarkers ? startMarkers(for: patient) : []
        return PDMeasureRound(patient: patient, task: task, markers: markers, answers: answers(from: markers, task: task, patient: patient))
    }

    /// Starts near the nasal edge of each lens, well away from every target.
    nonisolated static func startMarkers(for patient: PDMeasurePatient) -> [CGPoint] {
        let x = patient.bridge / 2 + 4
        let y = patient.lensHeight * 0.15
        return [CGPoint(x: -x, y: y), CGPoint(x: x, y: y)]
    }

    nonisolated static func targets(for task: PDMeasureTask, patient p: PDMeasurePatient) -> [PDMeasureTarget] {
        let tolerance = 1.0
        return switch task {
        case .binocularPD: [PDMeasureTarget(label: "Binocular PD", value: p.binocularPD, tolerance: tolerance)]
        case .monocularPD: [
            PDMeasureTarget(label: "OD monocular PD", value: p.rightPD, tolerance: tolerance),
            PDMeasureTarget(label: "OS monocular PD", value: p.leftPD, tolerance: tolerance),
        ]
        case .bifocalSegHeight: [
            PDMeasureTarget(label: "OD seg height", value: p.rightSegHeight, tolerance: tolerance),
            PDMeasureTarget(label: "OS seg height", value: p.leftSegHeight, tolerance: tolerance),
        ]
        case .progressiveFittingHeight: [
            PDMeasureTarget(label: "OD fitting height", value: p.rightPupilHeight, tolerance: tolerance),
            PDMeasureTarget(label: "OS fitting height", value: p.leftPupilHeight, tolerance: tolerance),
        ]
        case .nearPD: [PDMeasureTarget(label: "Near PD", value: p.nearPD, tolerance: 0.5)]
        }
    }

    nonisolated static func revealPoints(for task: PDMeasureTask, patient p: PDMeasurePatient) -> [CGPoint] {
        switch task {
        case .binocularPD, .monocularPD, .progressiveFittingHeight: [p.rightPupil, p.leftPupil]
        case .bifocalSegHeight: [CGPoint(x: -p.rightPD, y: p.rightSegHeight), CGPoint(x: p.leftPD, y: p.leftSegHeight)]
        case .nearPD: []
        }
    }

    /// Marker 0 is OD; PDs read off the center-zero rule, heights off the side rules.
    nonisolated static func answers(from markers: [CGPoint], task: PDMeasureTask, patient: PDMeasurePatient) -> [Double] {
        switch task {
        case .binocularPD: [PDMeasureScale.reading(abs(markers[1].x - markers[0].x))]
        case .monocularPD: [PDMeasureScale.reading(abs(markers[0].x)), PDMeasureScale.reading(abs(markers[1].x))]
        case .bifocalSegHeight, .progressiveFittingHeight: [PDMeasureScale.reading(markers[0].y), PDMeasureScale.reading(markers[1].y)]
        case .nearPD: [PDMeasureScale.reading(patient.binocularPD)]
        }
    }

    nonisolated static func isWithin(_ value: Double, of target: Double, tolerance: Double) -> Bool {
        abs(value - target) <= tolerance + 1e-9
    }

    nonisolated static func isCorrect(_ answers: [Double], targets: [PDMeasureTarget]) -> Bool {
        answers.count == targets.count && zip(answers, targets).allSatisfy { isWithin($0, of: $1.value, tolerance: $1.tolerance) }
    }
}

private struct PDMeasureScene: View {
    let patient: PDMeasurePatient
    let task: PDMeasureTask
    @Binding var markers: [CGPoint]
    let revealed: [CGPoint]
    let locked: Bool
    @State private var drag: (index: Int, origin: CGPoint)?
    @Environment(\.palette) private var palette

    var body: some View {
        GeometryReader { geo in
            let scale = PDMeasureScale(size: geo.size)
            Canvas { ctx, _ in draw(&ctx, scale) }
                .contentShape(Rectangle())
                .gesture(dragGesture(scale))
        }
        .aspectRatio(PDMeasureScale.bounds.width / PDMeasureScale.bounds.height, contentMode: .fit)
        .background(palette.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(palette.separator, lineWidth: 0.5))
    }

    private func dragGesture(_ scale: PDMeasureScale) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard !locked, !markers.isEmpty else { return }
                if drag == nil {
                    let start = scale.mm(value.startLocation)
                    let index = markers.indices.min { hypot(markers[$0].x - start.x, markers[$0].y - start.y) < hypot(markers[$1].x - start.x, markers[$1].y - start.y) }!
                    drag = (index, markers[index])
                }
                guard let drag else { return }
                let moved = CGPoint(
                    x: drag.origin.x + value.translation.width / scale.pointsPerMM,
                    y: drag.origin.y - value.translation.height / scale.pointsPerMM
                )
                markers[drag.index] = PDMeasureScale.clamped(moved)
            }
            .onEnded { _ in drag = nil }
    }

    private func draw(_ ctx: inout GraphicsContext, _ s: PDMeasureScale) {
        let ppm = s.pointsPerMM
        let ink = palette.text
        func p(_ x: Double, _ y: Double) -> CGPoint { s.point(CGPoint(x: x, y: y)) }
        func segment(_ a: CGPoint, _ b: CGPoint) -> Path { Path { $0.move(to: a); $0.addLine(to: b) } }
        func label(_ text: String, at point: CGPoint, size: CGFloat, color: Color, weight: Font.Weight = .regular) {
            ctx.draw(Text(text).font(.system(size: size, weight: weight)).foregroundStyle(color), at: point)
        }

        let face = Path(ellipseIn: s.rect(x: -76, y: -62, width: 152, height: 160))
        ctx.fill(face, with: .color(ink.opacity(0.03)))
        ctx.stroke(face, with: .color(ink.opacity(0.45)), lineWidth: 0.6 * ppm)

        let nose = Path {
            for side in [-1.0, 1.0] {
                $0.move(to: p(side * 6.5, 7))
                $0.addQuadCurve(to: p(side * 9.5, -16), control: p(side * 6.5, -7))
                $0.addQuadCurve(to: p(side * 3, -19), control: p(side * 8, -20))
            }
        }
        ctx.stroke(nose, with: .color(ink.opacity(0.45)), lineWidth: 0.5 * ppm)

        let r = patient.irisRadius
        for pupil in [patient.rightPupil, patient.leftPupil] {
            let px = pupil.x, py = pupil.y
            let browY = max(py + 12, patient.lensHeight + 4)
            let brow = Path {
                $0.move(to: p(px - 14, browY))
                $0.addQuadCurve(to: p(px + 14, browY), control: p(px, browY + 6))
            }
            ctx.stroke(brow, with: .color(ink.opacity(0.55)), style: StrokeStyle(lineWidth: 1.4 * ppm, lineCap: .round))

            // Quadratic midpoints sit at the control/endpoint average, so the lower lid touches the iris bottom exactly.
            let upperControl = p(px, py + 2 * r - 1)
            let lowerControl = p(px, py - 2 * r + 1)
            let aperture = Path {
                $0.move(to: p(px - 13, py - 1))
                $0.addQuadCurve(to: p(px + 13, py - 1), control: upperControl)
                $0.addQuadCurve(to: p(px - 13, py - 1), control: lowerControl)
                $0.closeSubpath()
            }
            ctx.fill(aperture, with: .color(.white.opacity(0.92)))
            var eye = ctx
            eye.clip(to: aperture)
            eye.fill(Path(ellipseIn: s.rect(x: px - r, y: py - r, width: 2 * r, height: 2 * r)), with: .color(Color(hex: 0x6E5A44)))
            eye.fill(Path(ellipseIn: s.rect(x: px - 1.8, y: py - 1.8, width: 3.6, height: 3.6)), with: .color(.black))
            eye.fill(Path(ellipseIn: s.rect(x: px - 0.55, y: py - 0.55, width: 1.1, height: 1.1)), with: .color(.white))
            ctx.stroke(aperture, with: .color(ink.opacity(0.7)), lineWidth: 0.4 * ppm)
            let lowerLid = Path {
                $0.move(to: p(px + 13, py - 1))
                $0.addQuadCurve(to: p(px - 13, py - 1), control: lowerControl)
            }
            ctx.stroke(lowerLid, with: .color(ink.opacity(0.85)), lineWidth: 0.6 * ppm)
        }

        let a = patient.eyeSize, b = patient.lensHeight
        let corner = min(a, b) * 0.3
        for side in [-1.0, 1.0] {
            let cx = side * patient.lensCenterOffset
            let lens = RoundedRectangle(cornerRadius: corner * ppm, style: .continuous).path(in: s.rect(x: cx - a / 2, y: 0, width: a, height: b))
            ctx.fill(lens, with: .color(palette.accent.opacity(0.07)))
            let rim = RoundedRectangle(cornerRadius: (corner + 1) * ppm, style: .continuous).path(in: s.rect(x: cx - a / 2 - 1, y: -1, width: a + 2, height: b + 2))
            ctx.stroke(rim, with: .color(ink), lineWidth: 2 * ppm)
            let outer = side * (patient.bridge / 2 + a + 1)
            ctx.stroke(segment(p(outer, b * 0.8), p(outer + side * 4, b * 0.82)), with: .color(ink), lineWidth: 2 * ppm)
            label(side < 0 ? "OD" : "OS", at: p(cx + side * (a / 2 - 8), b - 6), size: max(9, 3.2 * ppm), color: palette.secondaryText, weight: .bold)
        }
        let bridge = Path {
            $0.move(to: p(-patient.bridge / 2 - 0.5, b * 0.7))
            $0.addQuadCurve(to: p(patient.bridge / 2 + 0.5, b * 0.7), control: p(0, b * 0.85))
        }
        ctx.stroke(bridge, with: .color(ink), lineWidth: 2 * ppm)

        let tickWidth = max(0.5, 0.18 * ppm)
        let labelSize = max(7, 2.6 * ppm)
        func tickLength(_ mm: Int) -> Double { mm % 10 == 0 ? 3.5 : mm % 5 == 0 ? 2.5 : 1.5 }

        if task.measuresHeight {
            for side in [-1.0, 1.0] {
                let edge = side * (patient.bridge / 2 + a + 2.5)
                let top = Int(min(b + 4, PDMeasureScale.bounds.maxY - 6))
                let strip = s.rect(x: min(edge, edge + side * 7), y: -1, width: 7, height: Double(top) + 2)
                ctx.fill(Path(strip), with: .color(palette.cardBackground.opacity(0.92)))
                ctx.stroke(Path(strip), with: .color(ink.opacity(0.6)), lineWidth: tickWidth)
                for mm in 0...top {
                    ctx.stroke(segment(p(edge, Double(mm)), p(edge + side * tickLength(mm), Double(mm))), with: .color(ink), lineWidth: tickWidth)
                    if mm % 10 == 0 { label("\(mm)", at: p(edge + side * 5.3, Double(mm)), size: labelSize, color: ink) }
                }
                let lensEdge = side * (patient.bridge / 2)
                ctx.stroke(segment(p(lensEdge, 0), p(edge, 0)), with: .color(palette.accent.opacity(0.8)), style: StrokeStyle(lineWidth: max(0.75, 0.25 * ppm), dash: [3, 3]))
            }
        } else {
            let strip = s.rect(x: -72, y: -12.5, width: 144, height: 9)
            ctx.fill(Path(strip), with: .color(palette.cardBackground.opacity(0.92)))
            ctx.stroke(Path(strip), with: .color(ink.opacity(0.6)), lineWidth: tickWidth)
            for mm in -70...70 {
                ctx.stroke(segment(p(Double(mm), -3.5), p(Double(mm), -3.5 - tickLength(mm))), with: .color(ink), lineWidth: tickWidth)
                if mm % 10 == 0 { label("\(abs(mm))", at: p(Double(mm), -9.6), size: labelSize, color: ink) }
            }
        }

        let guide = StrokeStyle(lineWidth: max(0.75, 0.25 * ppm), dash: [3, 3])
        for (index, marker) in markers.enumerated() {
            if task.measuresHeight {
                let edge = (marker.x < 0 ? -1 : 1) * (patient.bridge / 2 + a + 2.5)
                ctx.stroke(segment(p(marker.x, marker.y), p(edge, marker.y)), with: .color(palette.accent.opacity(0.7)), style: guide)
            } else {
                ctx.stroke(segment(p(marker.x, marker.y), p(marker.x, -3.5)), with: .color(palette.accent.opacity(0.7)), style: guide)
            }
            let ring = Path(ellipseIn: s.rect(x: marker.x - 2.4, y: marker.y - 2.4, width: 4.8, height: 4.8))
            ctx.stroke(ring, with: .color(palette.accent), lineWidth: 1.5)
            ctx.stroke(segment(p(marker.x - 3.6, marker.y), p(marker.x + 3.6, marker.y)), with: .color(palette.accent), lineWidth: 1)
            ctx.stroke(segment(p(marker.x, marker.y - 3.6), p(marker.x, marker.y + 3.6)), with: .color(palette.accent), lineWidth: 1)
            label(index == 0 ? "R" : "L", at: p(marker.x + 4.4, marker.y + 4.4), size: max(9, 3 * ppm), color: palette.accent, weight: .bold)
        }

        for point in revealed {
            ctx.fill(Path(ellipseIn: s.rect(x: point.x - 1.1, y: point.y - 1.1, width: 2.2, height: 2.2)), with: .color(.green))
            ctx.stroke(Path(ellipseIn: s.rect(x: point.x - 1.1, y: point.y - 1.1, width: 2.2, height: 2.2)), with: .color(.black.opacity(0.6)), lineWidth: 0.75)
        }
    }
}
