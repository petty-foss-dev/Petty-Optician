import SwiftUI

enum DiagramArt {
    static func aspectRatio(_ id: String) -> CGFloat {
        switch id {
        case "eye-anatomy": 1.6
        case "refractive-errors", "lens-forms", "multifocals", "fluorescein-patterns": 2.6
        case "optical-cross", "pal-layout": 1.6
        case "prism": 1.8
        case "prentice", "vertex-distance", "frame-adjustments": 2.2
        case "boxing-system": 2.1
        case "tear-lens": 2.4
        default: 1.6
        }
    }

    static func draw(_ id: String, in s: Sketch) {
        switch id {
        case "eye-anatomy": eyeAnatomy(s)
        case "refractive-errors": refractiveErrors(s)
        case "lens-forms": lensForms(s)
        case "optical-cross": opticalCross(s)
        case "prism": prism(s)
        case "prentice": prentice(s)
        case "vertex-distance": vertexDistance(s)
        case "boxing-system": boxingSystem(s)
        case "frame-adjustments": frameAdjustments(s)
        case "multifocals": multifocals(s)
        case "pal-layout": palLayout(s)
        case "tear-lens": tearLens(s)
        case "fluorescein-patterns": fluoresceinPatterns(s)
        default: s.label(id, at: s.p(0.5, 0.5), color: s.muted)
        }
    }

    // MARK: Anatomy & refraction

    private static func eyeAnatomy(_ s: Sketch) {
        let c = s.p(0.5, 0.5)
        let r = s.h(0.38)

        s.fill(s.circle(c, r), s.palette.secondaryText.opacity(0.06))
        s.polyline(s.arc(c, r * 0.93, from: 215, to: 505), Color.red.opacity(0.55), s.stroke * 1.6)
        s.polyline(s.arc(c, r, from: 215, to: 505), s.ink, s.stroke * 1.6)

        let corneaTop = s.onCircle(c, r, 145)
        let corneaBottom = s.onCircle(c, r, 215)
        let corneaControl = CGPoint(x: c.x - r * 1.45, y: c.y)
        s.stroke(Path { $0.move(to: corneaTop); $0.addQuadCurve(to: corneaBottom, control: corneaControl) }, s.ray, s.stroke * 1.8)

        let irisX = c.x - r * 0.78
        s.line(CGPoint(x: irisX, y: c.y - r * 0.56), CGPoint(x: irisX, y: c.y - r * 0.13), s.accent, s.stroke * 2.4)
        s.line(CGPoint(x: irisX, y: c.y + r * 0.13), CGPoint(x: irisX, y: c.y + r * 0.56), s.accent, s.stroke * 2.4)

        let lensCenter = CGPoint(x: c.x - r * 0.6, y: c.y)
        let lens = s.ellipse(lensCenter, width: r * 0.32, height: r * 0.78)
        s.fill(lens, s.ray.opacity(0.18))
        s.stroke(lens, s.ray)

        for sign in [-1.0, 1.0] {
            let body = s.ellipse(CGPoint(x: c.x - r * 0.68, y: c.y + sign * r * 0.66), width: r * 0.2, height: r * 0.12)
            s.fill(body, s.muted.opacity(0.45))
        }

        let macula = s.onCircle(c, r * 0.93, 4)
        s.fill(s.circle(macula, s.w(0.008)), Color.red.opacity(0.8))

        let nerveTop = s.onCircle(c, r, -26)
        let nerveBottom = s.onCircle(c, r, -10)
        let nerveEnd = c.x + r * 1.18
        s.line(nerveTop, CGPoint(x: nerveEnd, y: nerveTop.y), s.ink, s.stroke * 1.4)
        s.line(nerveBottom, CGPoint(x: nerveEnd, y: nerveBottom.y), s.ink, s.stroke * 1.4)

        s.label("Vitreous", at: CGPoint(x: c.x + r * 0.15, y: c.y), color: s.muted, scale: 0.9)
        s.callout("Cornea", at: s.p(0.03, 0.14), to: CGPoint(x: c.x - r * 1.18, y: c.y - r * 0.32), anchor: .leading)
        s.callout("Aqueous humor", at: s.p(0.03, 0.32), to: CGPoint(x: c.x - r * 1.0, y: c.y - r * 0.22), anchor: .leading)
        s.callout("Pupil", at: s.p(0.03, 0.5), to: CGPoint(x: irisX, y: c.y), anchor: .leading)
        s.callout("Iris", at: s.p(0.03, 0.86), to: CGPoint(x: irisX, y: c.y + r * 0.4), anchor: .leading)
        s.callout("Lens", at: s.p(0.36, 0.05), to: CGPoint(x: lensCenter.x, y: c.y - r * 0.3), anchor: .center)
        s.callout("Ciliary body", at: s.p(0.36, 0.96), to: CGPoint(x: c.x - r * 0.68, y: c.y + r * 0.66), anchor: .center)
        s.callout("Sclera", at: s.p(0.97, 0.06), to: s.onCircle(c, r, -62), anchor: .trailing)
        s.callout("Optic nerve", at: s.p(0.97, 0.22), to: CGPoint(x: nerveEnd - s.w(0.01), y: (nerveTop.y + nerveBottom.y) / 2), anchor: .trailing)
        s.callout("Macula / fovea", at: s.p(0.97, 0.66), to: macula, anchor: .trailing)
        s.callout("Retina", at: s.p(0.97, 0.92), to: s.onCircle(c, r * 0.93, 58), anchor: .trailing)
    }

