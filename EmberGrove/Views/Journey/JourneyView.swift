import SwiftUI

@MainActor
struct JourneyView: View {
    @Environment(GameStore.self) private var store
    @State private var section: JourneySection = .quests
    @State private var reading: Chapter?
    @State private var inspecting: Curio?

    enum JourneySection: String, CaseIterable, Identifiable {
        case quests = "Quests", story = "Story", friends = "Friends", curios = "Curios", feats = "Feats"
        var id: String { rawValue }
    }

    private var state: GameState { store.state }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Picker("Section", selection: $section) {
                        ForEach(JourneySection.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    switch section {
                    case .quests: quests
                    case .story: story
                    case .friends: friends
                    case .curios: curios
                    case .feats: feats
                    }
                }
                .padding(.horizontal, Theme.gutter)
                .padding(.bottom, 30)
            }
            .screenBackground()
            .navigationTitle("Journey")
            .sheet(item: $reading) { ch in
                ChapterReader(chapter: ch).environment(store)
            }
            .alert(inspecting?.name ?? "", isPresented: Binding(get: { inspecting != nil }, set: { if !$0 { inspecting = nil } })) {
                Button("Lovely", role: .cancel) {}
            } message: {
                Text(inspecting?.blurb ?? "")
            }
        }
    }

    // MARK: Quests

    private var quests: some View {
        VStack(spacing: 16) {
            questGroup(title: "Today", subtitle: "New quests every morning", statuses: state.quests(.daily))
            questGroup(title: "This week", subtitle: "Bigger goals, bigger rewards", statuses: state.quests(.weekly))
            Text("Quests are always optional. Nothing is lost if you skip a day: the grove just waits for you.")
                .font(.footnote).foregroundStyle(Theme.inkSoft).multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }

    private func questGroup(title: String, subtitle: String, statuses: [QuestStatus]) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                SectionTitle(title: title, subtitle: subtitle)
                ForEach(statuses) { q in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(q.template.title).font(.label).foregroundStyle(Theme.ink)
                                HStack(spacing: 8) {
                                    Label("\(q.template.seeds)", systemImage: "leaf.fill")
                                    Label("\(q.template.glow) Glow", systemImage: "flame.fill")
                                }
                                .font(.caption).foregroundStyle(Theme.inkSoft)
                            }
                            Spacer()
                            if q.claimed {
                                Label("Claimed", systemImage: "checkmark.seal.fill")
                                    .font(.caption.weight(.bold)).foregroundStyle(Theme.moss)
                            } else if q.isComplete {
                                Button("Claim") { store.claim(q) }
                                    .buttonStyle(.borderedProminent)
                                    .tint(Palette.amber)
                                    .foregroundStyle(Palette.ink)
                            } else {
                                Text("\(q.progress)/\(q.template.target)")
                                    .font(.caption.monospacedDigit()).foregroundStyle(Theme.inkSoft)
                            }
                        }
                        GlowBar(value: q.fraction, tint: q.isComplete ? Theme.moss : Palette.amber, height: 7)
                    }
                }
            }
        }
    }

    // MARK: Story

    private var story: some View {
        VStack(spacing: 12) {
            ForEach(store.content.chapters) { ch in
                let unlocked = state.chapters[ch.id] != nil
                Button { if unlocked { reading = ch; store.markRead(ch.id) } } label: {
                    HStack(spacing: 14) {
                        Text("\(ch.number)")
                            .font(.display(20, weight: .heavy))
                            .foregroundStyle(unlocked ? Palette.ink : Theme.inkSoft)
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(unlocked ? Palette.amberGlow : Theme.line.opacity(0.5)))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(unlocked ? ch.title : "A chapter yet to come").font(.label).foregroundStyle(Theme.ink)
                            Text(unlocked ? (state.chaptersRead.contains(ch.id) ? "Read" : "New") : hint(for: ch.trigger))
                                .font(.caption)
                                .foregroundStyle(unlocked && !state.chaptersRead.contains(ch.id) ? Palette.amber : Theme.inkSoft)
                        }
                        Spacer()
                        if unlocked { Image(systemName: "chevron.right").foregroundStyle(Theme.inkSoft) }
                    }
                    .padding(14)
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous).strokeBorder(Theme.line, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .disabled(!unlocked)
            }
        }
    }

    private func hint(for trigger: ChapterTrigger) -> String {
        switch trigger {
        case .start: return ""
        case .firstSession: return "Complete your first session"
        case .firstRestoration: return "Restore your first place"
        case .areaUnlocked(let id): return "Reach \(store.content.area(id)?.name ?? "a new area")"
        case .pathChosen: return "Choose \(state.emberName)'s path"
        case .landmark(let id): return "Restore \(store.content.landmark(id)?.name ?? "something special")"
        case .curio: return "Find something hidden on the ridge"
        case .allRestored: return "Restore the whole grove"
        }
    }

    // MARK: Friends

    private var friends: some View {
        VStack(spacing: 12) {
            ForEach(store.content.companions) { c in
                let present = state.presentCompanions.contains(c)
                let hearts = state.hearts(c.id)
                Card {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 14) {
                            CompanionPortrait(id: c.id)
                                .frame(width: 64, height: 64)
                                .background(Circle().fill(Palette.amberGlow.opacity(present ? 0.3 : 0.1)))
                                .brightness(present ? 0 : -1)
                                .opacity(present ? 1 : 0.25)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(present ? c.name : "???").font(.display(18)).foregroundStyle(Theme.ink)
                                Text(present ? c.species : arrivalHint(c)).font(.caption).foregroundStyle(Theme.inkSoft)
                                if present { HeartsRow(hearts: hearts, size: 11) }
                            }
                        }
                        if present {
                            Text(c.blurb).font(.subheadline).foregroundStyle(Theme.inkSoft)
                            ForEach(c.memories.keys.sorted().filter { $0 <= hearts }, id: \.self) { h in
                                if let memory = c.memories[h] {
                                    Text("“\(memory)”").font(.system(.subheadline, design: .serif)).italic().foregroundStyle(Theme.ink)
                                }
                            }
                            if hearts < 10 {
                                Text("Friends keep you company during sessions of 5 minutes or more.")
                                    .font(.caption2).foregroundStyle(Theme.inkSoft)
                            }
                        }
                    }
                }
            }
        }
    }

    private func arrivalHint(_ c: Companion) -> String {
        if let home = c.homeLandmark, let l = store.content.landmark(home) { return "Might appear if \(l.name) is restored" }
        return "Arrives as the story unfolds"
    }

    // MARK: Curios

    private var curios: some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                SectionTitle(title: "Curio cabinet", subtitle: "\(state.curios.count) of \(store.content.curios.count) found. Longer sessions find more.")
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 84), spacing: 12)], spacing: 14) {
                    ForEach(store.content.curios) { curio in
                        let found = state.curios[curio.id] != nil
                        Button { if found { inspecting = curio } } label: {
                            VStack(spacing: 6) {
                                CurioBadge(curio: curio, found: found).frame(width: 58, height: 58)
                                Text(found ? curio.name : "???").font(.caption.weight(.semibold))
                                    .foregroundStyle(found ? Theme.ink : Theme.inkSoft)
                                    .lineLimit(2).multilineTextAlignment(.center)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(found ? curio.name : "Undiscovered curio")
                    }
                }
            }
        }
    }

    // MARK: Achievements

    private var feats: some View {
        VStack(spacing: 10) {
            ForEach(store.content.achievements) { a in
                let date = state.achievements[a.id]
                HStack(spacing: 14) {
                    Image(systemName: a.symbol)
                        .font(.title3)
                        .foregroundStyle(date != nil ? Palette.ink : Theme.inkSoft)
                        .frame(width: 46, height: 46)
                        .background(Circle().fill(date != nil ? Color(hex: 0xF2C14E) : Theme.line.opacity(0.5)))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(a.title).font(.label).foregroundStyle(Theme.ink)
                        Text(a.blurb).font(.caption).foregroundStyle(Theme.inkSoft)
                    }
                    Spacer()
                    if let date {
                        Text(date, format: .dateTime.month(.abbreviated).day()).font(.caption2).foregroundStyle(Theme.inkSoft)
                    }
                }
                .padding(12)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .opacity(date != nil ? 1 : 0.75)
                .accessibilityElement(children: .combine)
            }
        }
    }
}

