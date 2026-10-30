import SwiftUI

enum EmberMood: Equatable {
    case idle, happy, focused, sleepy, celebrating, curious
}

/// Animated Ember. Uses a TimelineView unless motion is reduced or `animated` is false
/// (widgets and Live Activities render a single still frame).
struct EmberView: View {
    var appearance: EmberAppearance
    var mood: EmberMood = .idle
    var animated: Bool = true

    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.emberReduceMotion) private var appReduceMotion

    var body: some View {
        let still = !animated || systemReduceMotion || appReduceMotion
        Group {
            if still {
                // Widgets and Live Activities can't animate, so they get a single frame.
                EmberFigure(appearance: appearance, mood: mood, time: 1.3, still: true)
            } else {
                TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
                    EmberFigure(
                        appearance: appearance,
                        mood: mood,
                        time: context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 3600)
                    )
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement()
        .accessibilityLabel(Text(EmberFigure.accessibilityDescription(appearance, mood)))
    }
}

/// A single frame of Ember drawn in a 200×200 design space. Everything is vector-drawn in code.
struct EmberFigure: View {
    var appearance: EmberAppearance
    var mood: EmberMood
    var time: Double
    var still: Bool = false

    private static let bodyTop = Color(hex: 0xFFF6E3)
    private static let bodyBottom = Color(hex: 0xF3C788)
    private static let rim = Color(hex: 0xC98A4B)
    private static let eye = Color(hex: 0x2E2238)
    private static let blush = Color(hex: 0xFF8F8F)

    var body: some View {
        Canvas { ctx, size in
            let s = min(size.width, size.height) / 200
            ctx.translateBy(x: (size.width - 200 * s) / 2, y: (size.height - 200 * s) / 2)
            ctx.scaleBy(x: s, y: s)
            draw(in: &ctx)
        }
    }

    static func accessibilityDescription(_ a: EmberAppearance, _ mood: EmberMood) -> String {
        let form = a.path.map { "\($0.title) Ember" } ?? (a.stage == 0 ? "small Ember" : "growing Ember")
        let feeling: String = switch mood {
        case .idle: "resting"
        case .happy: "smiling"
        case .focused: "calmly tending its flame"
        case .sleepy: "dozing"
        case .celebrating: "hopping with joy"
        case .curious: "looking around curiously"
        }
        return "\(form), \(feeling)"
    }

    // MARK: Drawing

