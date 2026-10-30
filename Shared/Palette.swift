import SwiftUI

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

/// Raw palette shared by the app, widgets and Live Activities.
enum Palette {
    // Dusk
    static let duskDeep = Color(hex: 0x1E1630)
    static let dusk = Color(hex: 0x2C2145)
    static let duskSoft = Color(hex: 0x45356A)
    static let lavender = Color(hex: 0xB9A6E0)

    // Warmth
    static let amber = Color(hex: 0xF5A524)
    static let amberGlow = Color(hex: 0xFFD27A)
    static let coral = Color(hex: 0xE8674A)
    static let honey = Color(hex: 0xE3A962)

    // Grove
    static let moss = Color(hex: 0x6E9F4E)
    static let mossDeep = Color(hex: 0x3F6B3A)
    static let mossLight = Color(hex: 0xA9D46F)

    // Paper
    static let cream = Color(hex: 0xFFF4E0)
    static let parchment = Color(hex: 0xF4E6CB)
    static let ink = Color(hex: 0x2E2238)
}

/// Colors of Ember's inner flame. Ids are stored in `EmberAppearance.flameTint`.
struct FlameTint: Hashable {
    let id: String
    let name: String
    let core: Color
    let glow: Color

    static let all: [FlameTint] = [
        FlameTint(id: "amber", name: "Amber", core: Color(hex: 0xFF9A1F), glow: Color(hex: 0xFFD27A)),
        FlameTint(id: "gold", name: "Hearth Gold", core: Color(hex: 0xFFC524), glow: Color(hex: 0xFFE89A)),
        FlameTint(id: "rose", name: "Rosefire", core: Color(hex: 0xFF6F91), glow: Color(hex: 0xFFB8C8)),
        FlameTint(id: "jade", name: "Jadeleaf", core: Color(hex: 0x4FD08A), glow: Color(hex: 0xB5F2CC)),
        FlameTint(id: "azure", name: "Azure Star", core: Color(hex: 0x5AB4FF), glow: Color(hex: 0xBFE2FF)),
        FlameTint(id: "violet", name: "Moonviolet", core: Color(hex: 0xA587FF), glow: Color(hex: 0xDCCFFF)),
    ]

    static func named(_ id: String) -> FlameTint {
        all.first { $0.id == id } ?? all[0]
    }
}

private struct EmberReduceMotionKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// The in-app "Reduce motion" setting, combined with the system setting where it's read.
    var emberReduceMotion: Bool {
        get { self[EmberReduceMotionKey.self] }
        set { self[EmberReduceMotionKey.self] = newValue }
    }
}
