import SwiftUI

/// Always the patient's side, never the viewer's.
enum FrameFitSide: String, CaseIterable, Sendable {
    case right, left

    nonisolated var opposite: FrameFitSide { self == .right ? .left : .right }
}

enum FrameFitAdjustment: Hashable, Sendable {
    case raiseTemple(FrameFitSide)
    case angleTempleIn(FrameFitSide)
    case narrowPads, spreadPads
    case templesDown, templesUp
    case templesIn, templesOut
    case bendsForward, bendsBack
    case positiveFaceForm
    case padsAwayFromEyewires, padsTowardEyewires
    case splayFrontsTogether, splayBacksTogether
    case padTopsTogether, padBottomsTogether

    nonisolated var text: String {
        switch self {
        case .raiseTemple(let side): "Bend the patient's \(side.rawValue) temple up at the endpiece (or the \(side.opposite.rawValue) temple down)"
        case .angleTempleIn(let side): "Angle the patient's \(side.rawValue) temple in at the endpiece (or the \(side.opposite.rawValue) temple out)"
        case .narrowPads: "Move the nose pads closer together"
        case .spreadPads: "Spread the nose pads farther apart"
        case .templesDown: "Bend both temples down at the endpieces"
        case .templesUp: "Bend both temples up at the endpieces"
        case .templesIn: "Angle both temples in at the endpieces"
        case .templesOut: "Angle both temples out at the endpieces"
        case .bendsForward: "Move the temple bends forward, toward the frame front"
        case .bendsBack: "Move the temple bends back, away from the frame front"
        case .positiveFaceForm: "Bend the front at the bridge to give it slight positive face form"
        case .padsAwayFromEyewires: "Pull the pads back from the eyewires, toward the face"
        case .padsTowardEyewires: "Push the pads in toward the eyewires"
        case .splayFrontsTogether: "Splay the pads so their front edges are closer together than their back edges"
        case .splayBacksTogether: "Splay the pads so their back edges are closer together than their front edges"
        case .padTopsTogether: "Angle the pads so their tops are slightly closer together than their bottoms"
        case .padBottomsTogether: "Angle the pads so their bottoms are closer together than their tops"
        }
    }
}

enum FrameFitPerspective: Sendable {
    case front, top, side, padsFromAbove, padsFromFront

    var label: String {
        switch self {
        case .front: "Front view: the patient faces you"
        case .top: "Top view: the patient faces you"
        case .side: "Side view"
        case .padsFromAbove: "Close-up of the nose pads from above"
        case .padsFromFront: "Close-up of the nose pads from the front"
        }
    }
}

enum FrameFitFault: Hashable, Sendable {
    case sitsHigher(FrameFitSide)
    case lensCloser(FrameFitSide)
    case sitsTooLow, sitsTooHigh
    case retroscopicTilt, excessiveTilt
    case negativeFaceForm
    case templesTooTight, templesTooLoose
    case bendTooFarBack, bendTooFarForward
    case lashesTouch
    case padSplayReversed, padFrontalReversed

    nonisolated static let all: [FrameFitFault] = FrameFitSide.allCases.flatMap { [.sitsHigher($0), .lensCloser($0)] } + [
        .sitsTooLow, .sitsTooHigh, .retroscopicTilt, .excessiveTilt, .negativeFaceForm, .templesTooTight, .templesTooLoose,
        .bendTooFarBack, .bendTooFarForward, .lashesTouch, .padSplayReversed, .padFrontalReversed,
    ]

    var perspective: FrameFitPerspective {
        switch self {
        case .sitsHigher, .sitsTooLow, .sitsTooHigh: .front
        case .lensCloser, .negativeFaceForm, .templesTooTight, .templesTooLoose: .top
        case .retroscopicTilt, .excessiveTilt, .bendTooFarBack, .bendTooFarForward, .lashesTouch: .side
        case .padSplayReversed: .padsFromAbove
        case .padFrontalReversed: .padsFromFront
        }
    }

