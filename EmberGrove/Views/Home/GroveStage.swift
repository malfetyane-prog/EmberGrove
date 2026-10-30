import SwiftUI

/// A slice of the grove with Ember placed in it, scaled to whatever space it's given.
/// Used by Home (preview), Focus (full-bleed night scene) and World (the whole map).
@MainActor
struct GroveStage: View {
    var snapshot: GroveSnapshot
    var appearance: EmberAppearance
    var mood: EmberMood
    var phase: SkyPhase = .current()
    var viewport: ClosedRange<Double>
    var emberX: Double = 322
    var hearthBoost: Double = 0
    var emberSize: Double = 96
    var onEmberTap: (() -> Void)? = nil

    var body: some View {
        GeometryReader { geo in
            let s: Double = Double(geo.size.height) / GroveRenderer.height
            let size: Double = emberSize * s
            let y: Double = GroveRenderer.groundY(emberX) + 52
            ZStack(alignment: .topLeading) {
                GroveScene(snapshot: snapshot, phase: phase, viewport: viewport, hearthBoost: hearthBoost)
                    .frame(width: geo.size.width, height: geo.size.height)
                EmberView(appearance: appearance, mood: mood)
                    .frame(width: size, height: size)
                    .position(x: (emberX - viewport.lowerBound) * s, y: y * s - size * 0.41)
                    .onTapGesture { onEmberTap?() }
                    .accessibilityAddTraits(onEmberTap == nil ? [] : .isButton)
            }
        }
        .aspectRatio((viewport.upperBound - viewport.lowerBound) / GroveRenderer.height, contentMode: .fit)
    }
}

/// Little things Ember says when you tap it. Never guilt, always warmth.
enum EmberChatter {
    static func line(for state: GameState, now: Date = .now) -> String {
        var options = [
            "I kept the fire warm for you.",
            "Shall we focus together?",
            "The grove feels different lately. Brighter.",
            "I like it when you're here.",
            "Every minute counts. Even small ones.",
        ]
        if state.canChoosePath { options = ["I feel… different. Like I'm about to change!"] }
        else if state.renewalsAvailable > 0 && !state.availableLandmarks.isEmpty { options.append("We could fix something in the grove! Want to choose?") }
        if state.todayMinutes == 0 { options.append("A short session is a lovely way to start.") }
        if state.todayMinutes >= state.settings.dailyGoalMinutes { options.append("You did so much today. Rest is good too.") }
        if !state.presentCompanions.isEmpty, let friend = state.presentCompanions.randomElement() {
            options.append("\(friend.name) was asking about you.")
        }
        let hour = Calendar.current.component(.hour, from: now)
        if hour >= 22 || hour < 5 { options.append("It's late. Maybe one more short one, then sleep?") }
        return options.randomElement() ?? options[0]
    }
}