    private static func refractiveErrors(_ s: Sketch) {
        let cases: [(title: String, focusFactor: CGFloat)] = [
            ("Emmetropia", 0.95),
            ("Myopia\ncorrect with minus", 0.35),
            ("Hyperopia\ncorrect with plus", 1.35)
        ]
        for (i, item) in cases.enumerated() {
            let cx = s.w((CGFloat(i) + 0.5) / 3)
            let c = CGPoint(x: cx - s.w(0.01), y: s.h(0.42))
            let r = s.h(0.28)
            s.fill(s.circle(c, r), s.palette.secondaryText.opacity(0.06))
            s.stroke(s.circle(c, r), s.ink)
            s.polyline(s.arc(c, r * 0.94, from: -50, to: 50), Color.red.opacity(0.6), s.stroke * 1.4)

            let retinaX = c.x + r * 0.94
            let focus = CGPoint(x: c.x + r * item.focusFactor, y: c.y)
            for offset in [-0.5, 0, 0.5] as [CGFloat] {
                let dy = r * offset
                let start = CGPoint(x: cx - s.w(0.15), y: c.y + dy)
                let entry = CGPoint(x: c.x - sqrt(r * r - dy * dy), y: c.y + dy)
                s.line(start, entry, s.ray)
                let t = (retinaX - entry.x) / (focus.x - entry.x)
                let atRetina = CGPoint(x: entry.x + t * (focus.x - entry.x), y: entry.y + t * (focus.y - entry.y))
                s.line(entry, atRetina, s.ray)
                if item.focusFactor > 1 {
                    s.line(atRetina, focus, s.ray.opacity(0.6), dash: [3, 3])
                }
            }
            s.fill(s.circle(focus, s.w(0.006)), s.accent)
            s.label(item.title, at: CGPoint(x: cx, y: s.h(0.86)), weight: .semibold)
        }
    }

