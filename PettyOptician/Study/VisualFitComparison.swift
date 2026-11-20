import SwiftUI

enum VisualFitLesson: String {
    case pupillaryDistance = "abo.dispensing#5"
    case softLensFit = "ncle.fitting#2"

    var title: String {
        switch self {
        case .pupillaryDistance: "Two frames, one distance PD"
        case .softLensFit: "One wearer, two trial lenses"
        }
    }

    var introduction: String {
        switch self {
        case .pupillaryDistance:
            "The wearer measures 30 mm OD and 34 mm OS. Both distance orders use +4.00 D spherical lenses with zero prescribed prism. Compare the pupil dots and optical-center crosses with the frames in their wearing position."
        case .softLensFit:
            "Compare two settled soft lenses on the same right eye at separate trial visits. Both initially feel comfortable. Change the observation to see how each lens responds."
        }
    }

    var question: String {
        switch self {
        case .pupillaryDistance: "Which frame places both optical centers at the measured pupil positions?"
        case .softLensFit: "Which lens shows the tighter fitting pattern?"
        }
    }

    var correctIndex: Int { self == .pupillaryDistance ? 1 : 0 }

    func specimen(_ index: Int) -> String {
        let name = self == .pupillaryDistance ? "Frame" : "Lens"
        return "\(name) \(index == 0 ? "A" : "B")"
    }

    func explanation(for index: Int) -> String {
        switch self {
        case .pupillaryDistance:
            let clue = index == correctIndex ? "Both crosses in Frame B coincide with the pupils." : "Frame A has the correct 64 mm total, but its equal split puts both crosses beside the pupils."
            return clue + " Frame A puts the right optical center 2 mm temporal to the right pupil. At +4.00 D that produces 0.2 cm × 4.00 D = 0.8Δ base out at OD. Read the two monocular distances separately when checking the order."
        case .softLensFit:
            let clue = index == correctIndex ? "Lens A barely shifts with the blink and resists the lid on push-up." : "Lens B moves farther on the blink and displaces easily on push-up. Those findings favor a loose fit."
            return clue + " Compare the movement and resistance together. Initial comfort and a centered appearance can conceal a tight fit. In practice, also check coverage, vision and the ocular surface."
        }
    }
}

private enum FitObservation: String, CaseIterable {
    case rest = "At rest"
    case blink = "After blink"
    case push = "Push-up"

    func scene(for trial: SoftLensCase) -> SoftLensScene {
        switch self {
        case .rest: trial.scene(at: 0)
        case .blink: trial.scene(at: SoftLensCase.firstBlink + 0.35)
        case .push: trial.scene(at: 0, pushUpElapsed: SoftLensCase.holdEnd)
        }
    }

    func caption(for index: Int) -> String {
        switch (self, index) {
        case (.rest, 0): "Lens centered over the cornea."
        case (.rest, _): "Lens sits slightly below center."
        case (.blink, 0): "The lower edge barely shifts."
        case (.blink, _): "The lower edge shifts visibly."
        case (.push, 0): "The lower lid rises. The lens resists."
        case (.push, _): "The same lid movement lifts the lens easily."
        }
    }
}

struct VisualFitComparison: View {
    let lesson: VisualFitLesson
    @Environment(\.palette) private var palette
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var observation = FitObservation.rest
    @State private var selection: Int?

    // A common iris and vessel landmark keep attention on differences between lenses.
    private static let eye = EyeLook(
        irisInner: Color(red: 0.57, green: 0.43, blue: 0.28),
        irisOuter: Color(red: 0.28, green: 0.24, blue: 0.17),
        vessels: [
            .init(points: [[-10, 4], [-8.8, 4.6], [-7.4, 4.8], [-6, 4.4]], width: 0.14, opacity: 0.52),
            .init(points: [[10, 3.4], [8.9, 3.8], [7.8, 4], [6.8, 4.4]], width: 0.12, opacity: 0.44)
        ]
    )