    nonisolated var fix: FrameFitAdjustment {
        switch self {
        case .sitsHigher(let side): .raiseTemple(side)
        case .lensCloser(let side): .angleTempleIn(side)
        case .sitsTooLow: .narrowPads
        case .sitsTooHigh: .spreadPads
        case .retroscopicTilt: .templesDown
        case .excessiveTilt: .templesUp
        case .negativeFaceForm: .positiveFaceForm
        case .templesTooTight: .templesOut
        case .templesTooLoose: .templesIn
        case .bendTooFarBack: .bendsForward
        case .bendTooFarForward: .bendsBack
        case .lashesTouch: .padsAwayFromEyewires
        case .padSplayReversed: .splayFrontsTogether
        case .padFrontalReversed: .padTopsTogether
        }
    }

    /// The first distractor is always the reversed fix, the most common exam trap.
    nonisolated var distractors: [FrameFitAdjustment] {
        switch self {
        case .sitsHigher(let side): [.raiseTemple(side.opposite), .angleTempleIn(side), .spreadPads]
        case .lensCloser(let side): [.angleTempleIn(side.opposite), .raiseTemple(side), .templesDown]
        case .sitsTooLow: [.spreadPads, .templesUp, .templesOut]
        case .sitsTooHigh: [.narrowPads, .templesDown, .templesIn]
        case .retroscopicTilt: [.templesUp, .positiveFaceForm, .spreadPads]
        case .excessiveTilt: [.templesDown, .spreadPads, .templesIn]
        case .negativeFaceForm: [.templesIn, .templesDown, .narrowPads]
        case .templesTooTight: [.templesIn, .positiveFaceForm, .narrowPads]
        case .templesTooLoose: [.templesOut, .spreadPads, .templesUp]
        case .bendTooFarBack: [.bendsBack, .templesOut, .spreadPads]
        case .bendTooFarForward: [.bendsForward, .templesIn, .templesDown]
        case .lashesTouch: [.padsTowardEyewires, .templesOut, .spreadPads]
        case .padSplayReversed: [.splayBacksTogether, .padTopsTogether, .spreadPads]
        case .padFrontalReversed: [.padBottomsTogether, .splayFrontsTogether, .narrowPads]
        }
    }

    var title: String {
        switch self {
        case .sitsHigher(let side): "Frame higher on the patient's \(side.rawValue)"
        case .lensCloser(let side): "Patient's \(side.rawValue) lens too close"
        case .sitsTooLow: "Frame sitting too low"
        case .sitsTooHigh: "Frame sitting too high"
        case .retroscopicTilt: "Retroscopic tilt"
        case .excessiveTilt: "Too much pantoscopic tilt"
        case .negativeFaceForm: "Negative face form"
        case .templesTooTight: "Temples too tight"
        case .templesTooLoose: "Temples too loose"
        case .bendTooFarBack: "Temple bends too far back"
        case .bendTooFarForward: "Temple bends too far forward"
        case .lashesTouch: "Lashes hitting the lenses"
        case .padSplayReversed: "Pad splay angle reversed"
        case .padFrontalReversed: "Pad frontal angle reversed"
        }
    }

    var observation: String {
        switch self {
        case .sitsHigher(let side): "The frame is in standard alignment on the bench, but on the face it sits higher on the patient's \(side.rawValue) side."
        case .lensCloser(let side): "The frame is in standard alignment on the bench, but on the face the patient's \(side.rawValue) lens sits closer to the eye than the \(side.opposite.rawValue)."
        case .sitsTooLow: "This metal frame sits low on the nose: the pupils are near the tops of the eyewires."
        case .sitsTooHigh: "This metal frame rides high against the brows, and the pads pinch the nose."
        case .retroscopicTilt: "The lower rims stand farther from the face than the tops."
        case .excessiveTilt: "The lower rims rest on the cheeks."
        case .negativeFaceForm: "The endpieces sit forward of the bridge, and the frame feels loose."
        case .templesTooTight: "The temples press into the sides of the head."
        case .templesTooLoose: "There are gaps between the temples and the head, and the glasses slide."
        case .bendTooFarBack: "The temple bends start well behind the ears, and the glasses slide down the nose."
        case .bendTooFarForward: "The temples bend down before the tops of the ears and press on them."
        case .lashesTouch: "The patient's lashes brush the backs of the lenses. The frame has adjustable pads."
        case .padSplayReversed: "Only the back edges of the pads touch the nose, leaving marks."
        case .padFrontalReversed: "Only the lower edges of the pads touch the nose, leaving marks."
        }
    }