    private static func lensForms(_ s: Sketch) {
        let forms: [(name: String, gap: CGFloat, front: CGFloat, back: CGFloat)] = [
            ("Biconvex", 0.008, 0.045, 0.045),
            ("Plano-\nconvex", 0.008, 0.08, 0),
            ("Plus\nmeniscus", 0.008, 0.10, -0.05),
            ("Minus\nmeniscus", 0.06, 0.05, -0.10),
            ("Plano-\nconcave", 0.06, 0, -0.07),
            ("Biconcave", 0.06, -0.035, -0.035)
        ]
        let top = s.h(0.12), bottom = s.h(0.62), mid = (top + bottom) / 2
        for (i, form) in forms.enumerated() {
            let cx = s.w((CGFloat(i) + 0.5) / 6)
            let xl = cx - s.w(form.gap / 2), xr = cx + s.w(form.gap / 2)
            var path = Path()
            path.move(to: CGPoint(x: xl, y: top))
            path.addQuadCurve(to: CGPoint(x: xl, y: bottom), control: CGPoint(x: xl - s.w(form.front), y: mid))
            path.addLine(to: CGPoint(x: xr, y: bottom))
            path.addQuadCurve(to: CGPoint(x: xr, y: top), control: CGPoint(x: xr + s.w(form.back), y: mid))
            path.closeSubpath()
            s.fill(path, (i < 3 ? s.accent : s.ray).opacity(0.25))
            s.stroke(path, i < 3 ? s.accent : s.ray)
            s.label(form.name, at: CGPoint(x: cx, y: s.h(0.76)), scale: 0.85)
        }
        s.line(s.p(0.03, 0.9), s.p(0.47, 0.9), s.accent.opacity(0.5))
        s.line(s.p(0.53, 0.9), s.p(0.97, 0.9), s.ray.opacity(0.5))
        s.label("Plus — thicker center", at: s.p(0.25, 0.9), color: s.accent, scale: 0.9, weight: .bold, plate: true)
        s.label("Minus — thicker edge", at: s.p(0.75, 0.9), color: s.ray, scale: 0.9, weight: .bold, plate: true)
    }

    // MARK: Optics

    private static func opticalCross(_ s: Sketch) {
        let c = s.p(0.42, 0.48)
        let r = s.h(0.34)
        s.fill(s.circle(c, r), s.ray.opacity(0.08))
        s.stroke(s.circle(c, r), s.muted)
        s.line(CGPoint(x: c.x - r, y: c.y), CGPoint(x: c.x + r, y: c.y), s.accent, s.stroke * 2.4)
        s.line(CGPoint(x: c.x, y: c.y - r), CGPoint(x: c.x, y: c.y + r), s.ray, s.stroke * 2.4)
        s.label("180°: −2.00", at: CGPoint(x: c.x + r + s.w(0.02), y: c.y), color: s.accent, weight: .bold, anchor: .leading)
        s.label("90°: −3.00", at: CGPoint(x: c.x, y: c.y - r - s.h(0.04)), color: s.ray, weight: .bold, anchor: .bottom)
        s.label("Rx  −2.00 −1.00 × 180", at: s.p(0.42, 0.94), weight: .semibold)
    }

    private static func prism(_ s: Sketch) {
        let apex = s.p(0.45, 0.12), baseL = s.p(0.3, 0.85), baseR = s.p(0.6, 0.85)
        var triangle = Path()
        triangle.move(to: apex)
        triangle.addLine(to: baseL)
        triangle.addLine(to: baseR)
        triangle.closeSubpath()
        s.fill(triangle, s.ray.opacity(0.15))
        s.stroke(triangle, s.ray)
        s.line(baseL, baseR, s.accent, s.stroke * 2.4)

        let object = s.p(0.06, 0.62)
        let entry = s.p(0.3675, 0.5215)
        let exit = s.p(0.555, 0.631)
        let eye = s.p(0.88, 0.78)
        let image = s.p(0.06, 0.404)
        s.line(object, entry, s.ray)
        s.line(entry, exit, s.ray)
        s.arrow(exit, CGPoint(x: eye.x - s.w(0.03), y: eye.y - s.h(0.014)), s.ray)
        s.line(exit, image, s.muted, dash: [4, 4])

        s.fill(s.circle(object, s.w(0.012)), s.accent)
        s.stroke(s.circle(image, s.w(0.012)), s.accent, dash: [3, 3])
        s.stroke(s.ellipse(eye, width: s.w(0.05), height: s.h(0.12)), s.ink)
        s.fill(s.circle(CGPoint(x: eye.x - s.w(0.012), y: eye.y), s.w(0.007)), s.ink)

        s.label("Apex", at: CGPoint(x: apex.x, y: apex.y - s.h(0.03)), weight: .semibold, anchor: .bottom)
        s.label("Base", at: CGPoint(x: (baseL.x + baseR.x) / 2, y: baseL.y + s.h(0.03)), color: s.accent, weight: .bold, anchor: .top)
        s.label("Object", at: CGPoint(x: object.x, y: object.y + s.h(0.05)), scale: 0.85, anchor: .top)
        s.label("Image", at: CGPoint(x: image.x, y: image.y - s.h(0.05)), scale: 0.85, anchor: .bottom)
        s.label("Eye", at: CGPoint(x: eye.x, y: eye.y - s.h(0.09)), scale: 0.85, anchor: .bottom)
    }