    var body: some View {
        Panel(padding: 16) {
            VStack(alignment: .leading, spacing: 14) {
                Text(lesson.title)
                    .font(.system(.title3, design: .serif, weight: .bold))
                    .accessibilityAddTraits(.isHeader)
                Text(lesson.introduction).font(.subheadline)
                if lesson == .softLensFit {
                    if typeSize.isAccessibilitySize {
                        phasePicker.pickerStyle(.menu)
                    } else {
                        phasePicker.pickerStyle(.segmented)
                    }
                } else {
                    Label("Front view. OD is on your left. Mark separation is enlarged.", systemImage: "eyeglasses")
                        .font(.caption)
                        .foregroundStyle(palette.secondaryText)
                }

                let layout = typeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10))
                    : AnyLayout(HStackLayout(alignment: .top, spacing: 8))
                layout {
                    ForEach(0..<2) { index in specimen(index) }
                }

                Text(lesson.question).font(.headline)
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) { choices }
                    VStack(alignment: .leading, spacing: 8) { choices }
                }
                if let selection {
                    VStack(alignment: .leading, spacing: 6) {
                        Label(selection == lesson.correctIndex ? "Correct" : "Compare again",
                              systemImage: selection == lesson.correctIndex ? "checkmark.circle.fill" : "magnifyingglass")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(palette.accent)
                        Text(lesson.explanation(for: selection)).font(.subheadline)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("visual.feedback")
                }
            }
            .foregroundStyle(palette.text)
        }
    }

    private var phasePicker: some View {
        Picker("Observation", selection: $observation) {
            ForEach(FitObservation.allCases, id: \.self) { phase in Text(phase.rawValue).tag(phase) }
        }
    }

    private func specimen(_ index: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(lesson.specimen(index)).font(.subheadline.weight(.bold))
            if lesson == .pupillaryDistance {
                let right = index == 0 ? 32 : 30
                let left = index == 0 ? 32 : 34
                PDFrameDiagram(rightCenterMM: right, leftCenterMM: left)
                    .accessibilityHidden(true)
                Text("OD \(right) · OS \(left) mm")
                    .font(.caption.monospacedDigit())
            } else {
                let trial = SoftLensCase(fit: index == 0 ? .tight : .loose, variation: .init())
                SoftLensFrame(fit: trial.fit, look: Self.eye, scene: observation.scene(for: trial))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .accessibilityHidden(true)
                Text(observation.caption(for: index)).font(.caption)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("visual.specimen.\(index)")
        .accessibilityValue(lesson == .pupillaryDistance
            ? (index == 0 ? "Both crosses sit left of the pupil dots in the examiner’s view." : "Each cross overlaps its pupil dot.") : "")
    }

    @ViewBuilder private var choices: some View {
        ForEach(0..<2) { index in
            Button { selection = index } label: {
                Label(lesson.specimen(index), systemImage: selection == index ? "largecircle.fill.circle" : "circle")
                    .frame(minHeight: 32)
            }
            .buttonStyle(.bordered)
            .tint(palette.accent)
            .accessibilityAddTraits(selection == index ? .isSelected : [])
            .accessibilityIdentifier("visual.choice.\(index)")
        }
    }
}

private struct PDFrameDiagram: View {
    let rightCenterMM: Int
    let leftCenterMM: Int
    @Environment(\.palette) private var palette

    var body: some View {
        Canvas { context, size in
            let scale = size.width / 120
            func point(_ x: Double, _ y: Double) -> CGPoint {
                CGPoint(x: size.width / 2 + x * scale, y: y * scale)
            }
            let pen = StrokeStyle(lineWidth: max(1.3, 1.5 * scale), lineCap: .round, lineJoin: .round)
            var bridge = Path()
            bridge.move(to: point(-8, 18))
            bridge.addQuadCurve(to: point(8, 18), control: point(0, 11))
            context.stroke(bridge, with: .color(palette.secondaryText), style: pen)
            for (pupil, measuredCenter) in [(-30.0, -Double(rightCenterMM)), (34.0, Double(leftCenterMM))] {
                let center = pupil < 0 ? -31.0 : 31.0
                let frame = CGRect(origin: point(center - 23, 8), size: CGSize(width: 46 * scale, height: 32 * scale))
                let rim = Path(roundedRect: frame, cornerRadius: 9 * scale)
                context.fill(rim, with: .color(palette.accent.opacity(0.05)))
                context.stroke(rim, with: .color(palette.secondaryText), style: pen)
                let dot = point(pupil, 24)
                context.fill(Path(ellipseIn: CGRect(x: dot.x - 2.4 * scale, y: dot.y - 2.4 * scale,
                                                    width: 4.8 * scale, height: 4.8 * scale)), with: .color(palette.text))
                let oc = pupil + 3 * (measuredCenter - pupil)
                var cross = Path()
                cross.move(to: point(oc - 4.8, 24))
                cross.addLine(to: point(oc + 4.8, 24))
                cross.move(to: point(oc, 19.2))
                cross.addLine(to: point(oc, 28.8))
                context.stroke(cross, with: .color(palette.accent), style: pen)
            }
        }
        .aspectRatio(120.0 / 48, contentMode: .fit)
    }
}
