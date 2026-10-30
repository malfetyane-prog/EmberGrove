import SwiftUI

@MainActor
struct WorldView: View {
    @Environment(GameStore.self) private var store
    @State private var emberX: Double = 322
    @State private var emberMood: EmberMood = .idle
    @State private var selected: Landmark?
    @State private var showDecor = false

    private var state: GameState { store.state }
    private let sceneHeight: CGFloat = 420

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    map
                    if state.renewalsAvailable > 0 && !state.availableLandmarks.isEmpty {
                        Button { store.route = .restore } label: {
                            Label("Restore something (\(state.renewalsAvailable) available)", systemImage: "leaf.fill")
                        }
                        .buttonStyle(GlowButtonStyle())
                        .padding(.horizontal, Theme.gutter)
                    }
                    areasCard.padding(.horizontal, Theme.gutter)
                    Button { showDecor = true } label: {
                        Label("Decorate the clearing", systemImage: "paintpalette.fill")
                    }
                    .buttonStyle(GlowButtonStyle(prominent: false))
                    .padding(.horizontal, Theme.gutter)
                }
                .padding(.bottom, 30)
            }
            .screenBackground()
            .navigationTitle("The Grove")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { SeedBadge(amount: state.seeds) }
            }
            .sheet(item: $selected) { l in
                LandmarkSheet(landmark: l).environment(store).presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showDecor) {
                DecorSheet().environment(store).presentationDetents([.medium, .large])
            }
        }
    }

    // MARK: Map

    private var map: some View {
        let s = Double(sceneHeight) / GroveRenderer.height
        return ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                ZStack(alignment: .topLeading) {
                    GroveStage(snapshot: GroveSnapshot(state), appearance: state.appearance, mood: emberMood,
                               viewport: 0...GroveRenderer.width, emberX: emberX, emberSize: 88) {
                        emberMood = .happy
                        Haptics.tap(.light)
                        store.sound.play(.tap)
                    }
                    .frame(width: sceneHeight * GroveRenderer.width / GroveRenderer.height, height: sceneHeight)

                    ForEach(store.content.landmarks.filter { state.isLandmarkVisible($0) }) { l in
                        Button { visit(l) } label: {
                            Color.clear.contentShape(Rectangle())
                        }
                        .frame(width: hotspotWidth(l) * s, height: hotspotHeight(l) * s)
                        .position(x: l.x * s, y: (l.y - hotspotHeight(l) / 2 + 10) * s)
                        .accessibilityLabel(Text(l.name))
                        .accessibilityHint(Text(state.restored[l.id] == nil ? "Not yet restored" : "Restored"))
                    }

                    ForEach(store.content.areas.filter { !state.isAreaUnlocked($0.id) }) { area in
                        VStack(spacing: 6) {
                            Image(systemName: "lock.fill").font(.title3)
                            Text(area.name).font(.label)
                            Text("Opens at \(formatMinutes(area.unlockMinutes)) of focus")
                                .font(.caption).foregroundStyle(Theme.inkSoft)
                        }
                        .foregroundStyle(Theme.ink)
                        .padding(12)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                        .position(x: (area.xStart + area.xEnd) / 2 * s, y: Double(sceneHeight) * 0.42)
                    }

                    ForEach([0.0, 520, 900, 1250], id: \.self) { x in
                        Color.clear.frame(width: 1, height: 1).position(x: x * s, y: 0).id(x)
                    }
                }
                .frame(width: sceneHeight * GroveRenderer.width / GroveRenderer.height, height: sceneHeight)
            }
            .scrollIndicators(.hidden)
            .frame(height: sceneHeight)
            .onAppear { proxy.scrollTo(0.0, anchor: .leading) }
        }
    }

    private func hotspotWidth(_ l: Landmark) -> Double {
        switch l.id {
        case "oldOak": 260
        case "meadow", "lilyPond", "mushroomRing", "fireflyHollow", "moonflowers", "willowBridge": 150
        default: 100
        }
    }

    private func hotspotHeight(_ l: Landmark) -> Double {
        switch l.id {
        case "oldOak": 300
        case "treehouse": 90
        default: 100
        }
    }

    private func visit(_ l: Landmark) {
        Haptics.selection()
        let target = l.x + (l.x < 200 ? 70 : -60)
        let distance = abs(target - emberX)
        emberMood = .curious
        withAnimation(.easeInOut(duration: min(1.6, 0.4 + distance / 600))) { emberX = target }
        after(min(1.6, 0.4 + distance / 600)) {
            emberMood = state.restored[l.id] == nil ? .curious : .happy
            selected = l
        }
    }

    // MARK: Areas

    private var areasCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                Text("Regions").font(.display(18)).foregroundStyle(Theme.ink)
                ForEach(store.content.areas) { area in
                    let landmarks = store.content.landmarks.filter { $0.area == area.id }
                    let restored = landmarks.filter { state.restored[$0.id] != nil }.count
                    let unlocked = state.isAreaUnlocked(area.id)
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Image(systemName: unlocked ? "mappin.circle.fill" : "lock.circle.fill")
                                .foregroundStyle(unlocked ? Theme.moss : Theme.inkSoft)
                            Text(area.name).font(.label).foregroundStyle(Theme.ink)
                            Spacer()
                            Text(unlocked ? "\(restored)/\(landmarks.count)" : formatMinutes(max(0, area.unlockMinutes - state.totalMinutes)) + " to go")
                                .font(.caption.monospacedDigit()).foregroundStyle(Theme.inkSoft)
                        }
                        GlowBar(value: unlocked ? Double(restored) / Double(landmarks.count)
                                                : Double(state.totalMinutes) / Double(max(1, area.unlockMinutes)),
                                tint: unlocked ? Theme.moss : Theme.inkSoft.opacity(0.6), height: 7)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }
}