    private static func prentice(_ s: Sketch) {
        let top = s.h(0.14), bottom = s.h(0.84), mid = (top + bottom) / 2
        let sight = s.h(0.32)

        for (cx, plus) in [(s.w(0.22), true), (s.w(0.7), false)] {
            var lens = Path()
            if plus {
                lens.move(to: CGPoint(x: cx - s.w(0.003), y: top))
                lens.addQuadCurve(to: CGPoint(x: cx - s.w(0.003), y: bottom), control: CGPoint(x: cx - s.w(0.07), y: mid))
                lens.addLine(to: CGPoint(x: cx + s.w(0.003), y: bottom))
                lens.addQuadCurve(to: CGPoint(x: cx + s.w(0.003), y: top), control: CGPoint(x: cx + s.w(0.07), y: mid))
            } else {
                lens.move(to: CGPoint(x: cx - s.w(0.03), y: top))
                lens.addQuadCurve(to: CGPoint(x: cx - s.w(0.03), y: bottom), control: CGPoint(x: cx + s.w(0.022), y: mid))
                lens.addLine(to: CGPoint(x: cx + s.w(0.03), y: bottom))
                lens.addQuadCurve(to: CGPoint(x: cx + s.w(0.03), y: top), control: CGPoint(x: cx - s.w(0.022), y: mid))
            }
            lens.closeSubpath()
            let tint = plus ? s.accent : s.ray
            s.fill(lens, tint.opacity(0.22))
            s.stroke(lens, tint)

            s.line(CGPoint(x: cx - s.w(0.14), y: mid), CGPoint(x: cx + s.w(0.12), y: mid), s.muted, dash: [4, 4])
            s.fill(s.circle(CGPoint(x: cx, y: mid), s.w(0.008)), s.ink)
            s.label("OC", at: CGPoint(x: cx - s.w(0.15), y: mid), scale: 0.85, weight: .bold, anchor: .trailing)

            s.line(CGPoint(x: cx - s.w(0.14), y: sight), CGPoint(x: cx + s.w(0.1), y: sight), s.ray.opacity(0.7))
            s.fill(s.circle(CGPoint(x: cx, y: sight), s.w(0.006)), s.ray)
            s.dimension(CGPoint(x: cx - s.w(0.1), y: sight), CGPoint(x: cx - s.w(0.1), y: mid), "c")
            s.prismGlyph(at: CGPoint(x: cx + s.w(0.15), y: sight), size: s.h(0.16), baseDown: plus)

            s.label(plus ? "Plus lens" : "Minus lens", at: CGPoint(x: cx, y: s.h(0.05)), weight: .bold)
            s.label(plus ? "base toward OC" : "base away from OC", at: CGPoint(x: cx + s.w(0.15), y: sight - s.h(0.11)), color: s.accent, scale: 0.85, weight: .semibold, anchor: .bottom)
        }
        s.label("Δ = c (cm) × F", at: s.p(0.5, 0.94), color: s.accent, weight: .bold)
    }

