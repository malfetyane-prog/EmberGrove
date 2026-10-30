import SwiftUI

@MainActor
struct HomeView: View {
    @Environment(GameStore.self) private var store
    @State private var mood: EmberMood = .idle
    @State private var speech: String?
    @State private var showSettings = false

    private var state: GameState { store.state }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    header
                    hero
                    choicesCard
                    todayCard
                    questsPreview
                }
                .padding(.horizontal, Theme.gutter)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .screenBackground()
            .safeAreaInset(edge: .bottom) { startBar }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showSettings) {
                SettingsView().environment(store)
            }
        }
    }

    // MARK: Sections

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(greeting).font(.subheadline).foregroundStyle(Theme.inkSoft)
                HStack(spacing: 8) {
                    Text(state.emberName).font(.display(30, weight: .heavy)).foregroundStyle(Theme.ink)
                    LevelBadge(level: state.level)
                }
            }
            Spacer()
            SeedBadge(amount: state.seeds)
            Button { showSettings = true } label: {
                Image(systemName: "gearshape.fill")
                    .font(.title3)
                    .foregroundStyle(Theme.inkSoft)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Settings")
        }
        .padding(.top, 8)
    }

    private var hero: some View {
        ZStack(alignment: .top) {
            GroveStage(snapshot: GroveSnapshot(state), appearance: state.appearance, mood: mood,
                       viewport: 40...480, emberSize: 110, onEmberTap: pokeEmber)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).strokeBorder(Theme.line, lineWidth: 1))
                .shadow(color: Palette.ink.opacity(0.12), radius: 16, y: 8)

            if let speech {
                Text(speech)
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .foregroundStyle(Palette.ink)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Palette.cream, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: .black.opacity(0.15), radius: 8, y: 3)
                    .padding(.top, 14)
                    .padding(.horizontal, 24)
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
            }

            VStack {
                Spacer()
                HStack {
                    Text(state.stage.name)
                        .font(.display(13, weight: .bold))
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(.ultraThinMaterial, in: Capsule())
                    Spacer()
                    Text("\(state.restored.count)/\(store.content.landmarks.count) restored")
                        .font(.display(13, weight: .bold))
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(.ultraThinMaterial, in: Capsule())
                }
                .foregroundStyle(Theme.ink)
                .padding(12)
            }
        }
    }

    @ViewBuilder
    private var choicesCard: some View {
        if state.canChoosePath {
            choiceButton(symbol: "sparkles", title: "\(state.emberName) is ready to evolve",
                         subtitle: "Choose a path: Hearth, Bloom or Starlight") { store.route = .choosePath }
        }
        if state.renewalsAvailable > 0 && !state.availableLandmarks.isEmpty {
            choiceButton(symbol: "leaf.fill", title: "The grove is ready to change",
                         subtitle: "\(state.renewalsAvailable) restoration\(state.renewalsAvailable == 1 ? "" : "s") to choose") { store.route = .restore }
        }
    }

    private func choiceButton(symbol: String, title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: symbol)
                    .font(.title2)
                    .foregroundStyle(Palette.ink)
                    .frame(width: 48, height: 48)
                    .background(Circle().fill(Palette.amberGlow))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.label).foregroundStyle(Theme.ink)
                    Text(subtitle).font(.caption).foregroundStyle(Theme.inkSoft)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(Theme.inkSoft)
            }
            .padding(14)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous).strokeBorder(Palette.amber.opacity(0.6), lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }

    private var todayCard: some View {
        Card {
            HStack(spacing: 18) {
                ZStack {
                    Circle().stroke(Theme.line, lineWidth: 10)
                    Circle()
                        .trim(from: 0, to: min(1, Double(state.todayMinutes) / Double(max(1, state.settings.dailyGoalMinutes))))
                        .stroke(LinearGradient(colors: [Palette.amberGlow, Palette.amber], startPoint: .top, endPoint: .bottom),
                                style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 0) {
                        Text(formatMinutes(state.todayMinutes)).font(.display(18, weight: .heavy)).foregroundStyle(Theme.ink)
                        Text("today").font(.caption2).foregroundStyle(Theme.inkSoft)
                    }
                }
                .frame(width: 86, height: 86)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Focused \(state.todayMinutes) of \(state.settings.dailyGoalMinutes) minutes today")

                VStack(alignment: .leading, spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Level \(state.level)").font(.label).foregroundStyle(Theme.ink)
                            Spacer()
                            Text("\(Leveling.xpRequired(forLevel: state.level + 1) - state.xp) Glow to go")
                                .font(.caption).foregroundStyle(Theme.inkSoft)
                        }
                        GlowBar(value: state.levelProgress)
                    }
                    if let next = state.nextRenewalMinutes {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Next restoration").font(.label).foregroundStyle(Theme.ink)
                                Spacer()
                                Text("\(formatMinutes(next - state.totalMinutes)) of focus")
                                    .font(.caption).foregroundStyle(Theme.inkSoft)
                            }
                            GlowBar(value: renewalProgress(next), tint: Theme.moss, height: 8)
                        }
                    }
                }
            }
        }
    }

    private func renewalProgress(_ next: Int) -> Double {
        let milestones = store.content.renewalMilestones
        let prev = milestones.last { $0 <= state.totalMinutes } ?? 0
        return Double(state.totalMinutes - prev) / Double(max(1, next - prev))
    }

    private var questsPreview: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Today's quests").font(.display(17)).foregroundStyle(Theme.ink)
                    Spacer()
                    Button("See all") { store.selectedTab = .journey }
                        .font(.label)
                }
                ForEach(state.quests(.daily)) { q in
                    HStack(spacing: 10) {
                        Image(systemName: q.claimed ? "checkmark.seal.fill" : (q.isComplete ? "gift.fill" : "circle.dotted"))
                            .foregroundStyle(q.isComplete ? Palette.amber : Theme.inkSoft)
                            .frame(width: 22)
                        Text(q.template.title).font(.subheadline).foregroundStyle(Theme.ink)
                            .strikethrough(q.claimed, color: Theme.inkSoft)
                        Spacer()
                        Text("\(min(q.progress, q.template.target))/\(q.template.target)")
                            .font(.caption.monospacedDigit()).foregroundStyle(Theme.inkSoft)
                    }
                }
            }
        }
    }

    private var startBar: some View {
        let s = state.settings
        return VStack(spacing: 6) {
            Button {
                Haptics.tap(.medium)
                store.route = .focusSetup
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "flame.fill")
                    Text("Begin focusing")
                }
            }
            .buttonStyle(GlowButtonStyle())
            Text(s.defaultMode == .countdown ? "\(s.defaultMinutes) min · \(s.defaultCategory.title)" : "Stopwatch · \(s.defaultCategory.title)")
                .font(.caption2Rounded)
                .foregroundStyle(Theme.inkSoft)
        }
        .padding(.horizontal, Theme.gutter)
        .padding(.top, 10)
        .padding(.bottom, 6)
        .background(Theme.background.opacity(0.92).ignoresSafeArea(edges: .bottom))
    }

    // MARK: Behavior

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<22: return "Good evening"
        default: return "A quiet night"
        }
    }

    private func pokeEmber() {
        Haptics.tap(.light)
        store.sound.play(.tap)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
            mood = .happy
            speech = EmberChatter.line(for: state)
        }
        Task {
            try? await Task.sleep(for: .seconds(3.2))
            withAnimation(.easeOut(duration: 0.4)) {
                mood = .idle
                speech = nil
            }
        }
    }
}
