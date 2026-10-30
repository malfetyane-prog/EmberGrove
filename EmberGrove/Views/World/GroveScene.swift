import SwiftUI

/// Everything the scene needs to know, decoupled from GameState so previews and the focus screen can tweak it.
struct GroveSnapshot: Equatable {
    var restored: [String: String]
    var unlockedAreas: Set<String>
    var decorations: Set<String>
    var companions: [String]
    var hearthLit: Bool
    var foundCurios: Set<String>

    init() {
        restored = [:]
        unlockedAreas = ["clearing"]
        decorations = []
        companions = []
        hearthLit = false
        foundCurios = []
    }

    init(_ state: GameState) {
        restored = state.restored
        unlockedAreas = state.unlockedAreas
        decorations = state.ownedDecorations.subtracting(state.hiddenDecorations)
        companions = state.presentCompanions.map(\.id)
        hearthLit = state.hearthLit
        foundCurios = Set(state.curios.keys)
    }
}

enum SkyPhase {
    case day, dusk, night

    static func current(_ date: Date = .now) -> SkyPhase {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 6..<17: return .day
        case 17..<20: return .dusk
        default: return .night
        }
    }
}

/// The world is 1600 × 600 design units. `viewport` selects the horizontal slice to draw.
@MainActor
struct GroveScene: View {
    var snapshot: GroveSnapshot
    var phase: SkyPhase = .current()
    var viewport: ClosedRange<Double> = 0...1600
    /// Brightens the hearth while focusing (0...1).
    var hearthBoost: Double = 0

    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.emberReduceMotion) private var appReduceMotion

    var body: some View {
        let still = systemReduceMotion || appReduceMotion
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: still)) { tl in
            Canvas { ctx, size in
                let s = size.height / GroveRenderer.height
                ctx.scaleBy(x: s, y: s)
                ctx.translateBy(x: -viewport.lowerBound, y: 0)
                GroveRenderer(ctx: ctx, snap: snapshot, phase: phase,
                              t: still ? 2 : tl.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 3600),
                              still: still, viewport: viewport, hearthBoost: hearthBoost)
                    .draw()
            }
        }
        .aspectRatio((viewport.upperBound - viewport.lowerBound) / GroveRenderer.height, contentMode: .fit)
        .accessibilityElement()
        .accessibilityLabel(Text(accessibilitySummary))
    }

    private var accessibilitySummary: String {
        let names = GameContent.grove.landmarks.filter { snapshot.restored[$0.id] != nil }.map(\.name)
        if names.isEmpty { return "The grove, still frosty. The hearth is \(snapshot.hearthLit ? "lit" : "cold")." }
        return "The grove. Restored: \(names.joined(separator: ", "))."
    }
}

// MARK: - Renderer

private struct RGB {
    var r, g, b: Double
    init(_ hex: UInt32) {
        r = Double((hex >> 16) & 0xFF) / 255; g = Double((hex >> 8) & 0xFF) / 255; b = Double(hex & 0xFF) / 255
    }
    init(r: Double, g: Double, b: Double) { self.r = r; self.g = g; self.b = b }
    func mix(_ o: RGB, _ f: Double) -> RGB { RGB(r: r + (o.r - r) * f, g: g + (o.g - g) * f, b: b + (o.b - b) * f) }
    var color: Color { Color(.sRGB, red: r, green: g, blue: b) }
}

struct GroveRenderer {
    static let width: Double = 1600
    static let height: Double = 600

    let ctx: GraphicsContext
    let snap: GroveSnapshot
    let phase: SkyPhase
    let t: Double
    let still: Bool
    let viewport: ClosedRange<Double>
    let hearthBoost: Double

    private var content: GameContent { .grove }
    private var vitality: Double { Double(snap.restored.count) / Double(content.landmarks.count) }
    private var isDark: Bool { phase != .day }

    private func areaVitality(_ area: String) -> Double {
        let inArea = content.landmarks.filter { $0.area == area }
        guard !inArea.isEmpty else { return 0 }
        return Double(inArea.filter { snap.restored[$0.id] != nil }.count) / Double(inArea.count)
    }

    private func areaOf(x: Double) -> String {
        content.areas.first { x >= $0.xStart && x < $0.xEnd }?.id ?? "clearing"
    }

    static func groundY(_ x: Double) -> Double {
        let ridge = smoothstep(1170, 1360, x) * 48
        return 430 + sin(x / 140) * 8 + sin(x / 61) * 3 - ridge
    }

    private static func farHill(_ x: Double) -> Double {
        let wave: Double = sin(x / 130) * 28 + sin(x / 53 + 2) * 10
        return 300 + wave - smoothstep(1100, 1500, x) * 40
    }

    private static func midHill(_ x: Double) -> Double {
        let wave: Double = sin(x / 170 + 1) * 22 + sin(x / 71) * 8
        return 365 + wave - smoothstep(1150, 1400, x) * 40
    }

    private static func smoothstep(_ a: Double, _ b: Double, _ x: Double) -> Double {
        let t = min(1, max(0, (x - a) / (b - a)))
        return t * t * (3 - 2 * t)
    }

    private func fill(_ p: Path, _ hex: UInt32, _ opacity: Double = 1) {
        ctx.fill(p, with: .color(Color(hex: hex, opacity: opacity)))
    }

    private func ellipse(_ cx: Double, _ cy: Double, _ rx: Double, _ ry: Double) -> Path {
        Path(ellipseIn: CGRect(x: cx - rx, y: cy - ry, width: rx * 2, height: ry * 2))
    }

    private func glow(_ cx: Double, _ cy: Double, _ r: Double, _ color: Color, _ strength: Double) {
        ctx.fill(ellipse(cx, cy, r, r), with: .radialGradient(
            Gradient(colors: [color.opacity(strength), color.opacity(0)]),
            center: CGPoint(x: cx, y: cy), startRadius: 0, endRadius: r))
    }

    private func night(_ dayValue: Double) -> Double { isDark ? dayValue : 0 }

    // MARK: Draw

