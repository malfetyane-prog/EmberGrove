import SwiftUI

extension Color {
    /// A color that adapts to light and dark mode.
    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                           blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
        })
    }
}

/// Semantic tokens for the app UI. Raw colors live in `Palette` (shared with widgets).
enum Theme {
    static let background = Color(light: 0xFBF3E4, dark: 0x171126)
    static let backgroundDeep = Color(light: 0xF3E4C8, dark: 0x0F0B1A)
    static let card = Color(light: 0xFFFAF0, dark: 0x251C3B)
    static let cardRaised = Color(light: 0xFFFFFF, dark: 0x30264A)
    static let ink = Color(light: 0x2E2238, dark: 0xF6EEDD)
    static let inkSoft = Color(light: 0x6E6178, dark: 0xB7ABC9)
    static let line = Color(light: 0xE8D9BC, dark: 0x3A2F55)
    static let accent = Palette.amber
    static let moss = Color(light: 0x4F8A3A, dark: 0x8FCB6A)
    static let seeds = Color(light: 0x8A6A2E, dark: 0xE9C27A)

    static let radius: CGFloat = 22
    static let gutter: CGFloat = 20

    static var backgroundGradient: LinearGradient {
        LinearGradient(colors: [background, backgroundDeep], startPoint: .top, endPoint: .bottom)
    }
}

extension Font {
    static func display(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
    static let storySerif = Font.system(.title3, design: .serif)
    static let label = Font.system(.subheadline, design: .rounded, weight: .semibold)
    static let caption2Rounded = Font.system(.caption, design: .rounded, weight: .medium)
}

// MARK: - Components

@MainActor
struct Card<Content: View>: View {
    var padding: CGFloat = 16
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous).strokeBorder(Theme.line.opacity(0.7), lineWidth: 1))
            .shadow(color: Palette.ink.opacity(0.06), radius: 10, y: 4)
    }
}

@MainActor
struct SectionTitle: View {
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.display(20)).foregroundStyle(Theme.ink)
            if let subtitle { Text(subtitle).font(.subheadline).foregroundStyle(Theme.inkSoft) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityAddTraits(.isHeader)
    }
}

struct GlowButtonStyle: ButtonStyle {
    var prominent = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.display(18, weight: .bold))
            .foregroundStyle(prominent ? Palette.ink : Theme.ink)
            .padding(.vertical, 16)
            .padding(.horizontal, 28)
            .frame(maxWidth: .infinity)
            .background {
                if prominent {
                    Capsule().fill(LinearGradient(colors: [Palette.amberGlow, Palette.amber], startPoint: .top, endPoint: .bottom))
                        .shadow(color: Palette.amber.opacity(configuration.isPressed ? 0.2 : 0.45), radius: configuration.isPressed ? 6 : 16, y: 6)
                } else {
                    Capsule().fill(Theme.cardRaised)
                        .overlay(Capsule().strokeBorder(Theme.line, lineWidth: 1))
                }
            }
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

@MainActor
struct Chip: View {
    let title: String
    var symbol: String? = nil
    var selected: Bool
    var tint: Color = Palette.amber

    var body: some View {
        HStack(spacing: 6) {
            if let symbol { Image(systemName: symbol).font(.caption.weight(.bold)) }
            Text(title).font(.label)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .foregroundStyle(selected ? Palette.ink : Theme.ink)
        .background(Capsule().fill(selected ? tint.opacity(0.9) : Theme.cardRaised))
        .overlay(Capsule().strokeBorder(selected ? .clear : Theme.line, lineWidth: 1))
        .contentShape(Capsule())
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }
}

/// XP-style progress bar with a warm glow at its leading edge.
@MainActor
struct GlowBar: View {
    var value: Double
    var tint: Color = Palette.amber
    var height: CGFloat = 12

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.line.opacity(0.6))
                Capsule()
                    .fill(LinearGradient(colors: [tint.opacity(0.75), tint], startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(height, geo.size.width * min(1, max(0, value))))
                    .shadow(color: tint.opacity(0.6), radius: 6)
            }
        }
        .frame(height: height)
        .accessibilityElement()
        .accessibilityValue(Text("\(Int(value * 100)) percent"))
    }
}

@MainActor
struct SeedBadge: View {
    let amount: Int

    var body: some View {
        HStack(spacing: 5) {
            SeedIcon().frame(width: 14, height: 16)
            Text("\(amount)").font(.label).monospacedDigit()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Capsule().fill(Theme.cardRaised))
        .overlay(Capsule().strokeBorder(Theme.line, lineWidth: 1))
        .foregroundStyle(Theme.seeds)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(amount) seeds")
    }
}

/// The seed currency glyph, drawn so it matches the illustrated world.
@MainActor
struct SeedIcon: View {
    var body: some View {
        Canvas { ctx, size in
            let w = size.width, h = size.height
            var seed = Path()
            seed.move(to: CGPoint(x: w * 0.5, y: 0))
            seed.addQuadCurve(to: CGPoint(x: w * 0.5, y: h), control: CGPoint(x: w * 1.15, y: h * 0.55))
            seed.addQuadCurve(to: CGPoint(x: w * 0.5, y: 0), control: CGPoint(x: -w * 0.15, y: h * 0.55))
            ctx.fill(seed, with: .linearGradient(Gradient(colors: [Color(hex: 0xE9B65C), Color(hex: 0xA8702E)]),
                                                 startPoint: .zero, endPoint: CGPoint(x: w, y: h)))
            var line = Path()
            line.move(to: CGPoint(x: w * 0.5, y: h * 0.2))
            line.addQuadCurve(to: CGPoint(x: w * 0.5, y: h * 0.85), control: CGPoint(x: w * 0.68, y: h * 0.5))
            ctx.stroke(line, with: .color(.white.opacity(0.5)), lineWidth: 1)
        }
    }
}

@MainActor
struct LevelBadge: View {
    let level: Int

    var body: some View {
        Text("Lv \(level)")
            .font(.display(13, weight: .heavy))
            .foregroundStyle(Palette.ink)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Capsule().fill(Palette.amberGlow))
            .accessibilityLabel("Level \(level)")
    }
}

@MainActor
struct HeartsRow: View {
    let hearts: Int
    var size: CGFloat = 12

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<10, id: \.self) { i in
                Image(systemName: i < hearts ? "heart.fill" : "heart")
                    .font(.system(size: size))
                    .foregroundStyle(i < hearts ? Palette.coral : Theme.line)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("\(hearts) of 10 hearts")
    }
}

extension View {
    func screenBackground() -> some View {
        background(Theme.backgroundGradient.ignoresSafeArea())
    }
}

func formatDuration(_ seconds: TimeInterval, alwaysHours: Bool = false) -> String {
    let total = max(0, Int(seconds.rounded(.down)))
    let h = total / 3600, m = (total % 3600) / 60, s = total % 60
    if h > 0 || alwaysHours { return String(format: "%d:%02d:%02d", h, m, s) }
    return String(format: "%02d:%02d", m, s)
}

func formatMinutes(_ minutes: Int) -> String {
    if minutes < 60 { return "\(minutes)m" }
    let h = minutes / 60, m = minutes % 60
    return m == 0 ? "\(h)h" : "\(h)h \(m)m"
}

/// Runs `work` on the main actor after a short delay (for choreographing UI beats).
@MainActor
func after(_ seconds: Double, _ work: @escaping @MainActor () -> Void) {
    Task { @MainActor in
        try? await Task.sleep(for: .seconds(seconds))
        work()
    }
}