// MARK: - Chapter reader

@MainActor
struct ChapterReader: View {
    let chapter: Chapter
    @Environment(GameStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var page = 0

    var body: some View {
        ZStack {
            LinearGradient(colors: [Palette.duskDeep, Palette.dusk], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            VStack(spacing: 20) {
                Text("CHAPTER \(chapter.number)").font(.caption.weight(.bold)).tracking(2).foregroundStyle(Palette.lavender)
                Text(chapter.title).font(.system(.largeTitle, design: .serif, weight: .bold)).foregroundStyle(Palette.cream)
                    .multilineTextAlignment(.center)
                EmberView(appearance: store.state.appearance, mood: page == chapter.pages.count - 1 ? .happy : .curious)
                    .frame(width: 120, height: 120)
                TabView(selection: $page) {
                    ForEach(Array(chapter.pages.enumerated()), id: \.offset) { i, text in
                        Text(text.replacingOccurrences(of: "{name}", with: store.state.emberName))
                            .font(.system(.title3, design: .serif))
                            .foregroundStyle(Palette.cream)
                            .multilineTextAlignment(.center)
                            .lineSpacing(6)
                            .padding(.horizontal, 28)
                            .tag(i)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                Button(page < chapter.pages.count - 1 ? "Next" : "Close") {
                    if page < chapter.pages.count - 1 { withAnimation { page += 1 } } else { dismiss() }
                }
                .buttonStyle(GlowButtonStyle())
                .padding(.horizontal, Theme.gutter)
            }
            .padding(.vertical, 30)
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Small illustrated pieces

/// A creature from the grove, cropped from the world renderer so it matches exactly.
@MainActor
struct CompanionPortrait: View {
    let id: String

    private var frame: (cx: Double, cy: Double, span: Double) {
        switch id {
        case "tansy": (192, 458, 72)
        case "mosslings": (124, 464, 110)
        case "pebble": (612, 460, 40)
        case "wren": (853, 346, 36)
        case "hoot": (1058, 316, 42)
        case "glimmer": (1230, 428, 40)
        case "nox": (1383, 422, 60)
        default: (0, 0, 100)
        }
    }

    var body: some View {
        Canvas { ctx, size in
            let f = frame
            let s = min(size.width, size.height) / f.span
            ctx.translateBy(x: size.width / 2, y: size.height / 2)
            ctx.scaleBy(x: s, y: s)
            ctx.translateBy(x: -f.cx, y: -f.cy)
            GroveRenderer(ctx: ctx, snap: GroveSnapshot(), phase: .day, t: 2, still: true,
                          viewport: 0...GroveRenderer.width, hearthBoost: 0)
                .drawCompanion(id)
        }
        .accessibilityHidden(true)
    }
}

@MainActor
struct CurioBadge: View {
    let curio: Curio
    let found: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(found ? RadialGradient(colors: [Palette.amberGlow, Palette.amber.opacity(0.7)], center: .topLeading, startRadius: 2, endRadius: 60)
                            : RadialGradient(colors: [Theme.line, Theme.line.opacity(0.6)], center: .center, startRadius: 0, endRadius: 40))
            Circle().strokeBorder(.white.opacity(0.4), lineWidth: 1.5).padding(3)
            Image(systemName: found ? curio.symbol : "questionmark")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(found ? Palette.ink : Theme.inkSoft)
        }
    }
}