    var explanation: String {
        switch self {
        case .sitsHigher:
            "Level a frame with the temple angle at the endpiece. Bending a temple up lowers that side of the front; bending it down raises it. So bend the high side's temple up, or the low side's temple down. Bending the high side down is the classic reversal and makes the tilt worse."
        case .lensCloser:
            "A temple angled in at the endpiece meets the head sooner and pushes that side of the front away from the face. So angle in the temple on the side of the closer lens, or open the opposite temple. The frame is already in standard alignment, so the bridge is not the problem."
        case .sitsTooLow:
            "Pad spread sets frame height. Moving the pads closer together makes them rest higher on the narrower part of the nose and lifts the frame; spreading them lets it drop. The same adjustment fine-tunes multifocal and progressive heights."
        case .sitsTooHigh:
            "Spreading the pads lets them settle lower on the wider part of the nose and brings the frame down. Moving them closer together would push it higher still."
        case .retroscopicTilt:
            "Retroscopic tilt is never acceptable: it looks wrong and degrades the optics. Bending both temples down at the endpieces tips the lower rims in toward the cheeks, giving the pantoscopic tilt you want."
        case .excessiveTilt:
            "The lower rims are tipped too far in. Bend both temples up at the endpieces to reduce the pantoscopic tilt. If the tilt keeps coming back, check the temple bends behind the ears too."
        case .negativeFaceForm:
            "Positive face form, with the bridge slightly forward of the endpieces, follows the curve of the face. Negative face form looks wrong, is optically incorrect and makes the frame feel loose. Correct it at the bridge (heat the bridge area on a plastic frame); bending the temples only hides it."
        case .templesTooTight:
            "Increase the temple spread by angling both temples out at the endpieces. Angling them in squeezes harder, and adding face form also narrows the temple spread. If the pressure is behind the ear instead, look at where the bend begins."
        case .templesTooLoose:
            "Reduce the temple spread by angling both temples in at the endpieces, so the temples touch the head lightly just before the ears and add grip."
        case .bendTooFarBack:
            "An improper temple bend is the most common reason glasses slip. The bend should begin just past the top of the ear, with the earpiece following the back of the ear and the side of the head. Move the bends forward."
        case .bendTooFarForward:
            "A bend that starts before the top of the ear digs into it. Move the bends back so they begin just past the top of the ear, then contour the earpiece behind the ear."
        case .lashesTouch:
            "The vertex distance is too short. Pull the pads back from the eyewires toward the face, which pushes the front farther from the eyes; easing the temple bends slightly can also help. Pushing the pads toward the eyewires brings the lenses even closer."
        case .padSplayReversed:
            "Splay is the pad angle seen from above. The nose widens toward the face, so the front edges of the pads should be closer together than the back edges, letting each pad sit flush. Wrong splay is one of the most common reasons pads hurt."
        case .padFrontalReversed:
            "The frontal angle is the pad angle seen from the front. The nose widens from top to bottom, so the tops of the pads should be slightly closer together than the bottoms. Then the whole pad face rests on the nose."
        }
    }
}

struct FrameAdjustmentTrainerView: View {
    @State private var fault = FrameFitFault.all.randomElement()!
    @State private var choices: [FrameFitAdjustment] = []
    @State private var picked: FrameFitAdjustment?
    @State private var correctCount = 0
    @State private var attempts = 0
    @Environment(\.palette) private var palette