// MARK: - Landmark detail

@MainActor
struct LandmarkSheet: View {
    let landmark: Landmark
    @Environment(GameStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let state = store.state
        let variantId = state.restored[landmark.id]
        let variant = landmark.variants.first { $0.id == variantId }
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(store.content.area(landmark.area)?.name.uppercased() ?? "")
                        .font(.caption.weight(.bold)).tracking(1.2).foregroundStyle(Theme.inkSoft)
                    Text(landmark.name).font(.display(28, weight: .heavy)).foregroundStyle(Theme.ink)
                    if let variant {
                        HStack {
                            Circle().fill(Color(hex: variant.hex)).frame(width: 14, height: 14)
                            Text(variant.name).font(.label)
                        }
                        Text(landmark.restoredText).font(.storySerif).foregroundStyle(Theme.ink)
                    } else {
                        Text(landmark.blurb).font(.storySerif).foregroundStyle(Theme.ink)
                        if state.availableLandmarks.contains(landmark) {
                            Text(state.renewalsAvailable > 0 ? "You can restore this now." :
                                    "Keep focusing to earn your next restoration.")
                                .font(.subheadline).foregroundStyle(Theme.inkSoft)
                            if state.renewalsAvailable > 0 {
                                Button {
                                    dismiss()
                                    after(0.5) { store.route = .restore }
                                } label: { Label("Restore", systemImage: "leaf.fill") }
                                .buttonStyle(GlowButtonStyle())
                            }
                        } else if let req = landmark.requiresLandmark, let r = store.content.landmark(req) {
                            Text("Restore \(r.name) first.").font(.subheadline).foregroundStyle(Theme.inkSoft)
                        }
                    }
                    if let cid = landmark.companion, let c = store.content.companion(cid) {
                        Card {
                            HStack(spacing: 12) {
                                CompanionPortrait(id: c.id).frame(width: 56, height: 56)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(variant == nil ? "Someone might live here…" : c.name).font(.label).foregroundStyle(Theme.ink)
                                    if variant != nil {
                                        Text(c.species).font(.caption).foregroundStyle(Theme.inkSoft)
                                        HeartsRow(hearts: state.hearts(c.id), size: 10)
                                    }
                                }
                                .opacity(variant == nil ? 0.6 : 1)
                            }
                        }
                        .saturation(variant == nil ? 0 : 1)
                    }
                }
                .padding(Theme.gutter)
            }
            .screenBackground()
        }
    }
}

// MARK: - Restoration choice

