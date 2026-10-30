import SwiftUI

/// A short, satisfying reveal after each session: Glow, level-ups, evolution, a visiting friend,
/// discoveries and world changes appear one beat at a time. Tap to speed it up.
@MainActor
struct RewardView: View {
    let summary: RewardSummary
    @Environment(GameStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var revealed = 0
    @State private var glowCounter = 0
    @State private var barValue = 0.0
    @State private var flash = false

    private enum Beat: Hashable {
        case glow, level, evolution, seeds, companion, discovery, renewal
        case area(String), chapter(String), achievement(String), cosmetic(String), quests
    }

    private var beats: [Beat] {
        var b: [Beat] = [.glow]
        if summary.levelAfter > summary.levelBefore { b.append(.level) }
        if summary.evolved { b.append(.evolution) }
        b.append(.seeds)
        if summary.companionVisit != nil { b.append(.companion) }
        if summary.discovery != nil { b.append(.discovery) }
        if summary.renewalsEarned > 0 { b.append(.renewal) }
        b += summary.milestones.areas.map { .area($0) }
        b += summary.milestones.chapters.map { .chapter($0) }
        b += summary.newCosmetics.map { .cosmetic($0) }
        b += summary.milestones.achievements.map { .achievement($0) }
        if summary.questsReady > 0 { b.append(.quests) }
        return b
    }

    private var done: Bool { revealed >= beats.count }
    private var showEvolved: Bool {
        guard summary.evolved, let idx = beats.firstIndex(of: .evolution) else { return false }
        return revealed > idx
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            LinearGradient(colors: [Palette.duskDeep, Palette.dusk, Color(hex: 0x5A3E6E)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 14) {
                        hero
                        ForEach(Array(beats.prefix(revealed).enumerated()), id: \.offset) { index, beat in
                            card(for: beat)
                                .id(index)
                                .transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity), removal: .opacity))
                        }
                        Color.clear.frame(height: 150).id("end")
                    }
                    .padding(.horizontal, Theme.gutter)
                    .padding(.top, 20)
                }
                .scrollIndicators(.hidden)
                .onChange(of: revealed) { _, _ in
                    withAnimation(.easeOut(duration: 0.4)) { proxy.scrollTo("end", anchor: .bottom) }
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { revealNext() }

            footer
        }
        .preferredColorScheme(.dark)
        .overlay {
            Color.white.opacity(flash ? 0.85 : 0).ignoresSafeArea().allowsHitTesting(false)
        }
        .task { await runSequence() }
    }

    // MARK: Hero

    private var hero: some View {
        VStack(spacing: 8) {
            EmberView(appearance: showEvolved ? summary.appearanceAfter : summary.appearanceBefore,
                      mood: .celebrating)
                .frame(width: 170, height: 170)
                .id(showEvolved)
                .transition(.scale(scale: 0.6).combined(with: .opacity))
            Text("Session complete")
                .font(.display(30, weight: .heavy))
                .foregroundStyle(Palette.cream)
            Text("\(formatMinutes(summary.record.minutes)) of \(summary.record.category.title.lowercased())")
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(Palette.lavender)
        }
        .padding(.bottom, 6)
        .accessibilityElement(children: .combine)
    }

    // MARK: Cards

    @ViewBuilder
    private func card(for beat: Beat) -> some View {
        let content = store.content
        switch beat {
        case .glow:
            RewardCard(symbol: "flame.fill", tint: Palette.amber) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("+\(glowCounter) Glow").font(.display(24, weight: .heavy)).monospacedDigit()
                        Spacer()
                        LevelBadge(level: summary.levelAfter)
                    }
                    ForEach(summary.glowLines, id: \.self) { line in
                        HStack {
                            Text(line.label).font(.subheadline)
                            Spacer()
                            Text("+\(line.amount)").font(.subheadline.monospacedDigit())
                        }
                        .foregroundStyle(Palette.lavender)
                    }
                    GlowBar(value: barValue)
                }
            }
        case .level:
            RewardCard(symbol: "arrow.up.circle.fill", tint: Palette.amberGlow) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Level \(summary.levelAfter)!").font(.display(22, weight: .heavy))
                    Text("\(store.state.emberName) feels stronger and a little taller.").font(.subheadline).foregroundStyle(Palette.lavender)
                }
            }
        case .evolution:
            RewardCard(symbol: "sparkles", tint: Color(hex: 0xFFE07A)) {
                VStack(spacing: 10) {
                    HStack(spacing: 6) {
                        EmberView(appearance: summary.appearanceBefore, mood: .idle, animated: false)
                            .frame(width: 80, height: 80).opacity(0.6)
                        Image(systemName: "arrow.right").foregroundStyle(Palette.lavender)
                        EmberView(appearance: summary.appearanceAfter, mood: .happy)
                            .frame(width: 110, height: 110)
                    }
                    Text("\(store.state.emberName) evolved into a \(content.stage(index: summary.appearanceAfter.stage, path: summary.appearanceAfter.path).name)!")
                        .font(.display(20, weight: .heavy)).multilineTextAlignment(.center)
                    Text(content.stage(index: summary.appearanceAfter.stage, path: summary.appearanceAfter.path).blurb)
                        .font(.subheadline).foregroundStyle(Palette.lavender).multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
            }
        case .seeds:
            RewardCard(symbol: "leaf.fill", tint: Theme.moss) {
                HStack {
                    SeedIcon().frame(width: 18, height: 22)
                    Text("+\(summary.seeds) Seeds").font(.display(20, weight: .heavy))
                    Spacer()
                    Text("\(store.state.seeds) total").font(.subheadline).foregroundStyle(Palette.lavender)
                }
            }
        case .companion:
            if let visit = summary.companionVisit, let c = content.companion(visit.companion) {
                RewardCard(symbol: "heart.fill", tint: Palette.coral) {
                    HStack(alignment: .top, spacing: 12) {
                        CompanionPortrait(id: c.id).frame(width: 64, height: 64)
                            .background(Circle().fill(.white.opacity(0.08)))
                        VStack(alignment: .leading, spacing: 6) {
                            Text("\(c.name) kept you company").font(.display(18, weight: .bold))
                            HeartsRow(hearts: visit.heartsAfter, size: 11)
                            ForEach(visit.memories, id: \.self) { m in
                                Text(m).font(.system(.subheadline, design: .serif)).italic().foregroundStyle(Palette.cream)
                            }
                            ForEach(Array(visit.gifts.enumerated()), id: \.offset) { _, gift in
                                Text("Gift: \(describe(gift))").font(.label).foregroundStyle(Palette.amberGlow)
                            }
                        }
                    }
                }
            }
        case .discovery:
            if let id = summary.discovery, let curio = content.curio(id) {
                RewardCard(symbol: "magnifyingglass", tint: Color(hex: 0x7FC8FF)) {
                    HStack(spacing: 14) {
                        CurioBadge(curio: curio, found: true).frame(width: 56, height: 56)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Discovery!").font(.caption.weight(.bold)).foregroundStyle(Palette.amberGlow)
                            Text(curio.name).font(.display(18, weight: .bold))
                            Text(curio.blurb).font(.subheadline).foregroundStyle(Palette.lavender)
                        }
                    }
                }
            }
        case .renewal:
            RewardCard(symbol: "leaf.arrow.triangle.circlepath", tint: Theme.moss) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("The grove stirs").font(.display(20, weight: .heavy))
                    Text("You earned a restoration. Choose what comes back to life.").font(.subheadline).foregroundStyle(Palette.lavender)
                }
            }
        case .area(let id):
            if let area = content.area(id) {
                RewardCard(symbol: "map.fill", tint: Color(hex: 0xB79CFF)) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("New area: \(area.name)").font(.display(20, weight: .heavy))
                        Text(area.blurb).font(.subheadline).foregroundStyle(Palette.lavender)
                    }
                }
            }
        case .chapter(let id):
            if let ch = content.chapter(id) {
                RewardCard(symbol: "book.fill", tint: Palette.amberGlow) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Chapter \(ch.number): \(ch.title)").font(.display(18, weight: .heavy))
                        Text("A new page of the story is waiting in Journey.").font(.subheadline).foregroundStyle(Palette.lavender)
                    }
                }
            }
        case .cosmetic(let id):
            if let cos = content.cosmetic(id) {
                RewardCard(symbol: "tshirt.fill", tint: Palette.coral) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Unlocked: \(cos.name)").font(.display(18, weight: .bold))
                            Text(cos.blurb).font(.subheadline).foregroundStyle(Palette.lavender)
                        }
                        Spacer()
                        Button("Wear it") { wear(cos) }
                            .buttonStyle(.borderedProminent)
                            .tint(Palette.amber)
                            .foregroundStyle(Palette.ink)
                    }
                }
            }
        case .achievement(let id):
            if let a = content.achievement(id) {
                RewardCard(symbol: a.symbol, tint: Color(hex: 0xF2C14E)) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(a.title).font(.display(18, weight: .bold))
                        Text(a.blurb).font(.subheadline).foregroundStyle(Palette.lavender)
                    }
                }
            }
        case .quests:
            RewardCard(symbol: "gift.fill", tint: Palette.amber) {
                Text("\(summary.questsReady) quest reward\(summary.questsReady == 1 ? "" : "s") ready to claim")
                    .font(.display(17, weight: .bold))
            }
        }
    }

    private func describe(_ item: RewardItem) -> String {
        switch item {
        case .seeds(let n): "\(n) Seeds"
        case .cosmetic(let id): store.content.cosmetic(id)?.name ?? id
        case .decoration(let id): store.content.decoration(id)?.name ?? id
        }
    }

    private func wear(_ cosmetic: Cosmetic) {
        store.equip(cosmetic, slot: cosmetic.slot)
    }

    // MARK: Footer

    private var footer: some View {
        VStack(spacing: 10) {
            if done {
                if store.state.canChoosePath {
                    Button { close(then: .choosePath) } label: { Label("Choose \(store.state.emberName)'s path", systemImage: "sparkles") }
                        .buttonStyle(GlowButtonStyle())
                } else if store.state.renewalsAvailable > 0 && !store.state.availableLandmarks.isEmpty {
                    Button { close(then: .restore) } label: { Label("Restore the grove", systemImage: "leaf.fill") }
                        .buttonStyle(GlowButtonStyle())
                }
                Button { close(then: nil) } label: { Text("Back to the hearth") }
                    .buttonStyle(GlowButtonStyle(prominent: !(store.state.canChoosePath || (store.state.renewalsAvailable > 0 && !store.state.availableLandmarks.isEmpty))))
            } else {
                Text("Tap to continue").font(.caption2Rounded).foregroundStyle(Palette.lavender.opacity(0.8))
            }
        }
        .padding(.horizontal, Theme.gutter)
        .padding(.bottom, 12)
        .padding(.top, 20)
        .background(LinearGradient(colors: [.clear, Palette.duskDeep.opacity(0.95)], startPoint: .top, endPoint: .center).ignoresSafeArea())
        .animation(.easeInOut, value: done)
    }

    private func close(then route: GameStore.Route?) {
        if let route {
            store.selectedTab = route == .restore ? .world : .ember
        }
        store.pendingReward = nil
        if let route {
            after(0.8) { store.route = route }
        }
    }

    // MARK: Sequencing

    private func runSequence() async {
        try? await Task.sleep(for: .seconds(0.8))
        while !done {
            revealNext()
            try? await Task.sleep(for: .seconds(1.1))
        }
    }

    private func revealNext() {
        guard !done else { return }
        let beat = beats[revealed]
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { revealed += 1 }
        switch beat {
        case .glow: animateGlow()
        case .level:
            store.sound.play(.levelUp)
            Haptics.celebrate()
        case .evolution:
            store.sound.play(.levelUp)
            Haptics.celebrate()
            guard !reduceMotion else { return }
            withAnimation(.easeIn(duration: 0.15)) { flash = true }
            withAnimation(.easeOut(duration: 0.9).delay(0.2)) { flash = false }
        case .discovery, .cosmetic, .chapter, .area:
            store.sound.play(.discover)
            Haptics.tap(.rigid)
        case .achievement, .companion:
            Haptics.success()
        default:
            Haptics.tap()
        }
    }

    private func animateGlow() {
        let target = summary.glowTotal
        let finalProgress = Leveling.progress(forXP: store.state.xp)
        let leveled = summary.levelAfter > summary.levelBefore
        Task { @MainActor in
            let steps = 24
            for i in 1...steps {
                glowCounter = target * i / steps
                if i % 6 == 0 { Haptics.selection() }
                try? await Task.sleep(for: .milliseconds(28))
            }
        }
        if leveled {
            withAnimation(.easeIn(duration: 0.5)) { barValue = 1 }
            after(0.55) {
                barValue = 0
                withAnimation(.easeOut(duration: 0.6)) { barValue = finalProgress }
            }
        } else {
            withAnimation(.easeOut(duration: 0.9)) { barValue = finalProgress }
        }
    }
}

@MainActor
struct RewardCard<Content: View>: View {
    let symbol: String
    let tint: Color
    @ViewBuilder var content: Content

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.title3.weight(.bold))
                .foregroundStyle(Palette.ink)
                .frame(width: 42, height: 42)
                .background(Circle().fill(tint))
                .shadow(color: tint.opacity(0.6), radius: 10)
            content
                .foregroundStyle(Palette.cream)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous).strokeBorder(.white.opacity(0.1), lineWidth: 1))
        .accessibilityElement(children: .combine)
    }
}
