import SwiftUI

/// Immediate-execution scientific calculator like the one Prometric shows on screen; trig works in degrees.
struct CalculatorEngine: Sendable {
    enum Operation: String, Sendable { case add = "+", subtract = "−", multiply = "×", divide = "÷" }
    enum Function: String, Sendable { case sqrt = "√", square = "x²", reciprocal = "1/x", sin, cos, tan }

    private(set) var display = "0"
    private var accumulator: Double?
    private var pending: Operation?
    private var startsNewEntry = true

    var value: Double { Double(display) ?? .nan }

    mutating func digit(_ d: String) {
        if startsNewEntry || display == "0" {
            display = d == "." ? "0." : d
            startsNewEntry = false
        } else if d != "." || !display.contains(".") {
            display += d
        }
    }

    mutating func operation(_ op: Operation) {
        if !startsNewEntry || accumulator == nil { evaluatePending() }
        accumulator = value
        pending = op
        startsNewEntry = true
    }

    mutating func equals() {
        evaluatePending()
        pending = nil
        accumulator = nil
        startsNewEntry = true
    }

    mutating func apply(_ function: Function) {
        let x = value
        let radians = x * .pi / 180
        let result: Double = switch function {
        case .sqrt: x.squareRoot()
        case .square: x * x
        case .reciprocal: 1 / x
        case .sin: sin(radians)
        case .cos: cos(radians)
        case .tan: tan(radians)
        }
        show(result)
        startsNewEntry = true
    }

    mutating func negate() {
        if display.hasPrefix("-") { display.removeFirst() } else if display != "0" { display = "-" + display }
    }

    mutating func clear() { self = CalculatorEngine() }

    private mutating func evaluatePending() {
        guard let pending, let accumulator else { return }
        let x = value
        let result: Double = switch pending {
        case .add: accumulator + x
        case .subtract: accumulator - x
        case .multiply: accumulator * x
        case .divide: accumulator / x
        }
        show(result)
        self.accumulator = result
    }

    private mutating func show(_ result: Double) {
        guard result.isFinite else {
            display = "Error"
            return
        }
        let rounded = (result * 1e10).rounded() / 1e10
        display = rounded == rounded.rounded() && abs(rounded) < 1e15
            ? String(Int64(rounded))
            : String(format: "%.10g", rounded)
    }
}

struct ExamCalculatorView: View {
    @State private var engine = CalculatorEngine()
    @Environment(\.palette) private var palette

    private let rows: [[Key]] = [
        [.function(.sin), .function(.cos), .function(.tan), .function(.reciprocal)],
        [.clear, .negate, .function(.sqrt), .function(.square)],
        [.digit("7"), .digit("8"), .digit("9"), .operation(.divide)],
        [.digit("4"), .digit("5"), .digit("6"), .operation(.multiply)],
        [.digit("1"), .digit("2"), .digit("3"), .operation(.subtract)],
        [.digit("0"), .digit("."), .equals, .operation(.add)],
    ]

    private enum Key: Hashable {
        case digit(String), operation(CalculatorEngine.Operation), function(CalculatorEngine.Function), clear, negate, equals

        var label: String {
            switch self {
            case .digit(let d): d
            case .operation(let op): op.rawValue
            case .function(let f): f.rawValue
            case .clear: "C"
            case .negate: "±"
            case .equals: "="
            }
        }
    }

    var body: some View {
        VStack(spacing: 10) {
            Text(engine.display)
                .font(.system(size: 40, weight: .medium, design: .rounded).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.4)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.horizontal, 8)
                .accessibilityIdentifier("calculator.display")
            ForEach(rows, id: \.self) { row in
                HStack(spacing: 10) {
                    ForEach(row, id: \.self) { key in
                        Button { press(key) } label: {
                            Text(key.label)
                                .font(.title3.weight(.semibold))
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .foregroundStyle(isAccent(key) ? palette.onAccent : palette.text)
                                .background(RoundedRectangle(cornerRadius: 12).fill(isAccent(key) ? palette.accent : palette.cardBackground))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            Text("Trig functions use degrees.")
                .font(.caption)
                .foregroundStyle(palette.secondaryText)
        }
        .padding()
        .background(palette.background.ignoresSafeArea())
    }

    private func isAccent(_ key: Key) -> Bool {
        switch key {
        case .operation, .equals: true
        default: false
        }
    }

    private func press(_ key: Key) {
        switch key {
        case .digit(let d): engine.digit(d)
        case .operation(let op): engine.operation(op)
        case .function(let f): engine.apply(f)
        case .clear: engine.clear()
        case .negate: engine.negate()
        case .equals: engine.equals()
        }
    }
}
