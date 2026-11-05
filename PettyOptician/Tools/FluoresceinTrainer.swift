import SwiftUI

enum FluoresceinPattern: String, CaseIterable, Identifiable, Sendable {
    case alignment, apicalClearance, apicalBearing, withTheRule, againstTheRule, excessiveEdge, insufficientEdge

    var id: String { rawValue }

    var title: String {
        switch self {
        case .alignment: "Alignment (ideal)"
        case .apicalClearance: "Steep: apical clearance"
        case .apicalBearing: "Flat: apical bearing"
        case .withTheRule: "Spherical lens on WTR cornea"
        case .againstTheRule: "Spherical lens on ATR cornea"
        case .excessiveEdge: "Excessive edge clearance"
        case .insufficientEdge: "Insufficient edge clearance"
        }
    }

    var signs: String {
        switch self {
        case .alignment: "Thin, even, light green across the optic zone, with a slightly brighter band of edge clearance at the periphery."
        case .apicalClearance: "Bright central pool, a dark ring of mid-peripheral bearing, and little or no edge clearance (peripheral seal-off)."
        case .apicalBearing: "Dark central touch, fluorescein increasing toward the periphery, and a wide, bright band of excessive edge clearance. The lens often decenters."
        case .withTheRule: "A horizontal band of bearing along the flat horizontal meridian with pooling above and below: the dumbbell pattern."
        case .againstTheRule: "A vertical band of bearing along the flat vertical meridian with pooling nasally and temporally."
        case .excessiveEdge: "Even central alignment, but a very wide, bright peripheral band where the edge stands off the cornea."
        case .insufficientEdge: "Central alignment, but the periphery is dark with no bright edge ring: the edge is sealed against the cornea."
        }
    }

    var action: String {
        switch self {
        case .alignment: "No base curve change. Confirm good centration and movement with the blink."
        case .apicalClearance: "Flatten the base curve (longer radius). A steep fit limits tear exchange and traps debris."
        case .apicalBearing: "Steepen the base curve (shorter radius). Central bearing can stain and flatten (distort) the cornea."
        case .withTheRule, .againstTheRule: "Acceptable with low to moderate corneal toricity; at about 2.50 D or more, consider a bitoric (back-surface toric) design."
        case .excessiveEdge: "Reduce edge lift: steepen the peripheral curve radius or narrow its width."
        case .insufficientEdge: "Increase edge lift: flatten the peripheral curve radius or widen it, so tears can exchange."
        }
    }

    /// Relative tear-layer thickness (0 = touch, 1 = heavy pooling) at a point in lens coordinates, where the edge is radius 1.
    nonisolated func tearThickness(x: Double, y: Double) -> Double {
        let rho = (x * x + y * y).squareRoot()
        func ramp(_ a: Double, _ b: Double, _ v: Double) -> Double {
            let t = min(1, max(0, (v - a) / (b - a)))
            return t * t * (3 - 2 * t)
        }
        let normalEdge = ramp(0.8, 0.95, rho) * 0.7
        return switch self {
        case .alignment: 0.28 + normalEdge
        case .apicalClearance: 0.95 * (1 - ramp(0.05, 0.6, rho)) + 0.04 + ramp(0.94, 1, rho) * 0.2
        case .apicalBearing: 0.03 + ramp(0.2, 0.7, rho) * 0.55 + ramp(0.62, 0.82, rho) * 0.45
        case .withTheRule: 0.04 + ramp(0.12, 0.8, abs(y)) * 0.85 + normalEdge * 0.6
        case .againstTheRule: 0.04 + ramp(0.12, 0.8, abs(x)) * 0.85 + normalEdge * 0.6
        case .excessiveEdge: 0.28 + ramp(0.62, 0.76, rho) * 0.75
        case .insufficientEdge: 0.03 + 0.25 * (1 - ramp(0.78, 0.9, rho))
        }
    }
}

struct FluoresceinTrainerView: View {
    @State private var pattern = FluoresceinPattern.allCases.randomElement()!
    @State private var choices: [FluoresceinPattern] = []
    @State private var picked: FluoresceinPattern?
    @State private var image: CGImage?
    @State private var correctCount = 0
    @State private var attempts = 0
    @Environment(\.palette) private var palette