@MainActor
struct RestoreSheet: View {
    @Environment(GameStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var picked: Landmark?
    @State private var variant: LandmarkVariant?

    var body: some View {
        let state = store.state
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("What should come back to life?").font(.display(24, weight: .heavy)).foregroundStyle(Theme.ink)
                        Text("\(state.renewalsAvailable) restoration\(state.renewalsAvailable == 1 ? "" : "s") available. Each place brings new life to the grove, and some bring new friends.")
                            .font(.subheadline).foregroundStyle(Theme.inkSoft)
                    }
                    ForEach(store.content.areas.filter { state.isAreaUnlocked($0.id) }) { area in
                        let options = state.availableLandmarks.filter { $0.area == area.id }
                        if !options.isEmpty {
                            Text(area.name.uppercased()).font(.caption.weight(.bold)).tracking(1.2).foregroundStyle(Theme.inkSoft)
                            ForEach(options) { l in landmarkOption(l) }
                        }
                    }
                }
                .padding(Theme.gutter)
            }
            .screenBackground()
            .safeAreaInset(edge: .bottom) {
                if let picked, let variant {
                    Button {
                        store.restore(picked, variant: variant)
                        dismiss()
                    } label: {
                        Label("Restore \(picked.name)", systemImage: "leaf.fill")
                    }
                    .buttonStyle(GlowButtonStyle())
                    .padding(.horizontal, Theme.gutter)
                    .padding(.vertical, 10)
                }
            }
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Later") { dismiss() } } }
        }
    }

    private func landmarkOption(_ l: Landmark) -> some View {
        let isPicked = picked?.id == l.id
        return VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.spring(response: 0.35)) {
                    picked = l
                    variant = l.variants.first
                }
                Haptics.selection()
            } label: {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(l.name).font(.display(18)).foregroundStyle(Theme.ink)
                        Text(l.blurb).font(.subheadline).foregroundStyle(Theme.inkSoft)
                        if let cid = l.companion, store.content.companion(cid) != nil {
                            Label("Someone may move in", systemImage: "pawprint.fill")
                                .font(.caption.weight(.semibold)).foregroundStyle(Palette.coral)
                        }
                    }
                    Spacer()
                    Image(systemName: isPicked ? "checkmark.circle.fill" : "circle")
                        .font(.title2).foregroundStyle(isPicked ? Palette.amber : Theme.line)
                }
            }
            .buttonStyle(.plain)

            if isPicked {
                HStack(spacing: 10) {
                    ForEach(l.variants) { v in
                        Button {
                            variant = v
                            Haptics.selection()
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                RoundedRectangle(cornerRadius: 10).fill(Color(hex: v.hex)).frame(height: 34)
                                Text(v.name).font(.label).foregroundStyle(Theme.ink)
                                Text(v.blurb).font(.caption).foregroundStyle(Theme.inkSoft).fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Theme.cardRaised, in: RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(variant == v ? Palette.amber : Theme.line, lineWidth: variant == v ? 2 : 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(16)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous).strokeBorder(isPicked ? Palette.amber.opacity(0.7) : Theme.line, lineWidth: isPicked ? 1.5 : 1))
    }
}

// MARK: - Decorations

@MainActor
struct DecorSheet: View {
    @Environment(GameStore.self) private var store
    @State private var notEnough: Decoration?

    var body: some View {
        let state = store.state
        NavigationStack {
            List {
                Section {
                    ForEach(store.content.decorations) { d in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(d.name).font(.label)
                                Text(d.blurb).font(.caption).foregroundStyle(Theme.inkSoft)
                            }
                            Spacer()
                            if state.ownedDecorations.contains(d.id) {
                                Toggle("Show", isOn: Binding(get: { !state.hiddenDecorations.contains(d.id) },
                                                             set: { _ in store.toggleDecoration(d.id) }))
                                    .labelsHidden()
                            } else {
                                Button {
                                    if !store.buy(d) { notEnough = d }
                                } label: {
                                    HStack(spacing: 4) {
                                        SeedIcon().frame(width: 10, height: 12)
                                        Text("\(d.cost)").monospacedDigit()
                                    }
                                }
                                .buttonStyle(.bordered)
                                .tint(state.seeds >= d.cost ? Palette.amber : .gray)
                            }
                        }
                        .listRowBackground(Theme.card)
                    }
                } footer: {
                    Text("Decorations appear around the hearth. Earn Seeds by focusing and finishing quests.")
                }
            }
            .scrollContentBackground(.hidden)
            .screenBackground()
            .navigationTitle("Decorate")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { SeedBadge(amount: state.seeds) } }
            .alert("Not enough Seeds yet", isPresented: Binding(get: { notEnough != nil }, set: { if !$0 { notEnough = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("A few more focus sessions will get you there.")
            }
        }
    }
}