    private static func vertexDistance(_ s: Sketch) {
        let c = s.p(0.74, 0.48)
        let r = s.h(0.34)
        s.fill(s.circle(c, r), s.palette.secondaryText.opacity(0.06))
        s.polyline(s.arc(c, r, from: 215, to: 505), s.ink, s.stroke * 1.5)
        let corneaTop = s.onCircle(c, r, 145)
        let corneaBottom = s.onCircle(c, r, 215)
        let control = CGPoint(x: c.x - r * 1.45, y: c.y)
        s.stroke(Path { $0.move(to: corneaTop); $0.addQuadCurve(to: corneaBottom, control: control) }, s.ray, s.stroke * 1.8)
        let apexX = s.quad(corneaTop, control, corneaBottom, 0.5).x

        let lensBack = apexX - s.w(0.15)
        var lens = Path()
        lens.move(to: CGPoint(x: lensBack - s.w(0.012), y: s.h(0.14)))
        lens.addQuadCurve(to: CGPoint(x: lensBack - s.w(0.012), y: s.h(0.82)), control: CGPoint(x: lensBack - s.w(0.07), y: s.h(0.48)))
        lens.addLine(to: CGPoint(x: lensBack, y: s.h(0.82)))
        lens.addQuadCurve(to: CGPoint(x: lensBack, y: s.h(0.14)), control: CGPoint(x: lensBack - s.w(0.04), y: s.h(0.48)))
        lens.closeSubpath()
        s.fill(lens, s.accent.opacity(0.25))
        s.stroke(lens, s.accent)

        let backApex = lensBack - s.w(0.02)
        s.line(CGPoint(x: backApex, y: s.h(0.48)), CGPoint(x: backApex, y: s.h(0.84)), s.muted, dash: [3, 3])
        s.line(CGPoint(x: apexX, y: s.h(0.48)), CGPoint(x: apexX, y: s.h(0.84)), s.muted, dash: [3, 3])
        s.dimension(CGPoint(x: backApex, y: s.h(0.84)), CGPoint(x: apexX, y: s.h(0.84)), "vertex distance", labelBelow: true)
        s.label("Spectacle lens", at: CGPoint(x: lensBack - s.w(0.03), y: s.h(0.07)), weight: .semibold)
        s.label("Cornea", at: CGPoint(x: apexX, y: s.h(0.12)), color: s.ray, scale: 0.85, weight: .semibold)
    }

    // MARK: Frames & lenses

    private static func boxingSystem(_ s: Sketch) {
        let boxes = [CGRect(x: s.w(0.1), y: s.h(0.24), width: s.w(0.33), height: s.h(0.52)),
                     CGRect(x: s.w(0.57), y: s.h(0.24), width: s.w(0.33), height: s.h(0.52))]
        for box in boxes {
            let lens = Path(roundedRect: box, cornerRadius: box.height * 0.42, style: .continuous)
            s.fill(lens, s.ray.opacity(0.1))
            s.stroke(lens, s.ink, s.stroke * 2)
            s.stroke(Path(box), s.muted, dash: [5, 4])
            let gc = CGPoint(x: box.midX, y: box.midY)
            s.fill(s.circle(gc, s.w(0.007)), s.accent)
        }
        let left = boxes[0], right = boxes[1]
        s.stroke(Path { p in
            p.move(to: CGPoint(x: left.maxX - s.w(0.01), y: left.minY + s.h(0.1)))
            p.addQuadCurve(to: CGPoint(x: right.minX + s.w(0.01), y: right.minY + s.h(0.1)), control: CGPoint(x: s.w(0.5), y: left.minY - s.h(0.02)))
        }, s.ink, s.stroke * 2)

        s.label("GC", at: CGPoint(x: left.midX, y: left.midY + s.h(0.06)), color: s.accent, scale: 0.85, weight: .bold)
        s.dimension(CGPoint(x: left.minX, y: s.h(0.86)), CGPoint(x: left.maxX, y: s.h(0.86)), "A")
        s.dimension(CGPoint(x: s.w(0.05), y: left.minY), CGPoint(x: s.w(0.05), y: left.maxY), "B")
        s.dimension(CGPoint(x: left.maxX, y: s.h(0.62)), CGPoint(x: right.minX, y: s.h(0.62)), "DBL")
        let gc = CGPoint(x: right.midX, y: right.midY)
        let cornerRadius = right.height * 0.42
        let arcCenter = CGPoint(x: right.maxX - cornerRadius, y: right.minY + cornerRadius)
        let dx = arcCenter.x - gc.x, dy = arcCenter.y - gc.y
        let length = sqrt(dx * dx + dy * dy)
        let farthest = CGPoint(x: arcCenter.x + cornerRadius * dx / length, y: arcCenter.y + cornerRadius * dy / length)
        let opposite = CGPoint(x: 2 * gc.x - farthest.x, y: 2 * gc.y - farthest.y)
        s.dimension(opposite, farthest, "ED = 2 × longest radius")
        s.dimension(CGPoint(x: left.midX, y: s.h(0.1)), CGPoint(x: right.midX, y: s.h(0.1)), "A + DBL = frame PD")
    }

