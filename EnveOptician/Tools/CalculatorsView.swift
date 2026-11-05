import SwiftUI

struct CalculatorsView: View {
    enum Tool: String, CaseIterable, Identifiable {
        case transpose = "Transposition"
        case prentice = "Prentice's Rule"
        case imbalance = "Vertical Imbalance"
        case vertex = "Vertex Distance"
        case oblique = "Oblique Meridian"
        case keratometry = "K Readings & Tear Lens"
        case blank = "Minimum Blank Size"
        case nearPD = "Near PD"

        var id: String { rawValue }

        var symbol: String {
            switch self {
            case .transpose: "arrow.left.arrow.right"
            case .prentice: "triangle"
            case .imbalance: "arrow.up.arrow.down"
            case .vertex: "ruler"
            case .oblique: "dial.medium"
            case .keratometry: "eye"
            case .blank: "circle.dashed"
            case .nearPD: "book"
            }
        }
    }

    @Environment(\.bottomBarInset) private var bottomBarInset

    var body: some View {
        List(Tool.allCases) { tool in
            NavigationLink {
                ToolScreen(tool: tool)
            } label: {
                Label(tool.rawValue, systemImage: tool.symbol)
            }
            .listRowBackground(Rectangle().fill(.ultraThinMaterial))
        }
        .safeAreaPadding(.bottom, bottomBarInset)
        .enveScreen()
        .navigationTitle("Calculators")
    }
}

private struct ToolScreen: View {
    let tool: CalculatorsView.Tool
    @Environment(\.bottomBarInset) private var bottomBarInset

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                switch tool {
                case .transpose: TransposeTool()
                case .prentice: PrenticeTool()
                case .imbalance: ImbalanceTool()
                case .vertex: VertexTool()
                case .oblique: ObliqueTool()
                case .keratometry: KeratometryTool()
                case .blank: BlankSizeTool()
                case .nearPD: NearPDTool()
                }
            }
            .padding()
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaPadding(.bottom, bottomBarInset)
        .enveScreen()
        .navigationTitle(tool.rawValue)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct NumberField: View {
    let label: String
    @Binding var value: Double
    var unit: String = ""
    @Environment(\.palette) private var palette

    var body: some View {
        HStack {
            Text(label).foregroundStyle(palette.text)
            Spacer()
            TextField(label, value: $value, format: .number.precision(.fractionLength(0...2)))
                .keyboardType(.numbersAndPunctuation)
                .multilineTextAlignment(.trailing)
                .font(.body.monospacedDigit())
                .frame(maxWidth: 110)
            if !unit.isEmpty {
                Text(unit).font(.subheadline).foregroundStyle(palette.secondaryText).frame(width: 28, alignment: .leading)
            }
        }
    }
}

private struct ResultPanel: View {
    let title: String
    let value: String
    var detail: String?
    @Environment(\.palette) private var palette

    var body: some View {
        Panel {
            VStack(alignment: .leading, spacing: 6) {
                Text(title.uppercased()).font(.caption.weight(.bold)).tracking(0.8).foregroundStyle(palette.accent)
                Text(value).font(.title2.weight(.bold).monospacedDigit()).foregroundStyle(palette.text)
                if let detail {
                    Text(detail).font(.footnote).foregroundStyle(palette.secondaryText)
                }
            }
        }
    }
}

private struct InputPanel<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        Panel { VStack(spacing: 14) { content } }
    }
}

private func rxString(_ rx: SpheroCylinder) -> String {
    "\(OpticsMath.formatPower(rx.sphere)) \(OpticsMath.formatPower(rx.cylinder)) × \(String(format: "%03d", rx.axis))"
}

private struct TransposeTool: View {
    @State private var sphere = -2.00
    @State private var cylinder = -1.50
    @State private var axis = 180.0

    var body: some View {
        let rx = SpheroCylinder(sphere: sphere, cylinder: cylinder, axis: Int(axis))
        let transposed = OpticsMath.transpose(rx)
        InputPanel {
            NumberField(label: "Sphere", value: $sphere, unit: "D")
            NumberField(label: "Cylinder", value: $cylinder, unit: "D")
            NumberField(label: "Axis", value: $axis, unit: "°")
        }
        ResultPanel(
            title: "Transposed",
            value: rxString(transposed),
            detail: "New sphere = sphere + cyl. Flip the cylinder sign. Rotate axis 90°."
        )
        ResultPanel(
            title: "Spherical Equivalent",
            value: OpticsMath.formatPower(OpticsMath.sphericalEquivalent(sphere: sphere, cylinder: cylinder)),
            detail: "SE = sphere + ½ cylinder"
        )
    }
}

private struct PrenticeTool: View {
    @State private var power = 4.00
    @State private var decentration = 5.0

    var body: some View {
        InputPanel {
            NumberField(label: "Lens power", value: $power, unit: "D")
            NumberField(label: "Decentration", value: $decentration, unit: "mm")
        }
        ResultPanel(
            title: "Induced Prism",
            value: String(format: "%.2f Δ", OpticsMath.prenticePrism(decentrationMM: decentration, power: power)),
            detail: "Δ = c × F, with c in centimeters. Plus lenses: base toward the direction of decentration. Minus lenses: base opposite."
        )
    }
}

private struct ImbalanceTool: View {
    @State private var right = 2.00
    @State private var left = -1.00
    @State private var drop = 10.0