    private static let sources = [
        SourceLink(title: "GP Lens Institute: Fluorescein Pattern Identification Guide", url: URL(string: "https://gpli.info/fluorescein-id-guide/")!),
        SourceLink(title: "Contact Lens Spectrum: Unmasking the RGP Fit With Fluorescein", url: URL(string: "https://clspectrum.com/issues/1998/october/unmasking-the-rgp-fit-with-fluorescein/")!),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Group {
                    if let image {
                        Image(decorative: image, scale: 1)
                            .resizable()
                            .interpolation(.high)
                            .blur(radius: 1.2)
                            .clipShape(Circle())
                    } else {
                        Circle().fill(.black)
                    }
                }
                .aspectRatio(1, contentMode: .fit)
                .frame(maxWidth: 340)
                .frame(maxWidth: .infinity)
                .accessibilityLabel("Fluorescein pattern under cobalt blue light")

                Text("A spherical GP lens under cobalt blue light. Which fit is this?")
                    .font(.headline)

                VStack(spacing: 10) {
                    ForEach(choices) { choice in
                        Button { answer(choice) } label: {
                            HStack {
                                Text(choice.title).multilineTextAlignment(.leading)
                                Spacer()
                                if let picked {
                                    if choice == pattern {
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
                            Text(pattern.title).font(.headline)
                            Label { Text(pattern.signs) } icon: { Image(systemName: "eye") }
                                .font(.subheadline)
                            Label { Text(pattern.action) } icon: { Image(systemName: "wrench.adjustable") }
                                .font(.subheadline)
                            Button("Next Pattern", action: next)
                                .buttonStyle(.borderedProminent)
                                .accessibilityIdentifier("fluorescein.next")
                        }
                    }
                }

                Text("Score \(correctCount) / \(attempts)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(palette.secondaryText)

                Panel {
                    VStack(alignment: .leading, spacing: 10) {
                        RichText(text: "**Bright green** = pooling (thick tear layer). **Dark** = touch or bearing. **Thin, even green** = alignment. Judge the center, the mid-periphery and the edge band separately. Simulated patterns; real ones vary with fluorescein amount and lens material.")
                            .font(.caption)
                        SourceList(sources: Self.sources)
                    }
                }
            }
            .padding()
        }
        .pettyScreen()
        .navigationTitle("Fluorescein Patterns")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { if choices.isEmpty { load(pattern) } }
    }

    private func answer(_ choice: FluoresceinPattern) {
        picked = choice
        attempts += 1
        if choice == pattern { correctCount += 1 }
    }

    private func next() {
        load(FluoresceinPattern.allCases.filter { $0 != pattern }.randomElement()!)
    }

    private func load(_ newPattern: FluoresceinPattern) {
        pattern = newPattern
        picked = nil
        choices = Self.choices(for: newPattern)
        image = FluoresceinRenderer.render(newPattern, variation: .random())
    }

    nonisolated static func choices(for pattern: FluoresceinPattern) -> [FluoresceinPattern] {
        (FluoresceinPattern.allCases.filter { $0 != pattern }.shuffled().prefix(3) + [pattern]).shuffled()
    }
}

enum FluoresceinRenderer {
    struct Variation: Sendable {
        var offsetX = 0.0
        var offsetY = 0.0
        var rotation = 0.0
        var brightness = 1.0
        var seed: UInt64 = 1

        static func random() -> Variation {
            Variation(
                offsetX: .random(in: -0.05...0.05),
                offsetY: .random(in: -0.05...0.05),
                rotation: .random(in: -12...12) * .pi / 180,
                brightness: .random(in: 0.88...1.08),
                seed: .random(in: 1...UInt64.max)
            )
        }
    }

    nonisolated static func render(_ pattern: FluoresceinPattern, variation: Variation, size: Int = 260) -> CGImage? {
        var pixels = [UInt8](repeating: 0, count: size * size * 4)
        var rng = variation.seed
        let lensRadius = 0.72
        let lensDrop = pattern == .apicalBearing ? 0.1 : 0
        let cosR = cos(variation.rotation), sinR = sin(variation.rotation)

        for py in 0..<size {
            for px in 0..<size {
                let fx = (Double(px) + 0.5) / Double(size) * 2 - 1
                let fy = (Double(py) + 0.5) / Double(size) * 2 - 1
                let lx = (fx - variation.offsetX) / lensRadius
                let ly = (fy - variation.offsetY - lensDrop) / lensRadius
                let rho = (lx * lx + ly * ly).squareRoot()

                let t: Double = if rho <= 1 {
                    pattern.tearThickness(x: lx * cosR + ly * sinR, y: -lx * sinR + ly * cosR) * variation.brightness
                } else if rho < 1.05 {
                    0.55
                } else {
                    0.1
                }
                rng = rng &* 6364136223846793005 &+ 1442695040888963407
                let noise = Double(rng >> 40) / Double(1 << 24) * 0.06 - 0.03
                let v = min(1, max(0, t + noise))
                let edgeShade = abs(rho - 1) < 0.012 ? 0.55 : 1

                let i = (py * size + px) * 4
                pixels[i] = UInt8(min(255, (6 + 70 * v * v) * edgeShade))
                pixels[i + 1] = UInt8(min(255, (10 + 240 * pow(v, 0.8)) * edgeShade))
                pixels[i + 2] = UInt8(min(255, (70 + 40 * v) * edgeShade))
                pixels[i + 3] = 255
            }
        }

        guard let provider = CGDataProvider(data: Data(pixels) as CFData) else { return nil }
        return CGImage(
            width: size, height: size, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: size * 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue),
            provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent
        )
    }
}