    private static func frameAdjustments(_ s: Sketch) {
        s.line(s.p(0.2, 0.12), s.p(0.2, 0.86), s.muted, dash: [4, 4])
        s.line(s.p(0.19, 0.18), s.p(0.25, 0.8), s.ink, s.stroke * 3.2)
        s.stroke(Path { p in
            p.move(to: s.p(0.195, 0.24))
            p.addLine(to: s.p(0.42, 0.24))
            p.addQuadCurve(to: s.p(0.45, 0.42), control: s.p(0.45, 0.25))
        }, s.ink, s.stroke * 1.6)
        s.stroke(Path { p in
            p.move(to: s.p(0.2, 0.62))
            p.addQuadCurve(to: s.p(0.235, 0.66), control: s.p(0.215, 0.66))
        }, s.accent, s.stroke * 1.4)
        s.label("tilt", at: s.p(0.255, 0.58), color: s.accent, scale: 0.85, weight: .bold, anchor: .leading)
        s.label("Side view", at: s.p(0.3, 0.05), color: s.muted, scale: 0.85)
        s.label("Pantoscopic tilt", at: s.p(0.3, 0.94), weight: .semibold)

        s.line(s.p(0.56, 0.34), s.p(0.94, 0.34), s.muted, dash: [4, 4])
        s.stroke(Path { p in
            p.move(to: s.p(0.58, 0.46))
            p.addQuadCurve(to: s.p(0.92, 0.46), control: s.p(0.75, 0.22))
        }, s.ink, s.stroke * 3.2)
        s.line(s.p(0.58, 0.46), s.p(0.6, 0.86), s.ink, s.stroke * 1.6)
        s.line(s.p(0.92, 0.46), s.p(0.9, 0.86), s.ink, s.stroke * 1.6)
        s.label("Top view", at: s.p(0.75, 0.05), color: s.muted, scale: 0.85)
        s.label("Face form (wrap)", at: s.p(0.75, 0.94), weight: .semibold)
    }

    private static func multifocals(_ s: Sketch) {
        let names = ["Flat-top (D-seg)", "Round seg", "Executive", "Trifocal"]
        for (i, name) in names.enumerated() {
            let c = CGPoint(x: s.w((CGFloat(i) + 0.5) / 4), y: s.h(0.42))
            let lensW = s.w(0.2), lensH = s.h(0.62)
            let lens = s.ellipse(c, width: lensW, height: lensH)
            s.fill(lens, s.ray.opacity(0.08))
            let segColor = s.accent.opacity(0.3)
            let segX = c.x - s.w(0.01)
            let r = s.w(0.036)

            switch i {
            case 0, 3:
                let lineY = c.y + s.h(i == 3 ? 0.04 : 0.07)
                let seg = Path { p in
                    p.addLines([CGPoint(x: segX - r, y: lineY)] + s.arc(CGPoint(x: segX, y: lineY), r, from: 0, to: 180))
                    p.closeSubpath()
                }
                s.fill(seg, clippedTo: lens, segColor)
                s.stroke(seg, s.accent)
                if i == 3 {
                    s.line(CGPoint(x: segX - r, y: lineY + s.h(0.06)), CGPoint(x: segX + r, y: lineY + s.h(0.06)), s.accent)
                    s.fill(Path(CGRect(x: segX - r, y: lineY, width: r * 2, height: s.h(0.06))), clippedTo: lens, s.accent.opacity(0.18))
                }
                s.dimension(CGPoint(x: c.x + s.w(0.058), y: lineY), CGPoint(x: c.x + s.w(0.058), y: c.y + lensH / 2), "ht")
            case 1:
                let seg = s.circle(CGPoint(x: segX, y: c.y + s.h(0.16)), s.w(0.03))
                s.fill(seg, segColor)
                s.stroke(seg, s.accent)
            default:
                let lineY = c.y + s.h(0.06)
                s.fill(Path(CGRect(x: c.x - lensW / 2, y: lineY, width: lensW, height: lensH)), clippedTo: lens, segColor)
                s.line(CGPoint(x: c.x - lensW / 2, y: lineY), CGPoint(x: c.x + lensW / 2, y: lineY), s.accent)
            }
            s.stroke(lens, s.ink, s.stroke * 1.6)
            s.label(name, at: CGPoint(x: c.x, y: s.h(0.86)), scale: 0.85, weight: .semibold)
        }
    }