    func draw() {
        drawSky()
        drawHills()
        drawBackTrees()
        drawGround()
        if snap.unlockedAreas.contains("brook") { drawBrook() }
        drawPath()

        // Painter's order: back to front by anchor y
        var items: [(Double, () -> Void)] = []
        for l in content.landmarks where snap.unlockedAreas.contains(l.area) {
            if let curio = l.requiresCurio, !snap.foundCurios.contains(curio) { continue }
            if let req = l.requiresLandmark, snap.restored[req] == nil, l.id == "treehouse" { continue }
            let variant = snap.restored[l.id]
            let hex = l.variants.first { $0.id == variant }?.hex ?? l.variants[0].hex
            items.append((l.y, { drawLandmark(l.id, x: l.x, y: l.y, alive: variant != nil, hex: hex, variant: variant) }))
        }
        items.append((455, { drawHearth(x: 260, y: 455) }))
        for d in snap.decorations { items.append((decorationDepth(d), { drawDecoration(d) })) }
        for c in snap.companions { items.append((companionDepth(c), { drawCompanion(c) })) }
        // The oak's canopy should be behind everything, so give it priority.
        for item in items.sorted(by: { $0.0 < $1.0 }) { item.1() }

        drawFireflies()
        if vitality < 0.34 { drawFrost() }
        drawFog()
    }

    private func drawSky() {
        let colors: (UInt32, UInt32) = switch phase {
        case .day: (0x9ED2F2, 0xFFEBC9)
        case .dusk: (0x3B2C5A, 0xF4A877)
        case .night: (0x110C22, 0x3A2B5C)
        }
        let top = colors.0, bottom = colors.1
        let rect = CGRect(x: viewport.lowerBound - 2, y: 0, width: viewport.upperBound - viewport.lowerBound + 4, height: 600)
        ctx.fill(Path(rect), with: .linearGradient(Gradient(colors: [Color(hex: top), Color(hex: bottom)]),
                                                   startPoint: CGPoint(x: 0, y: 0), endPoint: CGPoint(x: 0, y: 420)))
        if phase != .day {
            var rng = SeededGenerator(seed: 7)
            for i in 0..<90 {
                let x = Double.random(in: 0...1600, using: &rng)
                let y = Double.random(in: 10...260, using: &rng)
                let r = Double.random(in: 0.6...1.8, using: &rng)
                let tw = still ? 0.8 : 0.55 + 0.45 * sin(t * (0.8 + Double(i % 7) * 0.3) + Double(i))
                let alpha = (phase == .night ? 0.9 : 0.45) * tw
                ctx.fill(ellipse(x, y, r, r), with: .color(.white.opacity(alpha)))
            }
            // Moon
            glow(430, 90, 70, Color(hex: 0xFFF1C9), phase == .night ? 0.35 : 0.2)
            fill(ellipse(430, 90, 22, 22), 0xFFF4D6)
            fill(ellipse(440, 84, 19, 19), phase == .night ? 0x1A1330 : 0x4A3768, 0.92)
        } else {
            glow(430, 95, 90, Color(hex: 0xFFE7A0), 0.5)
            fill(ellipse(430, 95, 26, 26), 0xFFE7A0)
            for (cx, cy, s) in [(160.0, 110.0, 1.0), (760, 70, 0.8), (1180, 120, 1.1), (1450, 80, 0.7)] {
                let drift = still ? 0 : sin(t * 0.05 + cx) * 12
                for (dx, dy, r) in [(-26.0, 6.0, 20.0), (0, 0, 28), (28, 6, 20), (10, 12, 18)] {
                    fill(ellipse(cx + drift + dx * s, cy + dy * s, r * s, r * s * 0.7), 0xFFFFFF, 0.85)
                }
            }
        }
    }

    private func wavePath(base: (Double) -> Double, bottom: Double) -> Path {
        var p = Path()
        let x0 = viewport.lowerBound - 20, x1 = viewport.upperBound + 20
        p.move(to: CGPoint(x: x0, y: bottom))
        var x = x0
        while x <= x1 {
            p.addLine(to: CGPoint(x: x, y: base(x)))
            x += 12
        }
        p.addLine(to: CGPoint(x: x1, y: bottom))
        p.closeSubpath()
        return p
    }

    private func drawHills() {
        let far = RGB(phase == .day ? 0xB9B4DE : 0x4B3B72)
        let farLush = RGB(phase == .day ? 0xA7C6D9 : 0x3E3C70)
        ctx.fill(wavePath(base: Self.farHill, bottom: 600),
                 with: .color(far.mix(farLush, vitality).color))
        let mid = RGB(phase == .day ? 0xA9B7A6 : 0x34405A)
        let midLush = RGB(phase == .day ? 0x8DBB72 : 0x2F4A4A)
        ctx.fill(wavePath(base: Self.midHill, bottom: 600),
                 with: .color(mid.mix(midLush, vitality).color))
    }

    private func drawBackTrees() {
        let trees: [(Double, Double, Double)] = [
            (30, 398, 62), (175, 388, 48), (340, 392, 56), (470, 396, 70), (560, 388, 60), (690, 384, 48),
            (930, 390, 64), (990, 380, 44), (1190, 380, 58), (1270, 372, 46), (1420, 352, 40), (1590, 350, 52),
        ]
        for (x, y, r) in trees where x > viewport.lowerBound - 90 && x < viewport.upperBound + 90 {
            let v = areaVitality(areaOf(x: x))
            let unlocked = snap.unlockedAreas.contains(areaOf(x: x))
            let bare = RGB(isDark ? 0x4E4766 : 0x9B97A8)
            let lush = RGB(isDark ? 0x2E5A45 : 0x5E9A4A)
            let canopy = bare.mix(lush, unlocked ? 0.25 + v * 0.75 : 0.1)
            fill(Path(roundedRect: CGRect(x: x - r * 0.09, y: y - r * 0.4, width: r * 0.18, height: r * 0.6), cornerRadius: 3),
                 isDark ? 0x3A2C3E : 0x7A5A44)
            let sway = still ? 0 : sin(t * 0.6 + x) * 1.5
            for (dx, dy, rr) in [(-0.45, -0.55, 0.55), (0.45, -0.55, 0.55), (0, -0.95, 0.65), (0, -0.5, 0.6)] {
                ctx.fill(ellipse(x + r * dx + sway, y + r * dy, r * rr, r * rr * 0.9), with: .color(canopy.color))
            }
            if !unlocked || v == 0 {
                fill(ellipse(x + sway, y - r * 1.25, r * 0.5, r * 0.18), 0xF4F6FF, 0.75) // snow cap
            }
        }
    }

