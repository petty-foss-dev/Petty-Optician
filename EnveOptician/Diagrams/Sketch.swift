import SwiftUI

/// Canvas drawing helpers in unit coordinates: x and y run 0…1 across the canvas.
struct Sketch {
    let ctx: GraphicsContext
    let size: CGSize
    let palette: ColorSet

    let ray = Color(red: 0.22, green: 0.56, blue: 0.96)
    let tear = Color(red: 0.35, green: 0.78, blue: 1.0)
    var ink: Color { palette.text }
    var muted: Color { palette.secondaryText }
    var accent: Color { palette.accent }
    var fontSize: CGFloat { max(9, min(15, size.width / 30)) }
    var stroke: CGFloat { max(1.2, size.width / 260) }

    func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * size.width, y: y * size.height) }
    func w(_ v: CGFloat) -> CGFloat { v * size.width }
    func h(_ v: CGFloat) -> CGFloat { v * size.height }

    func stroke(_ path: Path, _ color: Color, _ width: CGFloat? = nil, dash: [CGFloat] = []) {
        ctx.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: width ?? stroke, lineCap: .round, lineJoin: .round, dash: dash))
    }

    func fill(_ path: Path, _ color: Color) {
        ctx.fill(path, with: .color(color))
    }

    func fill(_ path: Path, clippedTo clip: Path, _ color: Color) {
        var clipped = ctx
        clipped.clip(to: clip)
        clipped.fill(path, with: .color(color))
    }

    func line(_ a: CGPoint, _ b: CGPoint, _ color: Color, _ width: CGFloat? = nil, dash: [CGFloat] = []) {
        stroke(Path { $0.move(to: a); $0.addLine(to: b) }, color, width, dash: dash)
    }

    func polyline(_ points: [CGPoint], _ color: Color, _ width: CGFloat? = nil, dash: [CGFloat] = []) {
        stroke(Path { $0.addLines(points) }, color, width, dash: dash)
    }

    func arrow(_ a: CGPoint, _ b: CGPoint, _ color: Color, _ width: CGFloat? = nil, dash: [CGFloat] = []) {
        line(a, b, color, width, dash: dash)
        let angle = atan2(b.y - a.y, b.x - a.x)
        let head = max(6, size.width / 55)
        var path = Path()
        path.move(to: b)
        path.addLine(to: CGPoint(x: b.x - head * cos(angle - .pi / 7), y: b.y - head * sin(angle - .pi / 7)))
        path.addLine(to: CGPoint(x: b.x - head * cos(angle + .pi / 7), y: b.y - head * sin(angle + .pi / 7)))
        path.closeSubpath()
        fill(path, color)
    }

    /// Measurement line with arrowheads at both ends and a centered label.
    func dimension(_ a: CGPoint, _ b: CGPoint, _ text: String, color: Color? = nil, labelBelow: Bool = false) {
        let c = color ?? accent
        let mid = CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
        arrow(mid, a, c, stroke * 0.8)
        arrow(mid, b, c, stroke * 0.8)
        if labelBelow {
            label(text, at: CGPoint(x: mid.x, y: mid.y + fontSize * 0.4), color: c, weight: .bold, anchor: .top)
        } else {
            label(text, at: mid, color: c, weight: .bold, plate: true)
        }
    }

    func label(
        _ text: String,
        at point: CGPoint,
        color: Color? = nil,
        scale: CGFloat = 1,
        weight: Font.Weight = .medium,
        anchor: UnitPoint = .center,
        plate: Bool = false
    ) {
        let resolved = ctx.resolve(
            Text(text)
                .font(.system(size: fontSize * scale, weight: weight))
                .foregroundStyle(color ?? ink)
        )
        if plate {
            let s = resolved.measure(in: size)
            let rect = CGRect(x: point.x - s.width * anchor.x - 3, y: point.y - s.height * anchor.y - 1, width: s.width + 6, height: s.height + 2)
            fill(Path(roundedRect: rect, cornerRadius: 4), palette.background.opacity(0.9))
        }
        ctx.draw(resolved, at: point, anchor: anchor)
    }

    /// Label with a leader line pointing at `target`.
    func callout(_ text: String, at point: CGPoint, to target: CGPoint, anchor: UnitPoint) {
        line(point, target, muted.opacity(0.7), stroke * 0.7)
        fill(circle(target, w(0.006)), muted)
        label(text, at: point, scale: 0.9, anchor: anchor, plate: true)
    }

    func circle(_ center: CGPoint, _ radius: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
    }

    func ellipse(_ center: CGPoint, width: CGFloat, height: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: center.x - width / 2, y: center.y - height / 2, width: width, height: height))
    }

    /// Point on a circle; degrees measured clockwise from +x (screen coordinates).
    func onCircle(_ center: CGPoint, _ radius: CGFloat, _ degrees: CGFloat) -> CGPoint {
        let t = degrees * .pi / 180
        return CGPoint(x: center.x + radius * cos(t), y: center.y + radius * sin(t))
    }

    func arc(_ center: CGPoint, _ radius: CGFloat, from start: CGFloat, to end: CGFloat) -> [CGPoint] {
        stride(from: start, through: end, by: 2).map { onCircle(center, radius, $0) }
    }

    func quad(_ p0: CGPoint, _ c: CGPoint, _ p1: CGPoint, _ t: CGFloat) -> CGPoint {
        let u = 1 - t
        return CGPoint(
            x: u * u * p0.x + 2 * u * t * c.x + t * t * p1.x,
            y: u * u * p0.y + 2 * u * t * c.y + t * t * p1.y
        )
    }

    func quadPoints(_ p0: CGPoint, _ c: CGPoint, _ p1: CGPoint, from a: CGFloat = 0, to b: CGFloat = 1) -> [CGPoint] {
        stride(from: a, through: b, by: (b - a) / 40).map { quad(p0, c, p1, $0) }
    }

    /// Small prism glyph; `baseDown` puts the base at the bottom.
    func prismGlyph(at q: CGPoint, size s: CGFloat, baseDown: Bool) {
        var path = Path()
        let apexY = baseDown ? q.y - s / 2 : q.y + s / 2
        let baseY = baseDown ? q.y + s / 2 : q.y - s / 2
        path.move(to: CGPoint(x: q.x, y: apexY))
        path.addLine(to: CGPoint(x: q.x - s * 0.45, y: baseY))
        path.addLine(to: CGPoint(x: q.x + s * 0.45, y: baseY))
        path.closeSubpath()
        fill(path, ray.opacity(0.25))
        stroke(path, ray)
        line(CGPoint(x: q.x - s * 0.45, y: baseY), CGPoint(x: q.x + s * 0.45, y: baseY), accent, stroke * 2.2)
    }
}