    private static func palLayout(_ s: Sketch) {
        let c = s.p(0.5, 0.5)
        let lens = s.ellipse(c, width: s.w(0.42), height: s.h(0.9))
        s.fill(lens, s.ray.opacity(0.07))
        for x in [0.38, 0.62] as [CGFloat] {
            s.fill(s.ellipse(s.p(x, 0.68), width: s.w(0.1), height: s.h(0.3)), clippedTo: lens, s.muted.opacity(0.18))
        }
        var corridor = Path()
        corridor.move(to: s.p(0.485, 0.42))
        corridor.addLine(to: s.p(0.515, 0.42))
        corridor.addLine(to: s.p(0.495, 0.7))
        corridor.addLine(to: s.p(0.445, 0.7))
        corridor.closeSubpath()
        s.fill(corridor, s.accent.opacity(0.2))
        s.stroke(lens, s.ink, s.stroke * 1.8)

        s.line(s.p(0.35, 0.47), s.p(0.65, 0.47), s.muted, dash: [3, 4])
        for x in [0.35, 0.65] as [CGFloat] {
            s.stroke(s.circle(s.p(x, 0.47), s.w(0.011)), s.muted)
        }
        let distance = s.p(0.5, 0.22)
        s.polyline(s.arc(distance, s.w(0.045), from: 180, to: 360), s.accent, s.stroke * 1.4)
        s.line(CGPoint(x: distance.x - s.w(0.045), y: distance.y), CGPoint(x: distance.x + s.w(0.045), y: distance.y), s.accent, s.stroke * 1.4)
        let cross = s.p(0.5, 0.36)
        s.line(CGPoint(x: cross.x - s.w(0.025), y: cross.y), CGPoint(x: cross.x + s.w(0.025), y: cross.y), s.accent, s.stroke * 1.8)
        s.line(CGPoint(x: cross.x, y: cross.y - s.h(0.04)), CGPoint(x: cross.x, y: cross.y + s.h(0.04)), s.accent, s.stroke * 1.8)
        s.fill(s.circle(s.p(0.5, 0.47), s.w(0.007)), s.accent)
        s.label("34 mm", at: s.p(0.58, 0.5), color: s.muted, scale: 0.75, anchor: .top)
        s.stroke(s.circle(s.p(0.47, 0.76), s.w(0.035)), s.accent, s.stroke * 1.4)

        s.callout("Distance circle", at: s.p(0.03, 0.18), to: CGPoint(x: distance.x - s.w(0.045), y: distance.y), anchor: .leading)
        s.callout("Fitting cross", at: s.p(0.03, 0.36), to: CGPoint(x: cross.x - s.w(0.025), y: cross.y), anchor: .leading)
        s.callout("Engraving", at: s.p(0.03, 0.56), to: s.p(0.35, 0.47), anchor: .leading)
        s.callout("Prism ref. point", at: s.p(0.97, 0.4), to: s.p(0.5, 0.47), anchor: .trailing)
        s.callout("Corridor", at: s.p(0.97, 0.56), to: s.p(0.5, 0.58), anchor: .trailing)
        s.callout("Blur zone", at: s.p(0.97, 0.72), to: s.p(0.62, 0.7), anchor: .trailing)
        s.callout("Near circle", at: s.p(0.97, 0.88), to: s.p(0.47, 0.8), anchor: .trailing)
    }

    // MARK: Contact lenses