    private func drawGround() {
        let frost = RGB(isDark ? 0x4A5A63 : 0xB8C6C3)
        let lush = RGB(isDark ? 0x2F5A3C : 0x7DB356)
        let top = frost.mix(lush, 0.2 + vitality * 0.8)
        let bottom = top.mix(RGB(isDark ? 0x152519 : 0x4C8A3A), 0.6)
        ctx.fill(wavePath(base: Self.groundY, bottom: 600),
                 with: .linearGradient(Gradient(colors: [top.color, bottom.color]),
                                       startPoint: CGPoint(x: 0, y: 380), endPoint: CGPoint(x: 0, y: 600)))
        // grass tufts
        var rng = SeededGenerator(seed: 21)
        for _ in 0..<70 {
            let x = Double.random(in: 0...1600, using: &rng)
            let y = Self.groundY(x) + Double.random(in: 15...150, using: &rng)
            guard x > viewport.lowerBound - 10, x < viewport.upperBound + 10 else { continue }
            var g = Path()
            for dx in [-3.0, 0, 3] {
                g.move(to: CGPoint(x: x + dx, y: y))
                g.addLine(to: CGPoint(x: x + dx * 1.6, y: y - 7))
            }
            ctx.stroke(g, with: .color(lush.mix(RGB(0x2F5A2A), 0.4).color.opacity(0.35 + vitality * 0.5)), lineWidth: 1.4)
        }
    }