    var body: some View {
        let rPrism = OpticsMath.prenticePrism(decentrationMM: drop, power: right)
        let lPrism = OpticsMath.prenticePrism(decentrationMM: drop, power: left)
        let sameDirection = (right >= 0) == (left >= 0)
        let imbalance = sameDirection ? abs(rPrism - lPrism) : rPrism + lPrism
        InputPanel {
            NumberField(label: "OD vertical power", value: $right, unit: "D")
            NumberField(label: "OS vertical power", value: $left, unit: "D")
            NumberField(label: "Reading drop", value: $drop, unit: "mm")
        }
        ResultPanel(
            title: "Vertical Imbalance",
            value: String(format: "%.2f Δ", imbalance),
            detail: String(format: "OD %.2fΔ, OS %.2fΔ. Same base direction → subtract; opposite → add. Use the power in the 90° meridian.", rPrism, lPrism)
        )
    }
}

private struct VertexTool: View {
    @State private var power = -6.00
    @State private var fitted = 12.0
    @State private var target = 0.0

    var body: some View {
        let compensated = OpticsMath.compensatedPower(power, moveMM: fitted - target)
        InputPanel {
            NumberField(label: "Rx power", value: $power, unit: "D")
            NumberField(label: "Refracted vertex", value: $fitted, unit: "mm")
            NumberField(label: "New vertex", value: $target, unit: "mm")
        }
        ResultPanel(
            title: "Compensated Power",
            value: OpticsMath.formatPower(compensated),
            detail: "Rounded to nearest 0.25: \(OpticsMath.formatPower(OpticsMath.roundToQuarter(compensated))). Fc = F ÷ (1 − dF), d in meters. Use 0 mm for a contact lens. Significant above ±4.00 D."
        )
    }
}

private struct ObliqueTool: View {
    @State private var sphere = 1.00
    @State private var cylinder = -2.00
    @State private var axis = 90.0
    @State private var meridian = 180.0

    var body: some View {
        let rx = SpheroCylinder(sphere: sphere, cylinder: cylinder, axis: Int(axis))
        InputPanel {
            NumberField(label: "Sphere", value: $sphere, unit: "D")
            NumberField(label: "Cylinder", value: $cylinder, unit: "D")
            NumberField(label: "Axis", value: $axis, unit: "°")
            NumberField(label: "Meridian", value: $meridian, unit: "°")
        }
        ResultPanel(
            title: "Power in Meridian",
            value: OpticsMath.formatPower(OpticsMath.obliquePower(rx, meridian: Int(meridian))),
            detail: "F = S + C × sin²θ, θ = angle between the meridian and the cylinder axis. Full cylinder power lies 90° from the axis."
        )
    }
}

private struct KeratometryTool: View {
    @State private var radius = 7.80
    @State private var flatK = 43.00
    @State private var baseCurve = 7.70

    var body: some View {
        InputPanel {
            NumberField(label: "Radius", value: $radius, unit: "mm")
        }
        ResultPanel(
            title: "Keratometric Power",
            value: String(format: "%.2f D", OpticsMath.keratometricDiopters(radiusMM: radius)),
            detail: "K (D) = 337.5 ÷ r (mm), using the keratometric index 1.3375."
        )
        InputPanel {
            NumberField(label: "Flat K", value: $flatK, unit: "D")
            NumberField(label: "Base curve", value: $baseCurve, unit: "mm")
        }
        let flatMM = OpticsMath.radiusMM(diopters: flatK)
        let tear = OpticsMath.tearLensPower(baseCurveMM: baseCurve, flatKMM: flatMM)
        ResultPanel(
            title: "Tear Lens",
            value: OpticsMath.formatPower(tear),
            detail: String(format: "Flat K = %.2f mm. Steeper than K → plus tear lens (SAM: steeper add minus). Flatter than K → minus tear lens (FAP: flatter add plus). Rule of thumb: 0.05 mm ≈ 0.25 D.", flatMM)
        )
    }
}

private struct BlankSizeTool: View {
    @State private var ed = 52.0
    @State private var a = 50.0
    @State private var dbl = 18.0
    @State private var pd = 62.0

    var body: some View {
        let framePD = a + dbl
        InputPanel {
            NumberField(label: "Effective diameter", value: $ed, unit: "mm")
            NumberField(label: "A (eye size)", value: $a, unit: "mm")
            NumberField(label: "DBL", value: $dbl, unit: "mm")
            NumberField(label: "Patient PD", value: $pd, unit: "mm")
        }
        ResultPanel(
            title: "Minimum Blank Size",
            value: String(format: "%.1f mm", OpticsMath.minimumBlankSize(effectiveDiameter: ed, framePD: framePD, patientPD: pd)),
            detail: String(format: "Frame PD = A + DBL = %.0f mm. Decentration per lens = %.1f mm. MBS = ED + (frame PD − PD) + 2 mm.", framePD, (framePD - pd) / 2)
        )
    }
}

private struct NearPDTool: View {
    @State private var pd = 64.0
    @State private var distance = 400.0

    var body: some View {
        InputPanel {
            NumberField(label: "Distance PD", value: $pd, unit: "mm")
            NumberField(label: "Working distance", value: $distance, unit: "mm")
        }
        ResultPanel(
            title: "Near PD",
            value: String(format: "%.1f mm", OpticsMath.nearPD(distancePD: pd, workingDistanceMM: distance)),
            detail: "Near PD = PD × d ÷ (d + 27), where 27 mm ≈ vertex distance + distance to the eye's center of rotation. Rule of thumb: about 3–4 mm less than distance PD at 40 cm."
        )
    }
}
