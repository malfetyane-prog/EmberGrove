import SwiftUI

@MainActor
struct CharacterView: View {
    @Environment(GameStore.self) private var store
    @State private var mood: EmberMood = .idle
    @State private var slot: CosmeticSlot = .head
    @State private var renaming = false
    @State private var newName = ""
    @State private var pendingPurchase: Cosmetic?

    private var state: GameState { store.state }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    portrait
                    if state.canChoosePath {
                        Button { store.route = .choosePath } label: {
                            Label("\(state.emberName) is ready to evolve", systemImage: "sparkles")
                        }
                        .buttonStyle(GlowButtonStyle())
                    }
                    evolutionCard
                    abilitiesCard
                    wardrobeCard
                    memoriesCard
                }
                .padding(.horizontal, Theme.gutter)
                .padding(.bottom, 30)
            }
            .screenBackground()
            .navigationTitle(state.emberName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { SeedBadge(amount: state.seeds) }
            }
            .alert("Rename your companion", isPresented: $renaming) {
                TextField("Name", text: $newName)
                Button("Save") { store.rename(newName) }
                Button("Cancel", role: .cancel) {}
            }
            .confirmationDialog(purchaseTitle, isPresented: Binding(get: { pendingPurchase != nil }, set: { if !$0 { pendingPurchase = nil } }),
                                titleVisibility: .visible) {
                if let c = pendingPurchase, case .seeds(let cost) = c.unlock {
                    Button("Buy for \(cost) Seeds") {
                        if store.buy(c) { store.equip(c, slot: c.slot) }
                    }
                    .disabled(state.seeds < cost)
                }
                Button("Not now", role: .cancel) {}
            } message: {
                Text(pendingPurchase?.blurb ?? "")
            }
        }
    }

    private var purchaseTitle: String { pendingPurchase.map { "Get the \($0.name)?" } ?? "" }

    // MARK: Portrait

    private var portrait: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [FlameTint.named(state.flameTint).glow.opacity(0.55), .clear],
                                         center: .center, startRadius: 10, endRadius: 150))
                    .frame(width: 300, height: 300)
                EmberView(appearance: state.appearance, mood: mood)
                    .frame(width: 220, height: 220)
                    .onTapGesture { poke() }
                    .accessibilityAddTraits(.isButton)
                    .accessibilityHint("Tap to play")
            }
            .frame(height: 250)
            HStack(spacing: 8) {
                Text(state.emberName).font(.display(30, weight: .heavy)).foregroundStyle(Theme.ink)
                Button {
                    newName = state.emberName
                    renaming = true
                } label: { Image(systemName: "pencil.circle.fill").font(.title2).foregroundStyle(Theme.inkSoft) }
                .accessibilityLabel("Rename")
            }
            Text(state.path.map { "\(state.stage.name) · Path of \($0.title)" } ?? state.stage.name)
                .font(.label).foregroundStyle(Theme.inkSoft)
            Text(state.stage.blurb)
                .font(.subheadline).foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center).padding(.horizontal)
            VStack(spacing: 4) {
                GlowBar(value: state.levelProgress)
                HStack {
                    Text("Level \(state.level)").font(.label)
                    Spacer()
                    Text("\(state.xp) Glow").font(.caption.monospacedDigit())
                }
                .foregroundStyle(Theme.inkSoft)
            }
            .padding(.top, 8)
        }
    }

    private func poke() {
        let moods: [EmberMood] = [.happy, .celebrating, .curious]
        withAnimation { mood = moods.randomElement() ?? .happy }
        Haptics.tap(.light)
        store.sound.play(.tap)
        Task {
            try? await Task.sleep(for: .seconds(2.2))
            withAnimation { mood = .idle }
        }
    }

    // MARK: Evolution

    private var evolutionCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                SectionTitle(title: "Evolution", subtitle: state.path == nil ? "At level 8, choose one of three paths." : nil)
                ScrollView(.horizontal) {
                    HStack(alignment: .top, spacing: 14) {
                        ForEach(0..<5, id: \.self) { index in
                            stageCell(index)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .scrollIndicators(.hidden)
            }
        }
    }

    private func stageCell(_ index: Int) -> some View {
        let reached = state.stageIndex >= index
        let stage = store.content.stage(index: index, path: state.path ?? .hearth)
        let known = index < 2 || state.path != nil
        var look = state.appearance
        look.stage = index
        look.path = index >= 2 ? (state.path ?? .hearth) : nil
        return VStack(spacing: 6) {
            ZStack {
                Circle().fill(reached ? Palette.amberGlow.opacity(0.35) : Theme.line.opacity(0.4))
                EmberView(appearance: look, mood: .idle, animated: false)
                    .padding(6)
                    .brightness(reached ? 0 : -1)
                    .opacity(reached ? 1 : 0.25)
                if !known {
                    Text("?").font(.display(28, weight: .heavy)).foregroundStyle(Theme.inkSoft)
                }
            }
            .frame(width: 78, height: 78)
            Text(known ? stage.name : "???").font(.caption.weight(.bold)).foregroundStyle(Theme.ink)
            Text("Lv \(stage.minLevel)").font(.caption2).foregroundStyle(Theme.inkSoft)
        }
        .frame(width: 84)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(known ? stage.name : "Unknown form"), level \(stage.minLevel), \(reached ? "reached" : "not yet reached")")
    }

    // MARK: Abilities

    private var abilitiesCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                SectionTitle(title: "Abilities")
                let all = store.content.abilities.filter { $0.path == nil || $0.path == state.path }
                ForEach(all) { a in
                    let unlocked = state.unlockedAbilities.contains(a)
                    HStack(spacing: 12) {
                        Image(systemName: unlocked ? "flame.fill" : "lock.fill")
                            .foregroundStyle(unlocked ? Palette.amber : Theme.inkSoft)
                            .frame(width: 30, height: 30)
                            .background(Circle().fill(unlocked ? Palette.amberGlow.opacity(0.3) : Theme.line.opacity(0.4)))
                        VStack(alignment: .leading, spacing: 1) {
                            Text(a.name).font(.label).foregroundStyle(Theme.ink)
                            Text(unlocked ? a.blurb : "Unlocks as a \(store.content.stage(index: a.stage, path: a.path ?? state.path).name)")
                                .font(.caption).foregroundStyle(Theme.inkSoft)
                        }
                    }
                    .opacity(unlocked ? 1 : 0.7)
                }
            }
        }
    }

    // MARK: Wardrobe

    private var wardrobeCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                SectionTitle(title: "Wardrobe")
                Picker("Slot", selection: $slot) {
                    ForEach(CosmeticSlot.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 12)], spacing: 12) {
                    if slot != .flame { wardrobeItem(nil) }
                    ForEach(store.content.cosmetics.filter { $0.slot == slot }) { wardrobeItem($0) }
                }
            }
        }
    }

    private func wardrobeItem(_ cosmetic: Cosmetic?) -> some View {
        let unlocked = cosmetic.map { state.isCosmeticUnlocked($0) } ?? true
        let equipped = state.equipped(slot) == cosmetic?.id
        var look = state.appearance
        switch slot {
        case .head: look.head = cosmetic?.id
        case .neck: look.neck = cosmetic?.id
        case .face: look.face = cosmetic?.id
        case .flame: look.flameTint = cosmetic?.id ?? "amber"
        }
        return Button {
            guard let cosmetic else { store.equip(nil, slot: slot); return }
            if unlocked { store.equip(cosmetic, slot: slot) }
            else if case .seeds = cosmetic.unlock { pendingPurchase = cosmetic }
        } label: {
            VStack(spacing: 4) {
                EmberView(appearance: look, mood: .idle, animated: false)
                    .frame(width: 70, height: 70)
                    .opacity(unlocked ? 1 : 0.35)
                    .overlay(alignment: .topTrailing) {
                        if !unlocked { Image(systemName: "lock.fill").font(.caption).foregroundStyle(Theme.inkSoft) }
                    }
                Text(cosmetic?.name ?? "None").font(.caption.weight(.semibold)).foregroundStyle(Theme.ink).lineLimit(1)
                Text(unlocked ? (equipped ? "Wearing" : " ") : unlockHint(cosmetic))
                    .font(.caption2).foregroundStyle(equipped ? Palette.amber : Theme.inkSoft).lineLimit(1)
            }
            .padding(8)
            .frame(maxWidth: .infinity)
            .background(Theme.cardRaised, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(equipped ? Palette.amber : Theme.line, lineWidth: equipped ? 2 : 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(cosmetic?.name ?? "None"), \(unlocked ? (equipped ? "wearing" : "available") : unlockHint(cosmetic))")
    }

    private func unlockHint(_ c: Cosmetic?) -> String {
        guard let c else { return "" }
        switch c.unlock {
        case .starter: return ""
        case .level(let n): return "Level \(n)"
        case .seeds(let n): return "\(n) Seeds"
        case .gift(let companion): return "Gift from \(store.content.companion(companion)?.name ?? "a friend")"
        case .path(let p): return "\(p.title) path"
        case .curios(let n): return "\(n) curios"
        }
    }

    // MARK: Memories

    private var memoriesCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                SectionTitle(title: "Memories", subtitle: "\(state.emberName)'s story so far")
                if state.journal.isEmpty {
                    Text("Nothing yet. The first memory begins with your first focus session.")
                        .font(.subheadline).foregroundStyle(Theme.inkSoft)
                }
                ForEach(Array(state.journal.suffix(25).reversed())) { entry in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: entry.symbol)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Palette.amber)
                            .frame(width: 26, height: 26)
                            .background(Circle().fill(Palette.amberGlow.opacity(0.25)))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.text).font(.subheadline).foregroundStyle(Theme.ink)
                            Text(entry.date, format: .dateTime.month().day().hour().minute())
                                .font(.caption2).foregroundStyle(Theme.inkSoft)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Path choice

@MainActor
struct PathChoiceSheet: View {
    @Environment(GameStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var choice: EmberPath = .hearth

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    VStack(spacing: 6) {
                        Text("Who will \(store.state.emberName) become?")
                            .font(.display(26, weight: .heavy)).foregroundStyle(Theme.ink).multilineTextAlignment(.center)
                        Text("This choice shapes \(store.state.emberName)'s look, abilities and future forms. It's permanent, so pick the one that feels like you.")
                            .font(.subheadline).foregroundStyle(Theme.inkSoft).multilineTextAlignment(.center)
                    }
                    ForEach(EmberPath.allCases) { path in option(path) }
                }
                .padding(Theme.gutter)
            }
            .screenBackground()
            .safeAreaInset(edge: .bottom) {
                Button {
                    store.choosePath(choice)
                    dismiss()
                } label: {
                    Text("Become a \(store.content.stage(index: 2, path: choice).name)")
                }
                .buttonStyle(GlowButtonStyle())
                .padding(.horizontal, Theme.gutter)
                .padding(.vertical, 10)
            }
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Later") { dismiss() } } }
        }
    }

    private func option(_ path: EmberPath) -> some View {
        let selected = choice == path
        var look = store.state.appearance
        look.stage = 2
        look.path = path
        look.flameTint = store.content.cosmetics.first { $0.unlock == .path(path) }?.id ?? look.flameTint
        var elder = look
        elder.stage = 4
        let abilities = store.content.abilities.filter { $0.path == path }
        return Button {
            withAnimation(.spring(response: 0.35)) { choice = path }
            Haptics.selection()
        } label: {
            HStack(alignment: .top, spacing: 14) {
                VStack(spacing: 2) {
                    EmberView(appearance: look, mood: selected ? .happy : .idle, animated: selected)
                        .frame(width: 110, height: 110)
                    HStack(spacing: 4) {
                        Text("Later:").font(.caption2).foregroundStyle(Theme.inkSoft)
                        EmberView(appearance: elder, mood: .idle, animated: false).frame(width: 36, height: 36)
                    }
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text(path.title).font(.display(22, weight: .heavy)).foregroundStyle(Theme.ink)
                    Text(path.tagline).font(.subheadline).foregroundStyle(Theme.inkSoft).fixedSize(horizontal: false, vertical: true)
                    ForEach(abilities) { a in
                        Text("• \(a.name): \(a.blurb)").font(.caption).foregroundStyle(Theme.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(14)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous)
                .strokeBorder(selected ? Palette.amber : Theme.line, lineWidth: selected ? 2.5 : 1))
            .scaleEffect(selected ? 1 : 0.98)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
