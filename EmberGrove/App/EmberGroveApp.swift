import SwiftUI

@MainActor
@main
struct EmberGroveApp: App {
    @State private var store = GameStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(\.emberReduceMotion, store.settings.reduceMotion)
                .preferredColorScheme(colorScheme)
                .tint(Palette.amber)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { store.sceneBecameActive() }
        }
    }

    private var colorScheme: ColorScheme? {
        switch store.settings.appearance {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

enum AppTab: Hashable {
    case home, world, ember, journey, stats
}

@MainActor
struct RootView: View {
    @Environment(GameStore.self) private var store

    var body: some View {
        @Bindable var store = store
        TabView(selection: $store.selectedTab) {
            HomeView()
                .tabItem { Label("Hearth", systemImage: "flame.fill") }
                .tag(AppTab.home)
            WorldView()
                .tabItem { Label("Grove", systemImage: "tree.fill") }
                .tag(AppTab.world)
                .badge(store.state.pendingChoices > 0 && !store.state.canChoosePath ? store.state.pendingChoices : 0)
            CharacterView()
                .tabItem { Label(store.state.emberName, systemImage: "sparkles") }
                .tag(AppTab.ember)
                .badge(store.state.canChoosePath ? Text("!") : nil)
            JourneyView()
                .tabItem { Label("Journey", systemImage: "book.closed.fill") }
                .tag(AppTab.journey)
                .badge(store.state.claimableQuests)
            StatsView()
                .tabItem { Label("Stats", systemImage: "chart.bar.fill") }
                .tag(AppTab.stats)
        }
        .overlay(alignment: .top) { MilestoneBanner() }
        .fullScreenCover(isPresented: sessionPresented) {
            SessionFlowView()
                .environment(store)
                .environment(\.emberReduceMotion, store.settings.reduceMotion)
        }
        .background {
            // Separate host views keep each presentation independent.
            Color.clear.fullScreenCover(isPresented: onboardingPresented) {
                OnboardingView()
                    .environment(store)
                    .environment(\.emberReduceMotion, store.settings.reduceMotion)
            }
        }
        .sheet(item: $store.route) { route in
            Group {
                switch route {
                case .restore: RestoreSheet()
                case .choosePath: PathChoiceSheet()
                case .focusSetup: FocusSetupSheet()
                }
            }
            .environment(store)
            .environment(\.emberReduceMotion, store.settings.reduceMotion)
        }
    }

    /// The focus screen and the reward sequence share one cover, so finishing flows straight into rewards.
    private var sessionPresented: Binding<Bool> {
        Binding(get: { store.activeSession != nil || store.pendingReward != nil }, set: { _ in })
    }

    private var onboardingPresented: Binding<Bool> {
        Binding(get: { !store.settings.hasOnboarded }, set: { _ in })
    }
}

@MainActor
struct SessionFlowView: View {
    @Environment(GameStore.self) private var store

    var body: some View {
        ZStack {
            if let reward = store.pendingReward {
                RewardView(summary: reward)
                    .transition(.opacity.combined(with: .scale(scale: 1.04)))
            } else {
                FocusView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.6), value: store.pendingReward?.id)
    }
}

/// Celebrates milestones that happen outside the reward sequence (restorations, path choice, quests).
@MainActor
struct MilestoneBanner: View {
    @Environment(GameStore.self) private var store

    var body: some View {
        if let changes = store.banner, let line = describe(changes) {
            HStack(spacing: 12) {
                Image(systemName: line.symbol)
                    .font(.title3)
                    .foregroundStyle(Palette.amber)
                VStack(alignment: .leading, spacing: 2) {
                    Text(line.title).font(.label).foregroundStyle(Theme.ink)
                    Text(line.subtitle).font(.caption).foregroundStyle(Theme.inkSoft)
                }
                Spacer(minLength: 0)
            }
            .padding(14)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .padding(.horizontal, 16)
            .padding(.top, 6)
            .transition(.move(edge: .top).combined(with: .opacity))
            .onTapGesture { store.banner = nil }
            .task(id: line.title) {
                try? await Task.sleep(for: .seconds(4))
                withAnimation { store.banner = nil }
            }
            .accessibilityElement(children: .combine)
        }
    }

    private func describe(_ c: MilestoneChanges) -> (symbol: String, title: String, subtitle: String)? {
        let content = store.content
        if let id = c.chapters.first, let ch = content.chapter(id) {
            return ("book.fill", "New chapter: \(ch.title)", "Read it in Journey → Story")
        }
        if let id = c.companionsArrived.first, let comp = content.companion(id) {
            return ("pawprint.fill", "\(comp.name) arrived", comp.blurb)
        }
        if let id = c.areas.first, let area = content.area(id) {
            return ("map.fill", "\(area.name) is open", area.blurb)
        }
        if let id = c.achievements.first, let a = content.achievement(id) {
            return (a.symbol, "Achievement: \(a.title)", a.blurb)
        }
        return nil
    }
}