    private func draw(in ctx: inout GraphicsContext) {
        let a = appearance
        let tint = FlameTint.named(a.flameTint)
        let stage = max(0, min(4, a.stage))
        let scale: CGFloat = [0.72, 0.84, 0.92, 1.0, 1.06][stage]
        let t = time

        // Motion
        var bob: CGFloat = 0
        var breathe = CGFloat(sin(t * 2.2))
        var tilt: CGFloat = 0
        var hop: CGFloat = 0
        switch mood {
        case .idle: bob = CGFloat(sin(t * 1.6)) * 2
        case .happy: bob = CGFloat(sin(t * 3.0)) * 2.5; tilt = CGFloat(sin(t * 1.5)) * 0.04
        case .focused: bob = CGFloat(sin(t * 0.9)) * 1.2; breathe = CGFloat(sin(t * 1.1))
        case .sleepy: bob = CGFloat(sin(t * 0.7)) * 1; breathe = CGFloat(sin(t * 0.8)); tilt = 0.06
        case .celebrating: hop = CGFloat(abs(sin(t * 4.5)))
        case .curious: tilt = CGFloat(sin(t * 1.2)) * 0.09
        }
        if still { bob = 0; hop = 0; breathe = 0 }

        let landing: CGFloat = (mood == .celebrating && hop < 0.12) ? 0.05 : 0
        let widthFactor: CGFloat = 1 - breathe * 0.012 + landing
        let heightFactor: CGFloat = 1 + breathe * 0.018 + hop * 0.04
        let w: CGFloat = 104 * scale * widthFactor
        let h: CGFloat = 92 * scale * heightFactor
        let groundY: CGFloat = 182
        let lift = hop * 18 - bob
        let rect = CGRect(x: 100 - w / 2, y: groundY - 6 - h - lift, width: w, height: h)
        let cx = rect.midX

        // Ground shadow
        let shadowW = w * (0.9 - hop * 0.3)
        ctx.fill(
            Path(ellipseIn: CGRect(x: 100 - shadowW / 2, y: groundY - 5, width: shadowW, height: 9)),
            with: .color(Palette.ink.opacity(0.18 - Double(hop) * 0.08))
        )

        // Aura
        let flicker = still ? 0 : CGFloat(sin(t * 7.3) * 0.5 + sin(t * 11.1) * 0.5)
        let auraR = w * (0.95 + CGFloat(stage) * 0.06) + flicker * 2
        let auraCenter = CGPoint(x: cx, y: rect.midY + h * 0.1)
        ctx.fill(
            Path(ellipseIn: CGRect(x: auraCenter.x - auraR, y: auraCenter.y - auraR, width: auraR * 2, height: auraR * 2)),
            with: .radialGradient(
                Gradient(colors: [tint.glow.opacity(0.32 + Double(stage) * 0.06), tint.glow.opacity(0)]),
                center: auraCenter, startRadius: 0, endRadius: auraR
            )
        )

        // Pivot for tilt
        ctx.translateBy(x: cx, y: groundY - lift)
        ctx.rotate(by: .radians(Double(tilt)))
        ctx.translateBy(x: -cx, y: -(groundY - lift))

        // Back layers
        if a.path == .starlight && stage >= 2 { drawWings(&ctx, rect: rect, stage: stage, tint: tint, t: t) }
        if a.path == .bloom && stage >= 2 { drawLeafEars(&ctx, rect: rect, stage: stage, t: t) }
        if a.path == .hearth && stage >= 3 { drawEmberTufts(&ctx, rect: rect, tint: tint, t: t) }

        // Feet
        let footY = rect.maxY - 4
        for side in [-1.0, 1.0] {
            let fx = cx + CGFloat(side) * w * 0.2
            ctx.fill(Path(ellipseIn: CGRect(x: fx - w * 0.11, y: footY, width: w * 0.22, height: 10 * scale)),
                     with: .color(Palette.honey))
        }

        // Arms
        var armRaise: CGFloat = 0
        if mood == .celebrating { armRaise = -h * 0.28 * (0.5 + hop * 0.5) }
        if mood == .happy { armRaise = -h * 0.08 }
        for side in [-1.0, 1.0] {
            let ax = cx + CGFloat(side) * w * 0.49
            let ay = rect.minY + h * 0.66 + armRaise
            ctx.fill(Path(ellipseIn: CGRect(x: ax - 7 * scale, y: ay - 5 * scale, width: 14 * scale, height: 11 * scale)),
                     with: .color(Self.bodyBottom))
        }

        // Body
        let body = Self.bodyPath(rect)
        ctx.fill(body, with: .linearGradient(Gradient(colors: [Self.bodyTop, Self.bodyBottom]),
                                             startPoint: CGPoint(x: cx, y: rect.minY), endPoint: CGPoint(x: cx, y: rect.maxY)))

        // Inner belly glow + heart flame
        let bellyBase = CGPoint(x: cx, y: rect.minY + h * 0.95)
        let glowR = w * 0.42 + flicker * 1.5
        ctx.drawLayer { layer in
            layer.clip(to: body)
            layer.fill(Path(ellipseIn: CGRect(x: cx - glowR, y: bellyBase.y - glowR * 1.1, width: glowR * 2, height: glowR * 2)),
                       with: .radialGradient(Gradient(colors: [tint.glow.opacity(0.95), tint.glow.opacity(0)]),
                                             center: CGPoint(x: cx, y: bellyBase.y - glowR * 0.2), startRadius: 0, endRadius: glowR))
            let fh = h * (0.2 + CGFloat(stage) * 0.018) * (1 + flicker * 0.06)
            let fw = fh * 0.62
            let sway = still ? 0 : CGFloat(sin(t * 3.1)) * 1.6
            layer.fill(Self.flamePath(base: CGPoint(x: cx, y: bellyBase.y - 2), width: fw, height: fh, sway: sway),
                       with: .linearGradient(Gradient(colors: [tint.glow, tint.core]),
                                             startPoint: CGPoint(x: cx, y: bellyBase.y - fh), endPoint: CGPoint(x: cx, y: bellyBase.y)))
            layer.fill(Self.flamePath(base: CGPoint(x: cx, y: bellyBase.y - 3), width: fw * 0.45, height: fh * 0.5, sway: sway * 0.5),
                       with: .color(.white.opacity(0.85)))

            // Moss cap
            layer.fill(Self.capPath(rect), with: .linearGradient(
                Gradient(colors: [Palette.mossLight, Palette.moss]),
                startPoint: CGPoint(x: cx, y: rect.minY), endPoint: CGPoint(x: cx, y: rect.minY + h * 0.36)))
            for (dx, dy, r) in [(-0.28, 0.12, 0.05), (0.18, 0.08, 0.04), (0.33, 0.2, 0.03), (-0.08, 0.05, 0.03)] as [(CGFloat, CGFloat, CGFloat)] {
                layer.fill(Path(ellipseIn: CGRect(x: cx + w * dx - w * r, y: rect.minY + h * dy - w * r, width: w * r * 2, height: w * r * 1.6)),
                           with: .color(Color(hex: 0xC6E58E).opacity(0.8)))
            }
            if a.path == .bloom && stage >= 2 {
                for (i, dx) in [-0.3, 0.26, 0.05].enumerated() where i < stage {
                    Self.drawFlower(layer, at: CGPoint(x: cx + w * CGFloat(dx), y: rect.minY + h * (0.16 + CGFloat(i % 2) * 0.06)),
                                    radius: 4.2 * scale, petal: i == 1 ? Color(hex: 0xFFD6E5) : .white, center: Palette.amber)
                }
            }
        }
        ctx.stroke(body, with: .color(Self.rim.opacity(0.45)), lineWidth: 2)

        // Face
        let eyeY = rect.minY + h * 0.5
        let eyeDX = w * 0.18
        let ew = w * 0.115, eh = w * 0.145
        drawEyes(&ctx, cx: cx, eyeY: eyeY, dx: eyeDX, ew: ew, eh: eh, t: t)

        for side in [-1.0, 1.0] {
            let bx = cx + CGFloat(side) * w * 0.31
            ctx.fill(Path(ellipseIn: CGRect(x: bx - w * 0.065, y: eyeY + eh * 0.55, width: w * 0.13, height: w * 0.07)),
                     with: .color(Self.blush.opacity(0.42)))
        }
        if a.path == .starlight && stage >= 2 {
            for (side, dy) in [(-1.0, 0.0), (1.0, 0.25), (-1.0, 0.45)] {
                let p = CGPoint(x: cx + CGFloat(side) * w * (0.33 + CGFloat(dy) * 0.05), y: eyeY + eh * (0.4 + CGFloat(dy) * 1.2))
                ctx.fill(Self.sparklePath(center: p, radius: 2.4 * scale), with: .color(tint.core.opacity(0.75)))
            }
        }
        drawMouth(&ctx, cx: cx, y: eyeY + eh * 0.95, scale: scale)

        // Cosmetics: neck, face
        if let neck = a.neck { drawNeck(&ctx, id: neck, rect: rect, t: t) }
        if a.face == "roundGlasses" {
            for side in [-1.0, 1.0] {
                let r = ew * 1.25
                let c = CGPoint(x: cx + CGFloat(side) * eyeDX, y: eyeY)
                ctx.stroke(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)),
                           with: .color(Color(hex: 0x5B4636)), lineWidth: 1.8)
            }
            var bridge = Path()
            bridge.move(to: CGPoint(x: cx - eyeDX + ew * 1.25, y: eyeY - 1))
            bridge.addQuadCurve(to: CGPoint(x: cx + eyeDX - ew * 1.25, y: eyeY - 1), control: CGPoint(x: cx, y: eyeY - 4))
            ctx.stroke(bridge, with: .color(Color(hex: 0x5B4636)), lineWidth: 1.8)
        }

        // Crown of the head: sprout or path feature, then hat
        let hatLift: CGFloat = a.head == nil ? 0 : (a.head == "mushroomHat" ? h * 0.2 : h * 0.12)
        drawTopFeature(&ctx, rect: rect, stage: stage, tint: tint, t: t, lift: hatLift, hasHat: a.head != nil)
        if let head = a.head { drawHead(&ctx, id: head, rect: rect) }

        // Restore transform for floating effects
        ctx.translateBy(x: cx, y: groundY - lift)
        ctx.rotate(by: .radians(-Double(tilt)))
        ctx.translateBy(x: -cx, y: -(groundY - lift))

        drawParticles(&ctx, rect: rect, stage: stage, tint: tint, t: t)
    }

    // MARK: Face

    private func drawEyes(_ ctx: inout GraphicsContext, cx: CGFloat, eyeY: CGFloat, dx: CGFloat, ew: CGFloat, eh: CGFloat, t: Double) {
        for side in [-1.0, 1.0] {
            let ex = cx + CGFloat(side) * dx
            switch mood {
            case .happy, .celebrating:
                var p = Path()
                p.move(to: CGPoint(x: ex - ew * 0.85, y: eyeY + eh * 0.25))
                p.addQuadCurve(to: CGPoint(x: ex + ew * 0.85, y: eyeY + eh * 0.25), control: CGPoint(x: ex, y: eyeY - eh * 0.95))
                ctx.stroke(p, with: .color(Self.eye), style: StrokeStyle(lineWidth: 3.2, lineCap: .round))
            case .focused, .sleepy:
                var p = Path()
                p.move(to: CGPoint(x: ex - ew * 0.8, y: eyeY))
                p.addQuadCurve(to: CGPoint(x: ex + ew * 0.8, y: eyeY), control: CGPoint(x: ex, y: eyeY + eh * 0.75))
                ctx.stroke(p, with: .color(Self.eye), style: StrokeStyle(lineWidth: 3, lineCap: .round))
            case .idle, .curious:
                let phase = (t + (side > 0 ? 0.02 : 0)).truncatingRemainder(dividingBy: 4.3)
                let closed = (!still && phase < 0.16) ? CGFloat(sin(phase / 0.16 * .pi)) : 0
                let sizeBoost: CGFloat = mood == .curious ? 1.12 : 1
                let h2 = eh * sizeBoost * (1 - closed * 0.88)
                let w2 = ew * sizeBoost
                ctx.fill(Path(ellipseIn: CGRect(x: ex - w2, y: eyeY - h2, width: w2 * 2, height: h2 * 2)), with: .color(Self.eye))
                if closed < 0.5 {
                    let look: CGFloat = mood == .curious ? CGFloat(sin(t * 1.2)) * w2 * 0.25 : 0
                    let r1 = w2 * 0.36, r2 = w2 * 0.16
                    ctx.fill(Path(ellipseIn: CGRect(x: ex + w2 * 0.12 + look - r1, y: eyeY - h2 * 0.42 - r1, width: r1 * 2, height: r1 * 2)),
                             with: .color(.white))
                    ctx.fill(Path(ellipseIn: CGRect(x: ex - w2 * 0.35 + look - r2, y: eyeY + h2 * 0.35 - r2, width: r2 * 2, height: r2 * 2)),
                             with: .color(.white.opacity(0.85)))
                }
            }
        }
    }

    private func drawMouth(_ ctx: inout GraphicsContext, cx: CGFloat, y: CGFloat, scale: CGFloat) {
        switch mood {
        case .happy, .celebrating:
            var p = Path()
            p.move(to: CGPoint(x: cx - 6 * scale, y: y - 1))
            p.addQuadCurve(to: CGPoint(x: cx + 6 * scale, y: y - 1), control: CGPoint(x: cx, y: y + 10 * scale))
            p.closeSubpath()
            ctx.fill(p, with: .color(Self.eye))
            ctx.fill(Path(ellipseIn: CGRect(x: cx - 3 * scale, y: y + 2 * scale, width: 6 * scale, height: 3 * scale)),
                     with: .color(Color(hex: 0xFF7E8B)))
        case .sleepy:
            ctx.stroke(Path(ellipseIn: CGRect(x: cx - 2.5 * scale, y: y, width: 5 * scale, height: 5 * scale)),
                       with: .color(Self.eye), lineWidth: 2)
        case .curious:
            ctx.fill(Path(ellipseIn: CGRect(x: cx - 2.5 * scale, y: y, width: 5 * scale, height: 4 * scale)), with: .color(Self.eye))
        case .idle, .focused:
            var p = Path()
            p.move(to: CGPoint(x: cx - 5 * scale, y: y))
            p.addQuadCurve(to: CGPoint(x: cx + 5 * scale, y: y), control: CGPoint(x: cx, y: y + 5 * scale))
            ctx.stroke(p, with: .color(Self.eye), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
        }
    }

    // MARK: Path features

    private func drawTopFeature(_ ctx: inout GraphicsContext, rect: CGRect, stage: Int, tint: FlameTint, t: Double,
                                lift: CGFloat, hasHat: Bool) {
        let top = CGPoint(x: rect.midX, y: rect.minY + 3 - lift)
        let sway = still ? 0 : CGFloat(sin(t * 1.8)) * 0.12
        let path = stage >= 2 ? appearance.path : nil

        switch path {
        case .hearth:
            let fh = 22 + CGFloat(stage) * 5
            let flick = still ? 0 : CGFloat(sin(t * 6.1)) * 1.5
            ctx.fill(Self.flamePath(base: top, width: fh * 0.62, height: fh + flick, sway: flick),
                     with: .linearGradient(Gradient(colors: [tint.glow, tint.core]),
                                           startPoint: CGPoint(x: top.x, y: top.y - fh), endPoint: top))
            ctx.fill(Self.flamePath(base: CGPoint(x: top.x, y: top.y - 1), width: fh * 0.28, height: fh * 0.5, sway: flick * 0.5),
                     with: .color(.white.opacity(0.8)))
        case .starlight:
            for side in [-1.0, 1.0] {
                var p = Path()
                let start = CGPoint(x: top.x + CGFloat(side) * 6, y: top.y + 2)
                let end = CGPoint(x: top.x + CGFloat(side) * (18 + CGFloat(stage) * 3), y: top.y - 20 - CGFloat(stage) * 3)
                p.move(to: start)
                p.addQuadCurve(to: end, control: CGPoint(x: top.x + CGFloat(side) * 2, y: top.y - 18))
                ctx.stroke(p, with: .color(Color(hex: 0x6B5A8E)), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                let twinkle = still ? 1 : 0.75 + 0.25 * sin(t * 3 + Double(side))
                ctx.fill(Self.sparklePath(center: end, radius: 5.5 * CGFloat(twinkle)), with: .color(tint.glow))
                ctx.fill(Path(ellipseIn: CGRect(x: end.x - 2, y: end.y - 2, width: 4, height: 4)), with: .color(.white))
            }
        case .bloom:
            var stem = Path()
            stem.move(to: top)
            let tip = CGPoint(x: top.x + sway * 30, y: top.y - 18 - CGFloat(stage) * 2)
            stem.addQuadCurve(to: tip, control: CGPoint(x: top.x - 4, y: top.y - 10))
            ctx.stroke(stem, with: .color(Palette.mossDeep), style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
            ctx.fill(Self.leafPath(base: CGPoint(x: top.x - 1, y: top.y - 7), length: 12, width: 5, angle: -2.6), with: .color(Palette.moss))
            Self.drawFlower(ctx, at: tip, radius: 5 + CGFloat(stage) * 1.4,
                            petal: Color(hex: 0xFFB7CF), center: Palette.amberGlow)
        default:
            guard !hasHat else { return }
            // Sprout: two leaves on a short stem, grows a little with stage
            let len = 10 + CGFloat(stage) * 4
            var stem = Path()
            let tip = CGPoint(x: top.x + sway * 20, y: top.y - len)
            stem.move(to: top)
            stem.addQuadCurve(to: tip, control: CGPoint(x: top.x - 2, y: top.y - len * 0.5))
            ctx.stroke(stem, with: .color(Palette.mossDeep), style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
            ctx.fill(Self.leafPath(base: tip, length: 11 + CGFloat(stage) * 2, width: 5.5, angle: -2.5 + Double(sway)), with: .color(Palette.moss))
            ctx.fill(Self.leafPath(base: tip, length: 13 + CGFloat(stage) * 2, width: 6, angle: -0.5 + Double(sway)), with: .color(Palette.mossLight))
        }
    }

    private func drawWings(_ ctx: inout GraphicsContext, rect: CGRect, stage: Int, tint: FlameTint, t: Double) {
        let flutter = still ? 0 : sin(t * 5) * 0.12
        let size = rect.width * (0.38 + CGFloat(stage - 2) * 0.07)
        for side in [-1.0, 1.0] {
            let anchor = CGPoint(x: rect.midX + CGFloat(side) * rect.width * 0.32, y: rect.minY + rect.height * 0.42)
            for (i, (len, ang)) in [(size, -0.55), (size * 0.72, 0.35)].enumerated() {
                let angle = side > 0 ? ang - flutter : .pi - ang + flutter
                var wing = Path(ellipseIn: CGRect(x: 0, y: -len * 0.33, width: len, height: len * 0.66))
                wing = wing.applying(CGAffineTransform(rotationAngle: angle).concatenating(CGAffineTransform(translationX: anchor.x, y: anchor.y)))
                ctx.fill(wing, with: .color(tint.glow.opacity(i == 0 ? 0.55 : 0.45)))
                ctx.stroke(wing, with: .color(.white.opacity(0.75)), lineWidth: 1.2)
            }
        }
    }

    private func drawLeafEars(_ ctx: inout GraphicsContext, rect: CGRect, stage: Int, t: Double) {
        let wiggle = still ? 0 : sin(t * 1.4) * 0.06
        let len = rect.width * (0.3 + CGFloat(stage - 2) * 0.05)
        for side in [-1.0, 1.0] {
            let base = CGPoint(x: rect.midX + CGFloat(side) * rect.width * 0.36, y: rect.minY + rect.height * 0.18)
            let angle = side > 0 ? -0.45 + wiggle : .pi + 0.45 - wiggle
            ctx.fill(Self.leafPath(base: base, length: len, width: len * 0.42, angle: angle), with: .color(Palette.moss))
            var vein = Path()
            vein.move(to: base)
            vein.addLine(to: CGPoint(x: base.x + cos(angle) * len * 0.8, y: base.y + sin(angle) * len * 0.8))
            ctx.stroke(vein, with: .color(Palette.mossDeep.opacity(0.6)), lineWidth: 1)
        }
    }

    private func drawEmberTufts(_ ctx: inout GraphicsContext, rect: CGRect, tint: FlameTint, t: Double) {
        for side in [-1.0, 1.0] {
            let base = CGPoint(x: rect.midX + CGFloat(side) * rect.width * 0.34, y: rect.minY + rect.height * 0.2)
            let flick = still ? 0 : CGFloat(sin(t * 7 + side)) * 1.2
            var flame = Self.flamePath(base: .zero, width: 12, height: 20 + flick, sway: flick)
            flame = flame.applying(CGAffineTransform(rotationAngle: CGFloat(side) * 0.6).concatenating(CGAffineTransform(translationX: base.x, y: base.y)))
            ctx.fill(flame, with: .color(tint.core.opacity(0.9)))
        }
    }

    // MARK: Cosmetics

    private func drawHead(_ ctx: inout GraphicsContext, id: String, rect: CGRect) {
        let cx = rect.midX, top = rect.minY, w = rect.width
        switch id {
        case "acornCap":
            let capRect = CGRect(x: cx - w * 0.24, y: top - w * 0.07, width: w * 0.48, height: w * 0.2)
            var cap = Path()
            cap.move(to: CGPoint(x: capRect.minX, y: capRect.maxY))
            cap.addQuadCurve(to: CGPoint(x: capRect.maxX, y: capRect.maxY), control: CGPoint(x: cx, y: capRect.minY - w * 0.12))
            cap.addQuadCurve(to: CGPoint(x: capRect.minX, y: capRect.maxY), control: CGPoint(x: cx, y: capRect.maxY + w * 0.05))
            ctx.fill(cap, with: .color(Color(hex: 0x9A6233)))
            for i in 0..<4 {
                var line = Path()
                let x = capRect.minX + capRect.width * (0.2 + CGFloat(i) * 0.2)
                line.move(to: CGPoint(x: x - 4, y: capRect.maxY - 1))
                line.addLine(to: CGPoint(x: x + 3, y: capRect.minY + 3))
                ctx.stroke(line, with: .color(Color(hex: 0xC48A52).opacity(0.7)), lineWidth: 1.2)
            }
            ctx.fill(Path(roundedRect: CGRect(x: cx - 2, y: capRect.minY - w * 0.08, width: 4, height: w * 0.08), cornerRadius: 2),
                     with: .color(Color(hex: 0x6E4422)))
        case "mushroomHat":
            let r = CGRect(x: cx - w * 0.36, y: top - w * 0.2, width: w * 0.72, height: w * 0.36)
            var dome = Path()
            dome.move(to: CGPoint(x: r.minX, y: r.maxY))
            dome.addCurve(to: CGPoint(x: r.maxX, y: r.maxY), control1: CGPoint(x: r.minX, y: r.minY - 6), control2: CGPoint(x: r.maxX, y: r.minY - 6))
            dome.addQuadCurve(to: CGPoint(x: r.minX, y: r.maxY), control: CGPoint(x: cx, y: r.maxY + 6))
            ctx.fill(dome, with: .linearGradient(Gradient(colors: [Color(hex: 0xF07167), Color(hex: 0xC94A47)]),
                                                 startPoint: CGPoint(x: cx, y: r.minY), endPoint: CGPoint(x: cx, y: r.maxY)))
            for (dx, dy, rr) in [(-0.2, 0.45, 0.06), (0.12, 0.3, 0.07), (0.26, 0.62, 0.045), (-0.02, 0.68, 0.04)] as [(CGFloat, CGFloat, CGFloat)] {
                let c = CGPoint(x: cx + w * dx, y: r.minY + r.height * dy)
                ctx.fill(Path(ellipseIn: CGRect(x: c.x - w * rr, y: c.y - w * rr * 0.8, width: w * rr * 2, height: w * rr * 1.6)),
                         with: .color(Color(hex: 0xFFF4E0)))
            }
        case "flowerCrown":
            let colors = [Color(hex: 0xFFB7CF), .white, Color(hex: 0xFFD27A), Color(hex: 0xB9A6E0), Color(hex: 0xFFB7CF)]
            for (i, color) in colors.enumerated() {
                let f = CGFloat(i) / CGFloat(colors.count - 1)
                let x = cx - w * 0.36 + f * w * 0.72
                let y = top + rect.height * 0.14 - sin(f * .pi) * rect.height * 0.12
                ctx.fill(Self.leafPath(base: CGPoint(x: x, y: y), length: 7, width: 3, angle: -1.2 + Double(f) * 2.4), with: .color(Palette.mossDeep))
                Self.drawFlower(ctx, at: CGPoint(x: x, y: y), radius: 4.6, petal: color, center: Palette.amber)
            }
        case "starCirclet":
            var arc = Path()
            arc.move(to: CGPoint(x: cx - w * 0.38, y: top + rect.height * 0.3))
            arc.addQuadCurve(to: CGPoint(x: cx + w * 0.38, y: top + rect.height * 0.3), control: CGPoint(x: cx, y: top + rect.height * 0.12))
            ctx.stroke(arc, with: .color(Color(hex: 0xF2C14E)), style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
            let c = CGPoint(x: cx, y: top + rect.height * 0.2)
            ctx.fill(Self.starPath(center: c, outer: 7, inner: 3.2), with: .color(Color(hex: 0xFFE07A)))
            ctx.stroke(Self.starPath(center: c, outer: 7, inner: 3.2), with: .color(Color(hex: 0xD9A030)), lineWidth: 0.8)
        default: break
        }
    }

    private func drawNeck(_ ctx: inout GraphicsContext, id: String, rect: CGRect, t: Double) {
        let cx = rect.midX, w = rect.width
        let y = rect.minY + rect.height * 0.72
        let bandH = rect.height * 0.085
        let half = w * 0.485
        var band = Path()
        band.move(to: CGPoint(x: cx - half, y: y))
        band.addQuadCurve(to: CGPoint(x: cx + half, y: y), control: CGPoint(x: cx, y: y + bandH * 0.9))
        band.addLine(to: CGPoint(x: cx + half * 0.98, y: y + bandH))
        band.addQuadCurve(to: CGPoint(x: cx - half * 0.98, y: y + bandH), control: CGPoint(x: cx, y: y + bandH * 1.9))
        band.closeSubpath()
        let sway = still ? 0 : sin(t * 1.7) * 0.08

        switch id {
        case "leafScarf":
            ctx.fill(band, with: .color(Palette.moss))
            let knot = CGPoint(x: cx + half * 0.55, y: y + bandH)
            ctx.fill(Self.leafPath(base: knot, length: w * 0.2, width: w * 0.08, angle: 1.3 + sway), with: .color(Palette.mossLight))
            ctx.fill(Self.leafPath(base: knot, length: w * 0.17, width: w * 0.07, angle: 1.85 + sway), with: .color(Palette.moss))
        case "knitScarf":
            ctx.fill(band, with: .color(Palette.coral))
            ctx.stroke(band, with: .color(Color(hex: 0xFFD6C2).opacity(0.7)), style: StrokeStyle(lineWidth: 1, dash: [2, 3]))
            var tail = Path(roundedRect: CGRect(x: 0, y: 0, width: w * 0.1, height: rect.height * 0.3), cornerRadius: 2)
            tail = tail.applying(CGAffineTransform(rotationAngle: -0.15 + sway).concatenating(
                CGAffineTransform(translationX: cx + half * 0.45, y: y + bandH * 0.6)))
            ctx.fill(tail, with: .color(Color(hex: 0xD45539)))
            ctx.stroke(tail, with: .color(Color(hex: 0xFFD6C2).opacity(0.6)), style: StrokeStyle(lineWidth: 1, dash: [2, 3]))
        case "bellCollar":
            var thin = Path()
            thin.move(to: CGPoint(x: cx - half, y: y + bandH * 0.3))
            thin.addQuadCurve(to: CGPoint(x: cx + half, y: y + bandH * 0.3), control: CGPoint(x: cx, y: y + bandH * 1.4))
            ctx.stroke(thin, with: .color(Color(hex: 0x4F7CAC)), style: StrokeStyle(lineWidth: 3.2, lineCap: .round))
            let bell = CGPoint(x: cx, y: y + bandH * 1.3)
            ctx.fill(Path(ellipseIn: CGRect(x: bell.x - 5, y: bell.y - 4, width: 10, height: 10)), with: .color(Color(hex: 0xF2C14E)))
            var slit = Path()
            slit.move(to: CGPoint(x: bell.x, y: bell.y + 1.5))
            slit.addLine(to: CGPoint(x: bell.x, y: bell.y + 5))
            ctx.stroke(slit, with: .color(Color(hex: 0x8A6420)), lineWidth: 1.2)
        default: break
        }
    }

    // MARK: Particles

    private func drawParticles(_ ctx: inout GraphicsContext, rect: CGRect, stage: Int, tint: FlameTint, t: Double) {
        let cx = rect.midX
        if mood == .celebrating {
            for i in 0..<7 {
                let ang = Double(i) / 7 * 2 * .pi + t * 0.8
                let r = rect.width * 0.8 + CGFloat(sin(t * 3 + Double(i))) * 6
                let p = CGPoint(x: cx + CGFloat(cos(ang)) * r, y: rect.midY + CGFloat(sin(ang)) * r * 0.75)
                let tw = 0.5 + 0.5 * sin(t * 6 + Double(i) * 1.7)
                ctx.fill(Self.sparklePath(center: p, radius: 3 + 4 * CGFloat(tw)),
                         with: .color(i % 2 == 0 ? tint.glow : .white))
            }
        }
        if mood == .sleepy && !still {
            for i in 0..<3 {
                let phase = (t * 0.35 + Double(i) / 3).truncatingRemainder(dividingBy: 1)
                let p = CGPoint(x: cx + rect.width * 0.4 + CGFloat(phase) * 18, y: rect.minY - CGFloat(phase) * 36)
                ctx.opacity = 1 - phase
                ctx.draw(Text("z").font(.system(size: 10 + CGFloat(phase) * 8, weight: .bold, design: .rounded))
                    .foregroundColor(Palette.lavender), at: p)
                ctx.opacity = 1
            }
        }
        guard stage >= 3, let path = appearance.path, !still else { return }
        let count = stage == 4 ? 6 : 3
        switch path {
        case .hearth:
            for i in 0..<count {
                let phase = (t * 0.4 + Double(i) / Double(count)).truncatingRemainder(dividingBy: 1)
                let x = cx + CGFloat(sin(Double(i) * 2.4 + t)) * rect.width * 0.5
                let y = rect.maxY - CGFloat(phase) * rect.height * 1.6
                ctx.fill(Path(ellipseIn: CGRect(x: x - 2, y: y - 2, width: 4, height: 4)),
                         with: .color(tint.core.opacity(1 - phase)))
            }
        case .bloom:
            for i in 0..<(count / 3 + 1) {
                let ang = t * 0.9 + Double(i) * .pi
                let p = CGPoint(x: cx + CGFloat(cos(ang)) * rect.width * 0.75, y: rect.midY - 20 + CGFloat(sin(ang * 2)) * 14)
                let flap = CGFloat(abs(sin(t * 12 + Double(i))))
                for side in [-1.0, 1.0] {
                    let wingX: CGFloat = side > 0 ? p.x : p.x - 6 * flap
                    ctx.fill(Path(ellipseIn: CGRect(x: wingX, y: p.y - 4, width: 6 * flap, height: 8)),
                             with: .color(i == 0 ? Color(hex: 0xFFB7CF) : Palette.amberGlow))
                }
            }
        case .starlight:
            for i in 0..<count {
                let ang = t * 0.5 + Double(i) / Double(count) * 2 * .pi
                let p = CGPoint(x: cx + CGFloat(cos(ang)) * rect.width * 0.72, y: rect.midY + CGFloat(sin(ang)) * rect.height * 0.35 - 10)
                ctx.fill(Self.sparklePath(center: p, radius: 3.5), with: .color(tint.glow))
            }
        }
    }

    // MARK: Shapes

    static func bodyPath(_ r: CGRect) -> Path {
        var p = Path()
        let x = r.minX, y = r.minY, w = r.width, h = r.height
        p.move(to: CGPoint(x: x + w * 0.5, y: y))
        p.addCurve(to: CGPoint(x: x + w, y: y + h * 0.62), control1: CGPoint(x: x + w * 0.84, y: y), control2: CGPoint(x: x + w, y: y + h * 0.28))
        p.addCurve(to: CGPoint(x: x + w * 0.5, y: y + h), control1: CGPoint(x: x + w, y: y + h * 0.92), control2: CGPoint(x: x + w * 0.8, y: y + h))
        p.addCurve(to: CGPoint(x: x, y: y + h * 0.62), control1: CGPoint(x: x + w * 0.2, y: y + h), control2: CGPoint(x: x, y: y + h * 0.92))
        p.addCurve(to: CGPoint(x: x + w * 0.5, y: y), control1: CGPoint(x: x, y: y + h * 0.28), control2: CGPoint(x: x + w * 0.16, y: y))
        p.closeSubpath()
        return p
    }

    /// Scalloped moss cap covering the top third of the body (clipped by the caller).
    static func capPath(_ r: CGRect) -> Path {
        var p = Path()
        let baseY = r.minY + r.height * 0.3
        let bumps = 5
        let left = r.minX - 4, right = r.maxX + 4
        let seg = (right - left) / CGFloat(bumps)
        p.move(to: CGPoint(x: left, y: r.minY - 4))
        p.addLine(to: CGPoint(x: right, y: r.minY - 4))
        p.addLine(to: CGPoint(x: right, y: baseY))
        for i in 0..<bumps {
            let x0 = right - CGFloat(i) * seg
            let x1 = x0 - seg
            let depth = seg * (i % 2 == 0 ? 0.55 : 0.4)
            p.addQuadCurve(to: CGPoint(x: x1, y: baseY), control: CGPoint(x: (x0 + x1) / 2, y: baseY + depth))
        }
        p.closeSubpath()
        return p
    }

    static func flamePath(base: CGPoint, width: CGFloat, height: CGFloat, sway: CGFloat) -> Path {
        var p = Path()
        let tip = CGPoint(x: base.x + sway, y: base.y - height)
        p.move(to: tip)
        p.addCurve(to: CGPoint(x: base.x + width / 2, y: base.y - height * 0.3),
                   control1: CGPoint(x: base.x + width * 0.15 + sway * 0.5, y: base.y - height * 0.75),
                   control2: CGPoint(x: base.x + width / 2, y: base.y - height * 0.55))
        p.addCurve(to: CGPoint(x: base.x - width / 2, y: base.y - height * 0.3),
                   control1: CGPoint(x: base.x + width / 2, y: base.y + height * 0.06),
                   control2: CGPoint(x: base.x - width / 2, y: base.y + height * 0.06))
        p.addCurve(to: tip,
                   control1: CGPoint(x: base.x - width / 2, y: base.y - height * 0.55),
                   control2: CGPoint(x: base.x - width * 0.15 + sway * 0.5, y: base.y - height * 0.75))
        p.closeSubpath()
        return p
    }

    static func leafPath(base: CGPoint, length: CGFloat, width: CGFloat, angle: Double) -> Path {
        var p = Path()
        p.move(to: .zero)
        p.addQuadCurve(to: CGPoint(x: length, y: 0), control: CGPoint(x: length * 0.5, y: -width))
        p.addQuadCurve(to: .zero, control: CGPoint(x: length * 0.5, y: width))
        p.closeSubpath()
        return p.applying(CGAffineTransform(rotationAngle: angle).concatenating(CGAffineTransform(translationX: base.x, y: base.y)))
    }

    static func sparklePath(center c: CGPoint, radius r: CGFloat) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: c.x, y: c.y - r))
        p.addQuadCurve(to: CGPoint(x: c.x + r, y: c.y), control: c)
        p.addQuadCurve(to: CGPoint(x: c.x, y: c.y + r), control: c)
        p.addQuadCurve(to: CGPoint(x: c.x - r, y: c.y), control: c)
        p.addQuadCurve(to: CGPoint(x: c.x, y: c.y - r), control: c)
        p.closeSubpath()
        return p
    }

    static func starPath(center c: CGPoint, outer: CGFloat, inner: CGFloat, points: Int = 5) -> Path {
        var p = Path()
        for i in 0..<(points * 2) {
            let r = i % 2 == 0 ? outer : inner
            let a = Double(i) * .pi / Double(points) - .pi / 2
            let pt = CGPoint(x: c.x + CGFloat(cos(a)) * r, y: c.y + CGFloat(sin(a)) * r)
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        return p
    }

    static func drawFlower(_ ctx: GraphicsContext, at c: CGPoint, radius r: CGFloat, petal: Color, center: Color) {
        for i in 0..<5 {
            let a = Double(i) / 5 * 2 * .pi
            let pc = CGPoint(x: c.x + CGFloat(cos(a)) * r * 0.7, y: c.y + CGFloat(sin(a)) * r * 0.7)
            ctx.fill(Path(ellipseIn: CGRect(x: pc.x - r * 0.55, y: pc.y - r * 0.55, width: r * 1.1, height: r * 1.1)), with: .color(petal))
        }
        ctx.fill(Path(ellipseIn: CGRect(x: c.x - r * 0.4, y: c.y - r * 0.4, width: r * 0.8, height: r * 0.8)), with: .color(center))
    }
}