    private static let sources = [
        SourceLink(title: "Laramy-K OpticianWorks: The Ultimate ABO Study Guide", url: URL(string: "https://opticianworks.com/wp-content/uploads/2024/01/Laramy-K-OpticianWorks-Ultimate-ABO-Study-Guide-v6.23.pdf")!),
        SourceLink(title: "Ohio Optometric Association: Frame Adjusting II (J. Rohlf, LDO)", url: URL(string: "https://www.ooa.org/aws/OOA/asset_manager/get_file/110782?ver=85")!),
        SourceLink(title: "The Vision Council: Dispensing Guide", url: URL(string: "https://thevisioncouncil.org/sites/default/files/assets/media/Dispensing-Guide_2020.pdf")!),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Panel(padding: 12) {
                    VStack(spacing: 8) {
                        FrameFitDrawing(fault: fault)
                            .frame(maxWidth: 420)
                            .frame(maxWidth: .infinity)
                            .accessibilityLabel(fault.observation)
                        Text(fault.perspective.label)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(palette.secondaryText)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(fault.observation).font(.headline)
                    Text("Which adjustment fixes it?")
                        .font(.subheadline)
                        .foregroundStyle(palette.secondaryText)
                }

                VStack(spacing: 10) {
                    ForEach(choices, id: \.self) { choice in
                        Button { answer(choice) } label: {
                            HStack {
                                Text(choice.text).multilineTextAlignment(.leading)
                                Spacer()
                                if let picked {
                                    if choice == fault.fix {
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
                            Text(fault.title).font(.headline)
                            Label { Text(fault.fix.text) } icon: { Image(systemName: "wrench.adjustable") }
                                .font(.subheadline.weight(.medium))
                            Text(fault.explanation)
                                .font(.subheadline)
                                .foregroundStyle(palette.secondaryText)
                            Button("Next Fit", action: next)
                                .buttonStyle(.borderedProminent)
                                .accessibilityIdentifier("frameAdjustment.next")
                        }
                    }
                }

                Text("Score \(correctCount) / \(attempts)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(palette.secondaryText)

                Panel {
                    VStack(alignment: .leading, spacing: 10) {
                        RichText(text: "Right and left always mean the **patient's** right and left. In the front and top views the patient faces you, so their right is on your left. Bending a temple **down** at the endpiece raises that side of the front; bending it **up** lowers it. Simplified line drawings with each fault exaggerated.")
                            .font(.caption)
                        SourceList(sources: Self.sources)
                    }
                }
            }
            .padding()
        }
        .pettyScreen()
        .navigationTitle("Frame Adjustments")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { if choices.isEmpty { load(fault) } }
    }

    private func answer(_ choice: FrameFitAdjustment) {
        picked = choice
        attempts += 1
        if choice == fault.fix { correctCount += 1 }
    }

    private func next() {
        load(FrameFitFault.all.filter { $0 != fault }.randomElement()!)
    }

    private func load(_ newFault: FrameFitFault) {
        fault = newFault
        picked = nil
        choices = Self.choices(for: newFault)
    }

    nonisolated static func choices(for fault: FrameFitFault) -> [FrameFitAdjustment] {
        ([fault.fix] + fault.distractors).shuffled()
    }
}

private struct FrameFitDrawing: View {
    let fault: FrameFitFault
    @Environment(\.palette) private var palette

    var body: some View {
        let ink = FrameFitArt.Ink(face: palette.secondaryText, frame: palette.accent, fault: .red, guide: palette.tertiaryText, label: palette.secondaryText)
        Canvas { ctx, size in
            FrameFitArt.draw(fault, in: &ctx, size: size, ink: ink)
        }
        .aspectRatio(FrameFitArt.space.width / FrameFitArt.space.height, contentMode: .fit)
    }
}

/// Line art in a fixed 320 × 240 space with y running down; the patient's right is the viewer's left.
enum FrameFitArt {
    struct Ink {
        let face: Color
        let frame: Color
        let fault: Color
        let guide: Color
        let label: Color
    }

    static let space = CGSize(width: 320, height: 240)
    private static let frontFrameY = 116.0
    private static let topFrontY = 212.0

    /// Positive rotation raises the viewer's left, which is the patient's right.
    nonisolated static func tiltTransform(for fault: FrameFitFault) -> CGAffineTransform {
        let pivot: (side: FrameFitSide, y: Double)
        switch fault {
        case .sitsHigher(let side): pivot = (side, frontFrameY)
        case .lensCloser(let side): pivot = (side, topFrontY)
        default: return .identity
        }
        let radians = (pivot.side == .right ? 7.0 : -7.0) * .pi / 180
        return CGAffineTransform(translationX: 160, y: pivot.y).rotated(by: radians).translatedBy(x: -160, y: -pivot.y)
    }

    static func draw(_ fault: FrameFitFault, in ctx: inout GraphicsContext, size: CGSize, ink: Ink) {
        let scale = min(size.width / space.width, size.height / space.height)
        ctx.translateBy(x: (size.width - space.width * scale) / 2, y: (size.height - space.height * scale) / 2)
        ctx.scaleBy(x: scale, y: scale)
        switch fault.perspective {
        case .front: drawFront(fault, &ctx, ink)
        case .top: drawTop(fault, &ctx, ink)
        case .side: drawSide(fault, &ctx, ink)
        case .padsFromAbove: drawPadsFromAbove(&ctx, ink)
        case .padsFromFront: drawPadsFromFront(&ctx, ink)
        }
        if fault.perspective != .side {
            for (text, x) in [("Patient's R", 40.0), ("Patient's L", 280.0)] {
                ctx.draw(Text(text).font(.system(size: 10, weight: .semibold)).foregroundStyle(ink.label), at: p(x, 10))
            }
        }
    }

    private static func drawFront(_ fault: FrameFitFault, _ ctx: inout GraphicsContext, _ ink: Ink) {
        let face = GraphicsContext.Shading.color(ink.face)
        ctx.stroke(ellipse(p(160, 125), 88, 108), with: face, lineWidth: 1.5)
        for x in [70.0, 250] {
            ctx.stroke(ellipse(p(x, 122), 9, 20), with: face, lineWidth: 1.5)
        }
        for x in [124.0, 196] {
            ctx.stroke(ellipse(p(x, 112), 14, 7), with: face, lineWidth: 1.5)
            ctx.fill(ellipse(p(x, 112), 4.5, 4.5), with: face)
            ctx.stroke(Path { $0.move(to: p(x - 16, 95)); $0.addQuadCurve(to: p(x + 16, 95), control: p(x, 86)) }, with: face, lineWidth: 2)
        }
        ctx.stroke(Path {
            $0.move(to: p(156, 120))
            $0.addLine(to: p(147, 155))
            $0.addQuadCurve(to: p(173, 155), control: p(160, 166))
            $0.addLine(to: p(164, 120))
        }, with: face, lineWidth: 1.5)
        ctx.stroke(Path { $0.move(to: p(140, 190)); $0.addQuadCurve(to: p(180, 190), control: p(160, 199)) }, with: face, lineWidth: 1.5)
        ctx.stroke(line(p(54, 112), p(266, 112)), with: .color(ink.guide), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))

        let y = frontFrameY + (fault == .sitsTooLow ? 16 : fault == .sitsTooHigh ? -16 : 0)
        let shade = GraphicsContext.Shading.color(ink.frame)
        var frame = ctx
        frame.concatenate(tiltTransform(for: fault))
        for x in [124.0, 196] {
            frame.stroke(Path(roundedRect: CGRect(x: x - 29, y: y - 19, width: 58, height: 38), cornerRadius: 12), with: shade, lineWidth: 3)
        }
        frame.stroke(Path { $0.move(to: p(153, y - 10)); $0.addQuadCurve(to: p(167, y - 10), control: p(160, y - 17)) }, with: shade, lineWidth: 3)
        frame.stroke(line(p(95, y - 9), p(72, y - 12)), with: shade, lineWidth: 3)
        frame.stroke(line(p(225, y - 9), p(248, y - 12)), with: shade, lineWidth: 3)
        for x in [151.0, 169] {
            frame.fill(ellipse(p(x, y + 6), 2.5, 5), with: shade)
        }
        if fault == .sitsTooHigh {
            mark(p(151, y + 6), &frame, ink)
            mark(p(169, y + 6), &frame, ink)
        }
    }

    private static func drawTop(_ fault: FrameFitFault, _ ctx: inout GraphicsContext, _ ink: Ink) {
        let face = GraphicsContext.Shading.color(ink.face)
        ctx.stroke(Path(roundedRect: CGRect(x: 92, y: 18, width: 136, height: 180), cornerRadius: 58), with: face, lineWidth: 1.5)
        for x in [89.0, 231] {
            ctx.stroke(ellipse(p(x, 100), 5, 14), with: face, lineWidth: 1.5)
        }
        ctx.stroke(line(p(150, 197), p(160, 220), p(170, 197)), with: face, lineWidth: 1.5)
        for x in [130.0, 190] {
            ctx.fill(ellipse(p(x, 192), 9, 3.5), with: face)
        }

        let (bridgeY, endY) = fault == .negativeFaceForm ? (208.0, 222.0) : (214.0, 209.0)
        let tilt = tiltTransform(for: fault)
        let shade = GraphicsContext.Shading.color(ink.frame)
        let lensStyle = StrokeStyle(lineWidth: 4, lineCap: .round)
        var front = ctx
        front.concatenate(tilt)
        front.stroke(line(p(88, endY), p(152, bridgeY)), with: shade, style: lensStyle)
        front.stroke(line(p(168, bridgeY), p(232, endY)), with: shade, style: lensStyle)
        front.stroke(Path { $0.move(to: p(152, bridgeY)); $0.addQuadCurve(to: p(168, bridgeY), control: p(160, bridgeY + 4)) }, with: shade, lineWidth: 2.5)

        if fault == .negativeFaceForm {
            ctx.stroke(line(p(88, endY), p(232, endY)), with: .color(ink.guide), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
        }
        if case .lensCloser = fault {
            let dash = StrokeStyle(lineWidth: 1.5, dash: [3, 3])
            for (eyeX, lensY) in [(130.0, endY + (130 - 88) / 64 * (bridgeY - endY)), (190.0, endY + (232 - 190) / 64 * (bridgeY - endY))] {
                ctx.stroke(line(p(eyeX, 195), p(eyeX, lensY).applying(tilt)), with: .color(ink.fault), style: dash)
            }
        }

        let templeStyle = StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
        for mirrored in [false, true] {
            func m(_ x: Double, _ y: Double) -> CGPoint { p(mirrored ? 320 - x : x, y) }
            let endpiece = m(88, endY).applying(tilt)
            let temple = Path { path in
                path.move(to: endpiece)
                switch fault {
                case .templesTooTight:
                    path.addLine(to: m(97, 112))
                    path.addQuadCurve(to: m(100, 62), control: m(97, 84))
                case .templesTooLoose:
                    path.addLine(to: m(72, 100))
                    path.addQuadCurve(to: m(80, 62), control: m(72, 76))
                default:
                    path.addLine(to: m(86, 100))
                    path.addQuadCurve(to: m(95, 60), control: m(86, 78))
                }
            }
            ctx.stroke(temple, with: shade, style: templeStyle)
            if fault == .templesTooTight {
                mark(m(95, 128), &ctx, ink)
            } else if fault == .templesTooLoose {
                ctx.stroke(line(m(75, 124), m(90, 124)), with: .color(ink.fault), style: StrokeStyle(lineWidth: 1.5, dash: [3, 2]))
            }
        }
    }

    private static func drawSide(_ fault: FrameFitFault, _ ctx: inout GraphicsContext, _ ink: Ink) {
        let face = GraphicsContext.Shading.color(ink.face)
        ctx.stroke(Path {
            $0.move(to: p(150, 18))
            $0.addQuadCurve(to: p(232, 70), control: p(220, 22))
            $0.addQuadCurve(to: p(238, 96), control: p(238, 82))
            $0.addQuadCurve(to: p(236, 112), control: p(232, 104))
            $0.addLine(to: p(264, 150))
            $0.addQuadCurve(to: p(246, 158), control: p(262, 160))
            $0.addQuadCurve(to: p(248, 178), control: p(244, 168))
            $0.addQuadCurve(to: p(240, 204), control: p(250, 196))
            $0.addQuadCurve(to: p(205, 230), control: p(236, 226))
        }, with: face, lineWidth: 1.5)
        ctx.stroke(Path {
            $0.move(to: p(150, 18))
            $0.addQuadCurve(to: p(52, 120), control: p(60, 22))
            $0.addQuadCurve(to: p(110, 232), control: p(50, 210))
        }, with: face, lineWidth: 1.5)
        ctx.stroke(ellipse(p(130, 120), 12, 24), with: face, lineWidth: 1.5)
        ctx.stroke(Path { $0.move(to: p(230, 124)); $0.addQuadCurve(to: p(234, 150), control: p(248, 132)) }, with: face, lineWidth: 1.2)
        ctx.stroke(ellipse(p(226, 112), 6, 4), with: face, lineWidth: 1.5)
        let lashReach = fault == .lashesTouch ? 9.0 : 5
        for dy in [-4.0, -1, 2] {
            ctx.stroke(line(p(231, 110 + dy * 0.5), p(231 + lashReach, 106 + dy)), with: face, lineWidth: 1)
        }

        let tiltDegrees: Double = switch fault {
        case .retroscopicTilt: -14
        case .excessiveTilt: 34
        default: 10
        }
        let cx = fault == .lashesTouch ? 238.0 : 252
        let cy = 112.0
        let radians = tiltDegrees * .pi / 180
        let top = p(cx + sin(radians) * 20, cy - cos(radians) * 20)
        let bottom = p(cx - sin(radians) * 20, cy + cos(radians) * 20)
        if fault == .retroscopicTilt || fault == .excessiveTilt {
            ctx.stroke(line(p(cx, 84), p(cx, 140)), with: .color(ink.guide), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
        }

        let shade = GraphicsContext.Shading.color(ink.frame)
        ctx.stroke(line(top, bottom), with: shade, style: StrokeStyle(lineWidth: 5, lineCap: .round))
        ctx.stroke(line(p(cx - 1, cy), p(cx - 8, cy + 3)), with: shade, lineWidth: 1.5)
        ctx.fill(ellipse(p(cx - 9, cy + 4), 2, 6), with: shade)

        let bendX: Double = switch fault {
        case .bendTooFarBack: 96
        case .bendTooFarForward: 142
        default: 124
        }
        ctx.stroke(Path {
            $0.move(to: p(top.x - 4, top.y + 4))
            $0.addLine(to: p(bendX, 95))
            $0.addQuadCurve(to: p(bendX - 12, 142), control: p(bendX - 8, 104))
        }, with: shade, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))

        switch fault {
        case .excessiveTilt: mark(bottom, &ctx, ink)
        case .lashesTouch: mark(p(239, 105), &ctx, ink)
        case .bendTooFarForward: mark(p(137, 98), &ctx, ink)
        default: break
        }
    }

    private static func drawPadsFromAbove(_ ctx: inout GraphicsContext, _ ink: Ink) {
        let face = GraphicsContext.Shading.color(ink.face)
        ctx.stroke(line(p(20, 40), p(110, 40), p(160, 212), p(210, 40), p(300, 40)), with: face, lineWidth: 2)
        let shade = GraphicsContext.Shading.color(ink.frame)
        ctx.stroke(line(p(20, 200), p(128, 200)), with: shade, style: StrokeStyle(lineWidth: 4, lineCap: .round))
        ctx.stroke(line(p(192, 200), p(300, 200)), with: shade, style: StrokeStyle(lineWidth: 4, lineCap: .round))
        ctx.stroke(Path { $0.move(to: p(128, 200)); $0.addQuadCurve(to: p(192, 200), control: p(160, 192)) }, with: shade, lineWidth: 3)
        // Back edges angled in toward the nose: the reverse of the nose's own taper.
        let half = 20.0, angle = 16.0 * .pi / 180
        for mirrored in [false, true] {
            func m(_ x: Double, _ y: Double) -> CGPoint { p(mirrored ? 320 - x : x, y) }
            let dx = sin(angle) * half, dy = cos(angle) * half
            ctx.stroke(line(m(119 + dx, 112 - dy), m(119 - dx, 112 + dy)), with: shade, style: StrokeStyle(lineWidth: 7, lineCap: .round))
            ctx.stroke(line(m(140, 198), m(118, 122)), with: shade, lineWidth: 1.5)
            mark(m(119 + dx, 112 - dy), &ctx, ink)
        }
    }

    private static func drawPadsFromFront(_ ctx: inout GraphicsContext, _ ink: Ink) {
        let face = GraphicsContext.Shading.color(ink.face)
        ctx.stroke(Path {
            $0.move(to: p(146, 20))
            $0.addLine(to: p(118, 205))
            $0.addQuadCurve(to: p(202, 205), control: p(160, 222))
            $0.addLine(to: p(174, 20))
        }, with: face, lineWidth: 2)
        let shade = GraphicsContext.Shading.color(ink.frame)
        ctx.stroke(Path(roundedRect: CGRect(x: -10, y: 40, width: 118, height: 120), cornerRadius: 30), with: shade, lineWidth: 3)
        ctx.stroke(Path(roundedRect: CGRect(x: 212, y: 40, width: 118, height: 120), cornerRadius: 30), with: shade, lineWidth: 3)
        ctx.stroke(Path { $0.move(to: p(100, 58)); $0.addQuadCurve(to: p(220, 58), control: p(160, 30)) }, with: shade, lineWidth: 3)
        // Tops splayed apart, the reverse of the nose widening downward.
        let half = 20.0, angle = 18.0 * .pi / 180
        for mirrored in [false, true] {
            func m(_ x: Double, _ y: Double) -> CGPoint { p(mirrored ? 320 - x : x, y) }
            let dx = sin(angle) * half, dy = cos(angle) * half
            ctx.stroke(line(m(123.2 - dx, 111 - dy), m(123.2 + dx, 111 + dy)), with: shade, style: StrokeStyle(lineWidth: 7, lineCap: .round))
            ctx.stroke(line(m(108, 128), m(121, 114)), with: shade, lineWidth: 1.5)
            mark(m(123.2 + dx, 111 + dy), &ctx, ink)
        }
    }

    private static func mark(_ at: CGPoint, _ ctx: inout GraphicsContext, _ ink: Ink) {
        ctx.fill(ellipse(at, 3.5, 3.5), with: .color(ink.fault))
        ctx.stroke(ellipse(at, 7, 7), with: .color(ink.fault.opacity(0.6)), lineWidth: 1.5)
    }

    private static func p(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: x, y: y) }

    private static func line(_ points: CGPoint...) -> Path { Path { $0.addLines(points) } }

    private static func ellipse(_ c: CGPoint, _ rx: Double, _ ry: Double) -> Path {
        Path(ellipseIn: CGRect(x: c.x - rx, y: c.y - ry, width: rx * 2, height: ry * 2))
    }
}