    private func drawBrook() {
        let alive = ["lilyPond", "willowBridge", "waterWheel"].contains { snap.restored[$0] != nil }
        var p = Path()
        p.move(to: CGPoint(x: 700, y: Self.groundY(700) - 2))
        p.addCurve(to: CGPoint(x: 760, y: 600), control1: CGPoint(x: 690, y: 480), control2: CGPoint(x: 800, y: 520))
        let water: UInt32 = alive ? (isDark ? 0x3E6E9E : 0x6FB6E0) : 0xCFE0E8
        ctx.stroke(p, with: .color(Color(hex: water)), style: StrokeStyle(lineWidth: 34, lineCap: .round))
        ctx.stroke(p, with: .color(.white.opacity(alive ? 0.35 : 0.6)),
                   style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [10, 22], dashPhase: alive && !still ? -t * 30 : 0))
    }

    private func drawPath() {
        var p = Path()
        p.move(to: CGPoint(x: -20, y: 498))
        p.addCurve(to: CGPoint(x: 520, y: 505), control1: CGPoint(x: 150, y: 470), control2: CGPoint(x: 350, y: 535))
        p.addCurve(to: CGPoint(x: 1260, y: 490), control1: CGPoint(x: 800, y: 470), control2: CGPoint(x: 1000, y: 520))
        p.addCurve(to: CGPoint(x: 1620, y: 450), control1: CGPoint(x: 1400, y: 470), control2: CGPoint(x: 1500, y: 440))
        ctx.stroke(p, with: .color(Color(hex: isDark ? 0x5A4A52 : 0xD9BE8C, opacity: 0.55)),
                   style: StrokeStyle(lineWidth: 22, lineCap: .round))
    }

    // MARK: Hearth

    private func drawHearth(x: Double, y: Double) {
        let lit = snap.hearthLit
        let strength = lit ? (0.35 + hearthBoost * 0.35 + vitality * 0.2) : 0
        if lit { glow(x, y - 20, 140 + hearthBoost * 40, Color(hex: 0xFFB347), isDark ? strength : strength * 0.5) }
        // stones
        for i in 0..<9 {
            let a = Double(i) / 9 * .pi
            fill(ellipse(x + cos(a) * 34, y + 4 + sin(a) * 9, 9, 6.5), isDark ? 0x6D6577 : 0x9C96A0)
        }
        // logs
        var log1 = Path(roundedRect: CGRect(x: -26, y: -5, width: 52, height: 10), cornerRadius: 5)
        log1 = log1.applying(CGAffineTransform(rotationAngle: 0.25).concatenating(CGAffineTransform(translationX: x, y: y)))
        var log2 = Path(roundedRect: CGRect(x: -26, y: -5, width: 52, height: 10), cornerRadius: 5)
        log2 = log2.applying(CGAffineTransform(rotationAngle: -0.25).concatenating(CGAffineTransform(translationX: x, y: y)))
        fill(log1, 0x7A4A2A)
        fill(log2, 0x8B5A33)
        guard lit else {
            fill(ellipse(x, y - 2, 14, 4), 0x5A5560, 0.7)
            return
        }
        let size = 1 + hearthBoost * 0.35 + vitality * 0.3
        for (i, (dx, hex)) in [(-8.0, 0xE8674A), (8, 0xE8674A), (0, 0xFF9A1F), (0, 0xFFD27A)].enumerated() {
            let h = (i < 2 ? 30.0 : (i == 2 ? 44 : 26)) * size
            let flick = still ? 0 : sin(t * (6 + Double(i)) + Double(i)) * 3
            let flame = EmberFigure.flamePath(base: CGPoint(x: x + dx, y: y - 2), width: h * 0.55, height: h + flick, sway: flick)
            fill(flame, UInt32(hex))
        }
        // sparks
        if !still {
            for i in 0..<5 {
                let ph = (t * 0.6 + Double(i) / 5).truncatingRemainder(dividingBy: 1)
                let sx = x + sin(Double(i) * 2.1 + t) * 14
                fill(ellipse(sx, y - 30 - ph * 70, 1.6, 1.6), 0xFFD27A, 1 - ph)
            }
        }
    }

    // MARK: Landmarks

    private func drawLandmark(_ id: String, x: Double, y: Double, alive: Bool, hex: UInt32, variant: String?) {
        let dead: UInt32 = isDark ? 0x5B566A : 0x9E99A8
        if !alive, !still {
            // A gentle sparkle invites the player to restore it.
            let tw = 0.5 + 0.5 * sin(t * 2 + x)
            ctx.fill(EmberFigure.sparklePath(center: CGPoint(x: x + 18, y: y - 60), radius: 5 + 3 * tw),
                     with: .color(Color(hex: 0xFFE7A0, opacity: 0.4 + 0.5 * tw)))
        }
        switch id {
        case "mushroomRing":
            for i in 0..<6 {
                let a = Double(i) / 6 * 2 * .pi
                let mx = x + cos(a) * 46, my = y + sin(a) * 12
                let s = alive ? (0.8 + Double(i % 3) * 0.15) : 0.45
                fill(Path(roundedRect: CGRect(x: mx - 4 * s, y: my - 16 * s, width: 8 * s, height: 16 * s), cornerRadius: 3), alive ? 0xFFF1DC : dead)
                var cap = Path()
                cap.move(to: CGPoint(x: mx - 13 * s, y: my - 14 * s))
                cap.addQuadCurve(to: CGPoint(x: mx + 13 * s, y: my - 14 * s), control: CGPoint(x: mx, y: my - 38 * s))
                cap.closeSubpath()
                fill(cap, alive ? hex : dead)
                if alive {
                    fill(ellipse(mx - 4 * s, my - 21 * s, 2.5 * s, 2 * s), 0xFFF4E0)
                    fill(ellipse(mx + 5 * s, my - 19 * s, 2 * s, 1.6 * s), 0xFFF4E0)
                    if variant == "glowcap" && isDark { glow(mx, my - 20 * s, 22, Color(hex: hex), 0.45) }
                }
            }
        case "meadow":
            var rng = SeededGenerator(seed: 99)
            for _ in 0..<26 {
                let fx = x + Double.random(in: -80...85, using: &rng)
                let fy = y + Double.random(in: -10...34, using: &rng)
                let h = Double.random(in: 16...30, using: &rng)
                let sway = still ? 0 : sin(t * 1.3 + fx * 0.1) * 2.5
                var stem = Path()
                stem.move(to: CGPoint(x: fx, y: fy))
                stem.addQuadCurve(to: CGPoint(x: fx + sway, y: fy - h), control: CGPoint(x: fx, y: fy - h * 0.5))
                ctx.stroke(stem, with: .color(Color(hex: alive ? 0x4E8A3A : 0x8C8577)), lineWidth: 1.6)
                guard alive else { continue }
                let head = CGPoint(x: fx + sway, y: fy - h)
                if variant == "bluebells" {
                    for k in 0..<3 {
                        fill(ellipse(head.x + 3 + Double(k) * 1.5, head.y + Double(k) * 5, 2.6, 3.4), hex)
                    }
                } else {
                    for k in 0..<8 {
                        let a = Double(k) / 8 * 2 * .pi
                        fill(ellipse(head.x + cos(a) * 4.5, head.y + sin(a) * 4.5, 2.8, 2.8), hex)
                    }
                    fill(ellipse(head.x, head.y, 3, 3), 0x7A4A2A)
                }
            }
            if alive && !still {
                for i in 0..<2 { // bees
                    let a = t * 0.9 + Double(i) * 3
                    let bx = x + cos(a) * 60, by = y - 30 + sin(a * 2) * 10
                    fill(ellipse(bx, by, 3.5, 2.6), 0xF7C548)
                    fill(ellipse(bx, by - 3, 2.5, 1.6), 0xFFFFFF, 0.8)
                }
            }
        case "stoneLanterns":
            for lx in [x, 500.0] {
                let ly = lx == x ? y : 438
                fill(Path(roundedRect: CGRect(x: lx - 12, y: ly - 8, width: 24, height: 8), cornerRadius: 2), isDark ? 0x6D6577 : 0xA19BAA)
                fill(Path(CGRect(x: lx - 5, y: ly - 30, width: 10, height: 22)), isDark ? 0x7A7285 : 0xB2ACBA)
                fill(Path(roundedRect: CGRect(x: lx - 11, y: ly - 50, width: 22, height: 20), cornerRadius: 3), isDark ? 0x7A7285 : 0xB2ACBA)
                fill(Path(roundedRect: CGRect(x: lx - 6, y: ly - 46, width: 12, height: 12), cornerRadius: 2), alive ? hex : 0x3B3446)
                var roof = Path()
                roof.move(to: CGPoint(x: lx - 17, y: ly - 50))
                roof.addQuadCurve(to: CGPoint(x: lx + 17, y: ly - 50), control: CGPoint(x: lx, y: ly - 70))
                roof.closeSubpath()
                fill(roof, isDark ? 0x5E5770 : 0x8F889C)
                if alive { glow(lx, ly - 40, 46, Color(hex: hex), isDark ? 0.55 : 0.25) }
                else { fill(ellipse(lx - 6, ly - 52, 9, 3), 0x7DB356, 0.7) }
            }
        case "lilyPond":
            fill(ellipse(x, y, 62, 18), alive ? (isDark ? 0x2E5B82 : 0x6BB3D9) : 0x8D8A82)
            fill(ellipse(x, y - 2, 56, 13), alive ? (isDark ? 0x3C6E98 : 0x8DCBEA) : 0x9C998F, 0.8)
            if alive {
                for (dx, dy) in [(-30.0, 2.0), (12, -4), (32, 4)] {
                    let notch = Path(CGRect(x: x + dx, y: y + dy - 4, width: 11, height: 3))
                    fill(ellipse(x + dx, y + dy, 11, 4).subtracting(notch), 0x4E8A3A)
                }
                EmberFigure.drawFlower(ctx, at: CGPoint(x: x - 28, y: y - 1), radius: 4, petal: Color(hex: hex), center: Color(hex: 0xFFD27A))
                EmberFigure.drawFlower(ctx, at: CGPoint(x: x + 33, y: y + 2), radius: 3.4, petal: Color(hex: hex), center: Color(hex: 0xFFD27A))
                if !still {
                    let ripple = (t * 0.4).truncatingRemainder(dividingBy: 1)
                    ctx.stroke(ellipse(x + 5, y, 8 + ripple * 30, 2 + ripple * 7), with: .color(.white.opacity(0.5 * (1 - ripple))), lineWidth: 1)
                }
            } else {
                for dx in [-50.0, -42, 44, 52] {
                    var reed = Path()
                    reed.move(to: CGPoint(x: x + dx, y: y))
                    reed.addLine(to: CGPoint(x: x + dx + 4, y: y - 26))
                    ctx.stroke(reed, with: .color(Color(hex: 0x8C7F6A)), lineWidth: 1.5)
                }
            }
        case "willowBridge":
            let wood: UInt32 = alive ? hex : dead
            if alive {
                var arch = Path()
                arch.move(to: CGPoint(x: x - 50, y: y + 8))
                arch.addQuadCurve(to: CGPoint(x: x + 50, y: y + 8), control: CGPoint(x: x, y: y - 34))
                ctx.stroke(arch, with: .color(Color(hex: wood)), style: StrokeStyle(lineWidth: 9, lineCap: .round))
                var rail = Path()
                rail.move(to: CGPoint(x: x - 46, y: y - 8))
                rail.addQuadCurve(to: CGPoint(x: x + 46, y: y - 8), control: CGPoint(x: x, y: y - 50))
                ctx.stroke(rail, with: .color(Color(hex: wood).opacity(0.85)), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                for px in stride(from: -40.0, through: 40, by: 16) {
                    let archY = y + 8 - 21 * (1 - (px / 50) * (px / 50))
                    var post = Path()
                    post.move(to: CGPoint(x: x + px, y: archY))
                    post.addLine(to: CGPoint(x: x + px, y: archY - 15))
                    ctx.stroke(post, with: .color(Color(hex: wood)), lineWidth: 2)
                }
                if variant == "willow" {
                    for px in [-30.0, 0, 28] {
                        ctx.fill(EmberFigure.leafPath(base: CGPoint(x: x + px, y: y - 22), length: 10, width: 4, angle: 1.4), with: .color(Color(hex: 0x9CCB6E)))
                    }
                }
            } else {
                for side in [-1.0, 1.0] {
                    var stub = Path()
                    stub.move(to: CGPoint(x: x + side * 50, y: y + 8))
                    stub.addLine(to: CGPoint(x: x + side * 18, y: y - 6))
                    ctx.stroke(stub, with: .color(Color(hex: wood)), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                }
            }
        case "waterWheel":
            let wheelC = CGPoint(x: x - 30, y: y - 22)
            fill(Path(roundedRect: CGRect(x: x - 16, y: y - 50, width: 46, height: 50), cornerRadius: 3), alive ? 0xF1DFC0 : dead)
            var roof = Path()
            roof.move(to: CGPoint(x: x - 24, y: y - 48))
            roof.addLine(to: CGPoint(x: x + 7, y: y - 76))
            roof.addLine(to: CGPoint(x: x + 38, y: y - 48))
            roof.closeSubpath()
            fill(roof, alive ? hex : 0x6E6878)
            fill(Path(roundedRect: CGRect(x: x + 2, y: y - 30, width: 12, height: 14), cornerRadius: 2), alive && isDark ? 0xFFD27A : 0x5A4A52)
            let spin = alive && !still ? t * 0.8 : 0.3
            ctx.stroke(ellipse(wheelC.x, wheelC.y, 22, 22), with: .color(Color(hex: alive ? 0x8B5A33 : 0x6E6878)), lineWidth: 4)
            for k in 0..<8 {
                let a = spin + Double(k) / 8 * 2 * .pi
                var spoke = Path()
                spoke.move(to: wheelC)
                spoke.addLine(to: CGPoint(x: wheelC.x + cos(a) * 24, y: wheelC.y + sin(a) * 24))
                ctx.stroke(spoke, with: .color(Color(hex: alive ? 0x8B5A33 : 0x6E6878)), lineWidth: 2.5)
            }
        case "oldOak":
            var trunk = Path()
            trunk.move(to: CGPoint(x: x - 34, y: y))
            trunk.addCurve(to: CGPoint(x: x - 16, y: y - 170), control1: CGPoint(x: x - 18, y: y - 40), control2: CGPoint(x: x - 26, y: y - 120))
            trunk.addLine(to: CGPoint(x: x + 18, y: y - 170))
            trunk.addCurve(to: CGPoint(x: x + 36, y: y), control1: CGPoint(x: x + 26, y: y - 120), control2: CGPoint(x: x + 18, y: y - 40))
            trunk.closeSubpath()
            fill(trunk, isDark ? 0x4A3530 : 0x7A5236)
            fill(ellipse(x - 2, y - 120, 9, 12), 0x2E2238) // owl hollow
            var branches = Path()
            for (dx, dy) in [(-90.0, -230.0), (85, -240), (-40, -270), (45, -280), (-120, -180), (120, -190)] {
                branches.move(to: CGPoint(x: x, y: y - 160))
                branches.addQuadCurve(to: CGPoint(x: x + dx, y: y + dy), control: CGPoint(x: x + dx * 0.4, y: y - 170))
            }
            ctx.stroke(branches, with: .color(Color(hex: isDark ? 0x4A3530 : 0x7A5236)), style: StrokeStyle(lineWidth: 7, lineCap: .round))
            if alive {
                let sway = still ? 0 : sin(t * 0.5) * 2
                let canopy = RGB(hex).mix(RGB(isDark ? 0x10241A : 0xFFFFFF), isDark ? 0.4 : 0.0)
                let light = RGB(hex).mix(RGB(0xFFFFFF), 0.18)
                for (dx, dy, r) in [(-100.0, -200.0, 62.0), (100, -205, 62), (0, -260, 80), (-55, -275, 58), (60, -280, 56), (0, -190, 66)] {
                    ctx.fill(ellipse(x + dx + sway, y + dy, r, r * 0.85), with: .color(canopy.color))
                }
                for (dx, dy, r) in [(-70.0, -250.0, 26.0), (40, -300, 22), (95, -225, 20)] {
                    ctx.fill(ellipse(x + dx + sway, y + dy, r, r * 0.8), with: .color(light.color.opacity(0.7)))
                }
            } else {
                for (dx, dy) in [(-90.0, -232.0), (85, -242), (-40, -272), (45, -282)] {
                    fill(ellipse(x + dx, y + dy, 12, 4), 0xF4F6FF, 0.85)
                }
            }
        case "treehouse":
            if !alive && snap.restored["oldOak"] == nil { return }
            fill(Path(CGRect(x: x - 40, y: y + 2, width: 80, height: 6)), 0x6E4422)
            fill(Path(roundedRect: CGRect(x: x - 30, y: y - 40, width: 60, height: 42), cornerRadius: 4), alive ? 0xE8C99A : dead)
            var roof = Path()
            roof.move(to: CGPoint(x: x - 38, y: y - 38))
            roof.addLine(to: CGPoint(x: x, y: y - 68))
            roof.addLine(to: CGPoint(x: x + 38, y: y - 38))
            roof.closeSubpath()
            fill(roof, alive ? hex : 0x6E6878)
            fill(ellipse(x, y - 20, 9, 9), alive ? (isDark ? 0xFFD27A : 0x8DCBEA) : 0x3B3446)
            if alive && isDark { glow(x, y - 20, 40, Color(hex: 0xFFD27A), 0.4) }
            var ladder = Path()
            for side in [-1.0, 1.0] {
                ladder.move(to: CGPoint(x: x + 22 + side * 5, y: y + 8))
                ladder.addLine(to: CGPoint(x: x + 22 + side * 5, y: y + 120))
            }
            for k in 0..<7 {
                ladder.move(to: CGPoint(x: x + 17, y: y + 20 + Double(k) * 15))
                ladder.addLine(to: CGPoint(x: x + 27, y: y + 20 + Double(k) * 15))
            }
            ctx.stroke(ladder, with: .color(Color(hex: 0x6E4422)), lineWidth: 2)
        case "fireflyHollow":
            fill(Path(roundedRect: CGRect(x: x - 46, y: y - 26, width: 92, height: 30), cornerRadius: 15), isDark ? 0x5A3B2A : 0x8B5A33)
            fill(ellipse(x - 42, y - 11, 8, 14), 0x3A2318)
            fill(ellipse(x - 42, y - 11, 5, 10), alive ? hex : 0x1E1416, alive ? 0.8 : 1)
            fill(ellipse(x + 10, y - 27, 22, 5), 0x7DB356, 0.7)
            if alive {
                for i in 0..<14 {
                    let a = (still ? 0 : t * 0.5) + Double(i) * 0.9
                    let r = 20 + Double(i) * 4
                    let fx = x - 30 + cos(a) * r * 0.9, fy = y - 40 - Double(i) * 4 + sin(a * 1.3) * 10
                    glow(fx, fy, 9, Color(hex: hex), 0.8)
                    fill(ellipse(fx, fy, 1.8, 1.8), 0xFFFFFF)
                }
            }
        case "standingStones":
            for (dx, h, tilt) in [(-38.0, 58.0, -0.06), (0, 74, 0), (38, 52, 0.07)] {
                var stone = Path(roundedRect: CGRect(x: -13, y: -h, width: 26, height: h), cornerRadius: 10)
                stone = stone.applying(CGAffineTransform(rotationAngle: tilt).concatenating(CGAffineTransform(translationX: x + dx, y: y)))
                fill(stone, isDark ? 0x6D6880 : 0xA39FB2)
                if alive {
                    let pulse = still ? 0.8 : 0.6 + 0.4 * sin(t * 1.5 + dx)
                    var rune = Path()
                    rune.move(to: CGPoint(x: x + dx - 5, y: y - h * 0.7))
                    rune.addLine(to: CGPoint(x: x + dx + 4, y: y - h * 0.55))
                    rune.addLine(to: CGPoint(x: x + dx - 3, y: y - h * 0.4))
                    rune.move(to: CGPoint(x: x + dx, y: y - h * 0.3))
                    rune.addLine(to: CGPoint(x: x + dx, y: y - h * 0.15))
                    ctx.stroke(rune, with: .color(Color(hex: hex).opacity(pulse)), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    glow(x + dx, y - h * 0.45, 30, Color(hex: hex), 0.35 * pulse)
                }
            }
        case "moonflowers":
            var rng = SeededGenerator(seed: 42)
            for _ in 0..<12 {
                let fx = x + Double.random(in: -60...60, using: &rng)
                let fy = y + Double.random(in: -6...26, using: &rng)
                let h = Double.random(in: 14...26, using: &rng)
                var stem = Path()
                stem.move(to: CGPoint(x: fx, y: fy))
                stem.addLine(to: CGPoint(x: fx, y: fy - h))
                ctx.stroke(stem, with: .color(Color(hex: 0x4E7A5A)), lineWidth: 1.5)
                if alive {
                    if isDark { glow(fx, fy - h, 14, Color(hex: hex), 0.5) }
                    EmberFigure.drawFlower(ctx, at: CGPoint(x: fx, y: fy - h), radius: 5, petal: Color(hex: hex), center: Color(hex: 0xFFF4D6))
                } else {
                    fill(ellipse(fx, fy - h, 3, 5), 0x8C9A8A)
                }
            }
        case "starShrine":
            var arch = Path()
            arch.move(to: CGPoint(x: x - 30, y: y))
            arch.addLine(to: CGPoint(x: x - 30, y: y - 50))
            arch.addQuadCurve(to: CGPoint(x: x + 30, y: y - 50), control: CGPoint(x: x, y: y - 90))
            arch.addLine(to: CGPoint(x: x + 30, y: y))
            ctx.stroke(arch, with: .color(Color(hex: isDark ? 0x8A85A0 : 0xB8B3C6)), style: StrokeStyle(lineWidth: 10, lineCap: .round))
            if alive {
                let bob = still ? 0 : sin(t * 1.2) * 4
                glow(x, y - 42 + bob, 70, Color(hex: hex), 0.6)
                fill(EmberFigure.starPath(center: CGPoint(x: x, y: y - 42 + bob), outer: 14, inner: 6), hex)
                fill(EmberFigure.starPath(center: CGPoint(x: x, y: y - 42 + bob), outer: 7, inner: 3), 0xFFFFFF)
            }
        default: break
        }
    }

    // MARK: Decorations

    private func decorationDepth(_ id: String) -> Double {
        switch id {
        case "steppingStones": 480
        case "paperLanterns": 300
        case "fairyLights": 530
        case "toadstoolStools": 482
        default: 445
        }
    }

    private func drawDecoration(_ id: String) {
        switch id {
        case "steppingStones":
            for (i, sx) in stride(from: 300.0, through: 470, by: 34).enumerated() {
                fill(ellipse(sx, 492 + (i % 2 == 0 ? 0 : 6), 12, 5), isDark ? 0x7A7285 : 0xC9C3CF)
            }
        case "toadstoolStools":
            for (sx, sy) in [(218.0, 482.0), (308, 486)] {
                fill(Path(roundedRect: CGRect(x: sx - 5, y: sy - 12, width: 10, height: 12), cornerRadius: 3), 0xFFF1DC)
                fill(ellipse(sx, sy - 13, 13, 6), 0xD9534F)
                fill(ellipse(sx - 4, sy - 15, 2, 1.4), 0xFFF4E0)
            }
        case "windChimes":
            fill(Path(CGRect(x: 468, y: 395, width: 4, height: 55)), 0x7A5236)
            fill(Path(CGRect(x: 452, y: 395, width: 36, height: 3)), 0x7A5236)
            for k in 0..<4 {
                let cx = 456 + Double(k) * 9
                let sway = still ? 0 : sin(t * 2 + Double(k)) * 2
                var line = Path()
                line.move(to: CGPoint(x: cx, y: 398))
                line.addLine(to: CGPoint(x: cx + sway, y: 408))
                ctx.stroke(line, with: .color(Color(hex: 0xB8A88A)), lineWidth: 0.8)
                fill(Path(roundedRect: CGRect(x: cx + sway - 1.5, y: 408, width: 3, height: 12 + Double(k % 2) * 4), cornerRadius: 1.5), 0xC9B27C)
            }
        case "birdhouse":
            fill(Path(CGRect(x: 178, y: 410, width: 4, height: 40)), 0x7A5236)
            fill(Path(roundedRect: CGRect(x: 168, y: 392, width: 24, height: 20), cornerRadius: 2), 0xE3A962)
            var roof = Path()
            roof.move(to: CGPoint(x: 164, y: 394))
            roof.addLine(to: CGPoint(x: 180, y: 380))
            roof.addLine(to: CGPoint(x: 196, y: 394))
            roof.closeSubpath()
            fill(roof, 0xC94A47)
            fill(ellipse(180, 401, 3.5, 3.5), 0x2E2238)
        case "paperLanterns":
            var string = Path()
            string.move(to: CGPoint(x: 70, y: 330))
            string.addQuadCurve(to: CGPoint(x: 470, y: 336), control: CGPoint(x: 270, y: 380))
            ctx.stroke(string, with: .color(Color(hex: 0x5A4A52)), lineWidth: 1)
            let colors: [UInt32] = [0xFFB347, 0xE8674A, 0xFFD27A, 0xB79CFF, 0xFFB347, 0xE8674A, 0xFFD27A]
            for (k, hex) in colors.enumerated() {
                let f = (Double(k) + 0.5) / Double(colors.count)
                let lx = 70 + f * 400
                let ly = (1 - f) * (1 - f) * 330 + 2 * (1 - f) * f * 380 + f * f * 336
                let sway = still ? 0 : sin(t * 1.4 + Double(k)) * 1.5
                if isDark { glow(lx + sway, ly + 10, 22, Color(hex: hex), 0.45) }
                fill(Path(roundedRect: CGRect(x: lx - 6 + sway, y: ly + 2, width: 12, height: 15), cornerRadius: 5), hex)
            }
        case "fairyLights":
            for (k, fx) in stride(from: 60.0, through: 500, by: 55).enumerated() {
                let fy = 532 + (k % 2 == 0 ? 0 : 10.0)
                let pulse = still ? 0.8 : 0.6 + 0.4 * sin(t * 2 + Double(k))
                glow(fx, fy - 8, 18, Color(hex: 0xFFE07A), 0.5 * pulse)
                fill(Path(roundedRect: CGRect(x: fx - 5, y: fy - 14, width: 10, height: 13), cornerRadius: 3), 0xDCEFF5, 0.8)
                fill(ellipse(fx, fy - 8, 2, 2), 0xFFF4C0)
            }
        default: break
        }
    }

    // MARK: Companions

    private func companionDepth(_ id: String) -> Double {
        switch id {
        case "tansy": 476
        case "mosslings": 470
        case "pebble": 471
        case "wren": 426
        case "hoot": 441
        case "glimmer": 461
        case "nox": 440
        default: 450
        }
    }

    func drawCompanion(_ id: String) {
        let bob = still ? 0 : sin(t * 1.8 + Double(id.count)) * 1.5
        switch id {
        case "tansy":
            let x = 200.0, y = 476.0
            let wag = still ? 0 : sin(t * 2.4) * 0.25
            var tail = ellipse(0, 0, 20, 9).applying(CGAffineTransform(rotationAngle: -0.6 + wag).concatenating(CGAffineTransform(translationX: x - 18, y: y - 10)))
            fill(tail, 0xE98A3C)
            tail = ellipse(0, 0, 6, 5).applying(CGAffineTransform(translationX: x - 33 + wag * 10, y: y - 21))
            fill(tail, 0xFFF4E0)
            fill(ellipse(x, y - 12 + bob * 0.3, 15, 13), 0xF09A4A)
            fill(ellipse(x + 2, y - 8 + bob * 0.3, 8, 8), 0xFFF4E0)
            let hy = y - 30 + bob
            fill(ellipse(x + 4, hy, 12, 10), 0xF09A4A)
            for side in [-1.0, 1.0] {
                var ear = Path()
                ear.move(to: CGPoint(x: x + 4 + side * 9, y: hy - 4))
                ear.addLine(to: CGPoint(x: x + 4 + side * 9, y: hy - 18))
                ear.addLine(to: CGPoint(x: x + 4 + side * 2, y: hy - 8))
                ear.closeSubpath()
                fill(ear, 0xD9782E)
            }
            fill(ellipse(x + 13, hy + 3, 5, 3.5), 0xFFF4E0)
            fill(ellipse(x + 17, hy + 2, 1.6, 1.4), 0x2E2238)
            fill(ellipse(x + 3, hy - 1, 1.6, isDark ? 0.6 : 1.8), 0x2E2238)
            fill(ellipse(x + 10, hy - 1, 1.6, isDark ? 0.6 : 1.8), 0x2E2238)
        case "mosslings":
            for (k, (sx, sy)) in [(80.0, 470.0), (150, 474), (168, 466)].enumerated() {
                let crawl = still ? 0 : sin(t * 0.3 + Double(k)) * 4
                fill(ellipse(sx + crawl + 5, sy, 9, 3.5), 0xB9C79A)
                fill(ellipse(sx + crawl, sy - 6, 7, 7), 0x8DBF5A)
                ctx.stroke(ellipse(sx + crawl, sy - 6, 3.5, 3.5), with: .color(Color(hex: 0x5E8F3E)), lineWidth: 1.2)
                fill(ellipse(sx + crawl + 12, sy - 6, 1.2, 1.2), 0x2E2238)
            }
        case "pebble":
            let x = 612.0, y = 466.0 + bob * 0.5
            fill(ellipse(x, y, 12, 8), 0x6DB359)
            fill(ellipse(x, y + 2, 8, 4), 0xC6E58E)
            for side in [-1.0, 1.0] {
                fill(ellipse(x + side * 6, y - 8, 4.5, 4.5), 0x6DB359)
                fill(ellipse(x + side * 6, y - 8, 2, 2.2), 0x2E2238)
            }
            if !still && sin(t * 0.7) > 0.8 { // occasional croak bubble
                fill(ellipse(x, y + 3, 6, 5), 0xE6F5C8, 0.9)
            }
        case "wren":
            let x = 857.0, y = 426.0 - 75 + bob
            fill(ellipse(x, y, 8, 6), 0x9A6A44)
            fill(ellipse(x + 6, y - 5, 4.5, 4.5), 0x9A6A44)
            var tail = Path()
            tail.move(to: CGPoint(x: x - 6, y: y - 1))
            tail.addLine(to: CGPoint(x: x - 13, y: y - 11))
            tail.addLine(to: CGPoint(x: x - 9, y: y - 12))
            tail.closeSubpath()
            fill(tail, 0x7A5236)
            var beak = Path()
            beak.move(to: CGPoint(x: x + 10, y: y - 6))
            beak.addLine(to: CGPoint(x: x + 14, y: y - 5))
            beak.addLine(to: CGPoint(x: x + 10, y: y - 4))
            fill(beak, 0xF2C14E)
            fill(ellipse(x + 7, y - 6, 1, 1), 0x2E2238)
        case "hoot":
            let x = 1058.0, y = 322.0 + bob * 0.4
            fill(ellipse(x, y, 11, 13), 0x8B6A4E)
            fill(ellipse(x, y + 4, 7, 7), 0xD9C3A0)
            let blink = !still && (t.truncatingRemainder(dividingBy: 5) < 0.2)
            for side in [-1.0, 1.0] {
                fill(ellipse(x + side * 5, y - 5, 5, 5), 0xFFF4E0)
                fill(ellipse(x + side * 5, y - 5, 2.4, blink ? 0.4 : 2.4), 0x2E2238)
                var tuft = Path()
                tuft.move(to: CGPoint(x: x + side * 4, y: y - 11))
                tuft.addLine(to: CGPoint(x: x + side * 11, y: y - 18))
                tuft.addLine(to: CGPoint(x: x + side * 10, y: y - 9))
                fill(tuft, 0x8B6A4E)
            }
        case "glimmer":
            let a = still ? 0 : t * 0.8
            let x = 1200 + cos(a) * 30, y = 430 + sin(a * 1.6) * 12
            glow(x, y, 26, Color(hex: 0xFFE07A), 0.9)
            fill(ellipse(x, y, 3, 3), 0xFFFFFF)
            fill(EmberFigure.starPath(center: CGPoint(x: x, y: y - 7), outer: 3.5, inner: 1.5), 0xF2C14E)
        case "nox":
            let x = 1385.0, y = 440.0
            let hop = still ? 0 : max(0, sin(t * 1.4)) * 6
            fill(ellipse(x, y - 10 - hop, 14, 11), 0xD9DCEB)
            fill(ellipse(x + 10, y - 20 - hop, 8, 7), 0xD9DCEB)
            for (dx, ang) in [(8.0, -0.2), (13, 0.15)] {
                let ear = ellipse(0, -11, 3.2, 11).applying(CGAffineTransform(rotationAngle: ang).concatenating(CGAffineTransform(translationX: x + dx, y: y - 25 - hop)))
                fill(ear, 0xC9CDE0)
            }
            fill(ellipse(x + 13, y - 21 - hop, 1.4, 1.6), 0x2E2238)
            fill(ellipse(x - 13, y - 12 - hop, 4, 4), 0xFFFFFF)
            let tw = still ? 1 : 0.6 + 0.4 * sin(t * 3)
            ctx.fill(EmberFigure.sparklePath(center: CGPoint(x: x - 4, y: y - 34 - hop), radius: 4 * tw), with: .color(Color(hex: 0xBFE2FF)))
        default: break
        }
    }

    // MARK: Atmosphere

    private func drawFireflies() {
        let count = 3 + snap.restored.count * 3
        let strength = phase == .day ? 0.35 : 0.9
        for i in 0..<count {
            let seedX = Double((i * 7919) % 1600)
            let area = areaOf(x: seedX)
            guard snap.unlockedAreas.contains(area), seedX > viewport.lowerBound - 30, seedX < viewport.upperBound + 30 else { continue }
            let a = still ? Double(i) : t * (0.2 + Double(i % 5) * 0.05) + Double(i)
            let x = seedX + sin(a) * 30
            let y = 360 + Double((i * 137) % 140) + cos(a * 1.3) * 18
            let pulse = still ? 0.8 : 0.5 + 0.5 * sin(t * 2.5 + Double(i) * 1.7)
            glow(x, y, 10, Color(hex: 0xFFE07A), strength * pulse * 0.7)
            fill(ellipse(x, y, 1.4, 1.4), 0xFFF8D6, strength * pulse)
        }
    }

    private func drawFrost() {
        guard !still else { return }
        for i in 0..<26 {
            let x0 = Double((i * 263) % 1600)
            guard x0 > viewport.lowerBound - 20, x0 < viewport.upperBound + 20 else { continue }
            let fall = (t * (0.03 + Double(i % 4) * 0.01) + Double(i) * 0.13).truncatingRemainder(dividingBy: 1)
            let x = x0 + sin(t * 0.5 + Double(i)) * 14
            let y = fall * 560
            fill(ellipse(x, y, 1.8, 1.8), 0xFFFFFF, 0.6 * (1 - vitality * 2.5))
        }
    }

    private func drawFog() {
        for area in content.areas where !snap.unlockedAreas.contains(area.id) {
            let x0 = area.xStart - 50, x1 = area.xEnd + 10
            guard x1 > viewport.lowerBound, x0 < viewport.upperBound else { continue }
            let fogColor = Color(hex: isDark ? 0x2A2245 : 0xEDE7F5)
            ctx.fill(Path(CGRect(x: x0, y: 0, width: x1 - x0, height: 600)), with: .linearGradient(
                Gradient(stops: [.init(color: fogColor.opacity(0), location: 0), .init(color: fogColor.opacity(0.94), location: 0.12),
                                 .init(color: fogColor.opacity(0.97), location: 1)]),
                startPoint: CGPoint(x: x0, y: 0), endPoint: CGPoint(x: x1, y: 0)))
            for k in 0..<5 {
                let drift = still ? 0 : sin(t * 0.15 + Double(k)) * 20
                let cx = x0 + 60 + Double(k) * (x1 - x0 - 60) / 5 + drift
                fill(ellipse(cx, 380 + Double(k % 2) * 60, 90, 40), isDark ? 0x3A3060 : 0xFFFFFF, 0.5)
            }
        }
    }
}