    private static func tearLens(_ s: Sketch) {
        for (i, steep) in [true, false].enumerated() {
            let cx = s.w(i == 0 ? 0.25 : 0.75)
            let c0 = CGPoint(x: cx - s.w(0.18), y: s.h(0.78))
            let cc = CGPoint(x: cx, y: s.h(0.18))
            let c1 = CGPoint(x: cx + s.w(0.18), y: s.h(0.78))
            let a: CGFloat = 0.0556
            let contactL = s.quad(c0, cc, c1, a)
            let contactR = s.quad(c0, cc, c1, 1 - a)

            let backStart = steep ? contactL : CGPoint(x: contactL.x, y: contactL.y - s.h(0.07))
            let backEnd = CGPoint(x: contactR.x, y: backStart.y)
            let backControl = steep ? CGPoint(x: cx, y: s.h(0.0)) : CGPoint(x: cx, y: s.h(0.27))
            let front = Path { p in
                p.move(to: CGPoint(x: backStart.x - s.w(0.006), y: backStart.y - s.h(0.03)))
                p.addQuadCurve(to: CGPoint(x: backEnd.x + s.w(0.006), y: backEnd.y - s.h(0.03)), control: CGPoint(x: cx, y: backControl.y - s.h(0.08)))
                p.addLine(to: backEnd)
                p.addQuadCurve(to: backStart, control: backControl)
                p.closeSubpath()
            }

            var tearPath = Path()
            tearPath.addLines(s.quadPoints(backStart, backControl, backEnd) + [contactR] + s.quadPoints(c0, cc, c1, from: 1 - a, to: a))
            tearPath.closeSubpath()
            s.fill(tearPath, s.tear.opacity(0.55))

            s.polyline(s.quadPoints(c0, cc, c1), s.ink, s.stroke * 1.6)
            s.fill(front, s.accent.opacity(0.3))
            s.stroke(front, s.accent)

            s.label(steep ? "Steeper than K" : "Flatter than K", at: CGPoint(x: cx, y: s.h(0.04)), weight: .bold)
            s.label(steep ? "Plus tear lens\nSAM: add minus" : "Minus tear lens\nFAP: add plus",
                    at: CGPoint(x: cx, y: s.h(0.9)), color: s.accent, scale: 0.9, weight: .semibold)
        }
    }

    private static func fluoresceinPatterns(_ s: Sketch) {
        let green = Color(red: 0.45, green: 1.0, blue: 0.35)
        let navy = Color(red: 0.04, green: 0.06, blue: 0.22)
        let names = ["Alignment\n(on K)", "Apical clearance\n(steep)", "Apical bearing\n(flat)"]
        for (i, name) in names.enumerated() {
            let c = CGPoint(x: s.w((CGFloat(i) + 0.5) / 3), y: s.h(0.4))
            let r = s.h(0.34)
            let disc = s.circle(c, r)
            s.fill(disc, navy)
            let stops: [Gradient.Stop] = switch i {
            case 0: [.init(color: green.opacity(0.32), location: 0), .init(color: green.opacity(0.32), location: 0.82),
                     .init(color: green.opacity(0.95), location: 0.92), .init(color: green.opacity(0.6), location: 1)]
            case 1: [.init(color: green.opacity(0.9), location: 0), .init(color: green.opacity(0.4), location: 0.45),
                     .init(color: .clear, location: 0.62), .init(color: .clear, location: 0.93),
                     .init(color: green.opacity(0.45), location: 0.97), .init(color: green.opacity(0.3), location: 1)]
            default: [.init(color: .clear, location: 0), .init(color: .clear, location: 0.3),
                      .init(color: green.opacity(0.55), location: 0.6), .init(color: green.opacity(0.95), location: 0.85),
                      .init(color: green.opacity(0.7), location: 1)]
            }
            s.ctx.fill(disc, with: .radialGradient(Gradient(stops: stops), center: c, startRadius: 0, endRadius: r))
            s.stroke(disc, s.muted.opacity(0.6))
            s.label(name, at: CGPoint(x: c.x, y: s.h(0.88)), scale: 0.9, weight: .semibold)
        }
    }
}
