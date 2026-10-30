import Foundation

// MARK: - Leveling

enum Leveling {
    static let glowPerMinute = 10
    static let maxLevel = 50

    /// Total Glow needed to reach `level`. Level 2 takes 10 minutes; level 8 (first evolution choice)
    /// about 2.5 hours; the final form (level 25) about 22 hours.
    static func xpRequired(forLevel level: Int) -> Int {
        let n = max(1, level) - 1
        return 100 * n + 20 * n * max(0, n - 1)
    }

    static func level(forXP xp: Int) -> Int {
        var level = 1
        while level < maxLevel && xp >= xpRequired(forLevel: level + 1) { level += 1 }
        return level
    }

    /// Fraction of the way from the current level to the next.
    static func progress(forXP xp: Int) -> Double {
        let level = level(forXP: xp)
        guard level < maxLevel else { return 1 }
        let lo = xpRequired(forLevel: level), hi = xpRequired(forLevel: level + 1)
        return Double(xp - lo) / Double(hi - lo)
    }
}

struct Bonuses {
    var discoveryChance = 0.0
    var seedMultiplier = 1.0
    var friendshipMultiplier = 1.0
    var glowMultiplier = 1.0
    var minDiscoveryMinutes = 10
}

/// One line in the reward breakdown, e.g. "Finished your timer +50".
struct GlowLine: Hashable {
    let label: String
    let amount: Int
}

struct CompanionVisit: Hashable {
    let companion: String
    let heartsBefore: Int
    let heartsAfter: Int
    let gifts: [RewardItem]
    let memories: [String]
}

struct RewardSummary: Identifiable {
    let id = UUID()
    var record: FocusRecord
    var glowLines: [GlowLine] = []
    var glowTotal = 0
    var seeds = 0
    var levelBefore = 1
    var levelAfter = 1
    var appearanceBefore = EmberAppearance.starter
    var appearanceAfter = EmberAppearance.starter
    var evolved = false
    var pathChoiceReady = false
    var newCosmetics: [String] = []
    var companionVisit: CompanionVisit?
    var discovery: String?
    var renewalsEarned = 0
    var milestones = MilestoneChanges()
    var questsReady = 0
}

struct MilestoneChanges: Hashable {
    var areas: [String] = []
    var chapters: [String] = []
    var achievements: [String] = []
    var companionsArrived: [String] = []

    var isEmpty: Bool { areas.isEmpty && chapters.isEmpty && achievements.isEmpty && companionsArrived.isEmpty }

    mutating func merge(_ other: MilestoneChanges) {
        areas += other.areas
        chapters += other.chapters
        achievements += other.achievements
        companionsArrived += other.companionsArrived
    }
}

struct QuestStatus: Identifiable, Hashable {
    let template: QuestTemplate
    let progress: Int
    let claimKey: String
    let claimed: Bool
    var id: String { claimKey }
    var isComplete: Bool { progress >= template.target }
    var fraction: Double { min(1, Double(progress) / Double(max(1, template.target))) }
}

// MARK: - Derived state

extension GameState {
    static let content = GameContent.grove
    var content: GameContent { Self.content }

    var level: Int { Leveling.level(forXP: xp) }
    var levelProgress: Double { Leveling.progress(forXP: xp) }

    var stageIndex: Int {
        let lvl = level
        if lvl >= 25, path != nil { return 4 }
        if lvl >= 15, path != nil { return 3 }
        if lvl >= 8, path != nil { return 2 }
        if lvl >= 4 { return 1 }
        return 0
    }

    var stage: EvolutionStage { content.stage(index: stageIndex, path: path) }
    var canChoosePath: Bool { path == nil && level >= 8 }

    var totalSeconds: Int { sessions.reduce(0) { $0 + $1.seconds } }
    var totalMinutes: Int { totalSeconds / 60 }

    var renewalsEarned: Int { content.renewalMilestones.filter { totalMinutes >= $0 }.count }
    var renewalsAvailable: Int { max(0, renewalsEarned - restored.count) }
    var nextRenewalMinutes: Int? { content.renewalMilestones.first { $0 > totalMinutes } }

    var pendingChoices: Int {
        let renewals = min(renewalsAvailable, availableLandmarks.count)
        return renewals + (canChoosePath ? 1 : 0)
    }

    func isAreaUnlocked(_ id: String) -> Bool { unlockedAreas.contains(id) }

    func isLandmarkVisible(_ l: Landmark) -> Bool {
        guard isAreaUnlocked(l.area) else { return false }
        if let curio = l.requiresCurio, curios[curio] == nil { return false }
        return true
    }

    var availableLandmarks: [Landmark] {
        content.landmarks.filter { l in
            restored[l.id] == nil && isLandmarkVisible(l) && (l.requiresLandmark.map { restored[$0] != nil } ?? true)
        }
    }

    var hearthLit: Bool { !sessions.isEmpty }

    var presentCompanions: [Companion] {
        content.companions.filter { c in
            if let home = c.homeLandmark { return restored[home] != nil }
            if let chapter = c.arrivesWithChapter { return chapters[chapter] != nil }
            return false
        }
    }

    static let pointsPerHeart = 25

    func hearts(_ companion: String) -> Int {
        min(10, (friendship[companion] ?? 0) / Self.pointsPerHeart)
    }

    var bonuses: Bonuses {
        var b = Bonuses()
        let unlocked = content.abilities.filter { $0.stage <= stageIndex && ($0.path == nil || $0.path == path) }
        for ability in unlocked {
            switch ability.id {
            case "emberSense": b.discoveryChance += 0.05
            case "wayfinder": b.discoveryChance += 0.10
            case "steadyFlame": b.seedMultiplier += 0.10
            case "gentleRain": b.seedMultiplier += 0.15
            case "hearthSong", "greenThumb": b.friendshipMultiplier += 0.25
            case "everflame", "evergreen", "astralTide": b.glowMultiplier += 0.10
            case "nightSight": b.minDiscoveryMinutes = 5
            default: break
            }
        }
        return b
    }

    var unlockedCosmeticIds: [String] {
        content.cosmetics.filter { isCosmeticUnlocked($0) }.map(\.id)
    }

    var unlockedAbilities: [Ability] {
        content.abilities.filter { $0.stage <= stageIndex && ($0.path == nil || $0.path == path) }
    }

    func isCosmeticUnlocked(_ c: Cosmetic) -> Bool {
        switch c.unlock {
        case .starter: return true
        case .level(let n): return level >= n
        case .seeds: return purchasedCosmetics.contains(c.id)
        case .gift: return purchasedCosmetics.contains(c.id)
        case .path(let p): return path == p && stageIndex >= 2
        case .curios(let n): return curios.count >= n
        }
    }

    func equipped(_ slot: CosmeticSlot) -> String? {
        switch slot {
        case .head: equippedHead
        case .neck: equippedNeck
        case .face: equippedFace
        case .flame: flameTint
        }
    }

    // MARK: Stats helpers

    func minutes(on day: Date, calendar: Calendar = .current) -> Int {
        sessions.filter { calendar.isDate($0.start, inSameDayAs: day) }.reduce(0) { $0 + $1.seconds } / 60
    }

    func sessions(inWeekOf date: Date, calendar: Calendar = .current) -> [FocusRecord] {
        guard let week = calendar.dateInterval(of: .weekOfYear, for: date) else { return [] }
        return sessions.filter { week.contains($0.start) }
    }

    func sessions(onDay date: Date, calendar: Calendar = .current) -> [FocusRecord] {
        sessions.filter { calendar.isDate($0.start, inSameDayAs: date) }
    }

    var todayMinutes: Int { minutes(on: .now) }

    // MARK: Quests

    static func dayKey(_ date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    static func weekKey(_ date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return String(format: "%04d-W%02d", c.yearForWeekOfYear ?? 0, c.weekOfYear ?? 0)
    }

    func quests(_ cadence: QuestTemplate.Cadence, now: Date = .now, calendar: Calendar = .current) -> [QuestStatus] {
        let pool = content.quests.filter { $0.cadence == cadence }
        let key = cadence == .daily ? Self.dayKey(now, calendar: calendar) : Self.weekKey(now, calendar: calendar)
        var rng = SeededGenerator(seed: UInt64(abs(key.hashValueStable)))
        let picked = Array(pool.shuffled(using: &rng).prefix(cadence == .daily ? 3 : 2))
        let records = cadence == .daily ? sessions(onDay: now, calendar: calendar) : sessions(inWeekOf: now, calendar: calendar)
        return picked.map { t in
            let claimKey = "\(t.id)@\(key)"
            return QuestStatus(template: t, progress: Self.progress(of: t.metric, in: records, calendar: calendar),
                               claimKey: claimKey, claimed: claimedQuests.contains(claimKey))
        }
    }

    static func progress(of metric: QuestMetric, in records: [FocusRecord], calendar: Calendar) -> Int {
        switch metric {
        case .minutes: return records.reduce(0) { $0 + $1.seconds } / 60
        case .sessions: return records.filter { $0.minutes >= 1 }.count
        case .categoryMinutes(let c): return records.filter { $0.category == c }.reduce(0) { $0 + $1.seconds } / 60
        case .longestSession: return records.map(\.minutes).max() ?? 0
        case .startedBeforeNoon: return records.contains { calendar.component(.hour, from: $0.start) < 12 } ? 1 : 0
        case .distinctDays: return Set(records.map { calendar.startOfDay(for: $0.start) }).count
        case .distinctCategories: return Set(records.map(\.category)).count
        }
    }

    var claimableQuests: Int {
        (quests(.daily) + quests(.weekly)).filter { $0.isComplete && !$0.claimed }.count
    }
}

// MARK: - Mutations

extension GameState {
    mutating func log(_ text: String, symbol: String, date: Date = .now) {
        journal.append(JournalEntry(date: date, text: text.replacingOccurrences(of: "{name}", with: emberName), symbol: symbol))
    }

    /// Applies a finished focus session and returns everything that happened, for the reward sequence.
    /// Rewards never shrink for ending early: every focused minute counts.
    mutating func applySession(_ record: FocusRecord, now: Date = .now,
                               rng: inout some RandomNumberGenerator) -> RewardSummary {
        var summary = RewardSummary(record: record)
        summary.levelBefore = level
        summary.appearanceBefore = appearance
        let cosmeticsBefore = Set(unlockedCosmeticIds)
        let renewalsBefore = renewalsEarned
        let bonus = bonuses
        let previousEnd = sessions.map(\.end).max()
        let minutes = record.minutes

        sessions.append(record)
        guard minutes >= 1 else {
            summary.levelAfter = level
            summary.appearanceAfter = appearance
            return summary
        }

        // Glow
        let base = minutes * Leveling.glowPerMinute
        var lines = [GlowLine(label: "\(minutes) focused minute\(minutes == 1 ? "" : "s")", amount: base)]
        if record.mode == .countdown && record.reachedTarget {
            lines.append(GlowLine(label: "Finished your timer", amount: base / 5))
        } else if record.mode == .stopwatch && minutes >= 25 {
            lines.append(GlowLine(label: "Long, steady session", amount: base / 10))
        }
        if let previousEnd, now.timeIntervalSince(previousEnd) > 36 * 3600 {
            lines.append(GlowLine(label: "Welcome back, rested glow", amount: base / 4))
        }
        if bonus.glowMultiplier > 1 {
            lines.append(GlowLine(label: "\(stage.name)'s radiance", amount: Int(Double(base) * (bonus.glowMultiplier - 1))))
        }
        summary.glowLines = lines
        summary.glowTotal = lines.reduce(0) { $0 + $1.amount }
        xp += summary.glowTotal

        // Seeds
        let seedBase = max(1, minutes / 5)
        summary.seeds = Int((Double(seedBase) * bonus.seedMultiplier).rounded())
        seeds += summary.seeds

        // Companion keeps you company
        let present = presentCompanions.filter { hearts($0.id) < 10 }
        if minutes >= 5, !present.isEmpty {
            let weights = present.map { 11 - hearts($0.id) }
            var roll = Int.random(in: 0..<weights.reduce(0, +), using: &rng)
            var chosen = present[0]
            for (c, w) in zip(present, weights) {
                if roll < w { chosen = c; break }
                roll -= w
            }
            let before = hearts(chosen.id)
            friendship[chosen.id, default: 0] += Int((Double(minutes) * bonus.friendshipMultiplier).rounded())
            let after = hearts(chosen.id)
            var gifts: [RewardItem] = []
            var memories: [String] = []
            if after > before {
                for h in (before + 1)...after {
                    if let gift = chosen.gifts[h] { gifts.append(grant(gift)) }
                    if let memory = chosen.memories[h] {
                        memories.append(memory)
                        log(memory, symbol: "heart.fill", date: now)
                    }
                }
            }
            summary.companionVisit = CompanionVisit(companion: chosen.id, heartsBefore: before, heartsAfter: after,
                                                    gifts: gifts, memories: memories)
        }

        // Discovery
        if minutes >= bonus.minDiscoveryMinutes {
            let chance = min(0.75, 0.12 + Double(minutes) * 0.01 + bonus.discoveryChance)
            if Double.random(in: 0..<1, using: &rng) < chance, let curio = pickCurio(rng: &rng) {
                curios[curio.id] = now
                summary.discovery = curio.id
                log("Found something in the grove: \(curio.name).", symbol: curio.symbol, date: now)
            }
        }

        if sessions.count == 1 {
            log("{name} lit the hearth for the first time.", symbol: "flame.fill", date: now)
        }

        summary.levelAfter = level
        summary.appearanceAfter = appearance
        summary.evolved = summary.appearanceAfter.stage != summary.appearanceBefore.stage
        if summary.evolved {
            log("{name} grew into a \(stage.name)!", symbol: "sparkles", date: now)
        }
        summary.pathChoiceReady = canChoosePath
        summary.newCosmetics = unlockedCosmeticIds.filter { !cosmeticsBefore.contains($0) }
        summary.renewalsEarned = renewalsEarned - renewalsBefore
        summary.milestones = refreshMilestones(now: now)
        summary.questsReady = claimableQuests
        lastModified = now
        return summary
    }

    private func pickCurio(rng: inout some RandomNumberGenerator) -> Curio? {
        let candidates = content.curios.filter { curios[$0.id] == nil && isAreaUnlocked($0.area) }
        // The star map is story-critical: it turns up first once the ridge is open.
        if let map = candidates.first(where: { $0.id == "starMap" }) { return map }
        return candidates.randomElement(using: &rng)
    }

    /// Grants a gift. Duplicates turn into seeds so a reward is never wasted.
    mutating func grant(_ item: RewardItem) -> RewardItem {
        switch item {
        case .seeds(let n):
            seeds += n
            return item
        case .cosmetic(let id):
            if purchasedCosmetics.contains(id) { seeds += 30; return .seeds(30) }
            purchasedCosmetics.insert(id)
            return item
        case .decoration(let id):
            if ownedDecorations.contains(id) { seeds += 30; return .seeds(30) }
            ownedDecorations.insert(id)
            return item
        }
    }

    mutating func restore(_ landmarkId: String, variant: String, now: Date = .now) -> MilestoneChanges {
        guard renewalsAvailable > 0, let landmark = content.landmark(landmarkId),
              availableLandmarks.contains(landmark) else { return MilestoneChanges() }
        restored[landmarkId] = variant
        restoredOrder.append(landmarkId)
        let variantName = landmark.variants.first { $0.id == variant }?.name ?? ""
        log("Restored \(landmark.name) with \(variantName).", symbol: "leaf.fill", date: now)
        if let companion = landmark.companion, let c = content.companion(companion) {
            log("\(c.name) moved in.", symbol: "pawprint.fill", date: now)
        }
        lastModified = now
        return refreshMilestones(now: now)
    }

    mutating func choosePath(_ newPath: EmberPath, now: Date = .now) -> MilestoneChanges {
        guard canChoosePath else { return MilestoneChanges() }
        path = newPath
        if let tint = content.cosmetics.first(where: { $0.unlock == .path(newPath) }) { flameTint = tint.id }
        log("{name} chose the path of \(newPath.title) and became a \(stage.name).", symbol: "arrow.triangle.branch", date: now)
        lastModified = now
        return refreshMilestones(now: now)
    }

    mutating func claim(_ quest: QuestStatus) -> Bool {
        guard quest.isComplete, !claimedQuests.contains(quest.claimKey) else { return false }
        claimedQuests.insert(quest.claimKey)
        seeds += quest.template.seeds
        xp += quest.template.glow
        lastModified = .now
        return true
    }

    mutating func buyCosmetic(_ cosmetic: Cosmetic) -> Bool {
        guard case .seeds(let cost) = cosmetic.unlock, seeds >= cost, !purchasedCosmetics.contains(cosmetic.id) else { return false }
        seeds -= cost
        purchasedCosmetics.insert(cosmetic.id)
        lastModified = .now
        return true
    }

    mutating func buyDecoration(_ decoration: Decoration) -> Bool {
        guard seeds >= decoration.cost, !ownedDecorations.contains(decoration.id) else { return false }
        seeds -= decoration.cost
        ownedDecorations.insert(decoration.id)
        log("Added \(decoration.name) to the clearing.", symbol: "house.fill")
        lastModified = .now
        return true
    }

    mutating func equip(_ cosmetic: Cosmetic?, slot: CosmeticSlot) {
        if let cosmetic, !isCosmeticUnlocked(cosmetic) { return }
        switch slot {
        case .head: equippedHead = cosmetic?.id
        case .neck: equippedNeck = cosmetic?.id
        case .face: equippedFace = cosmetic?.id
        case .flame: flameTint = cosmetic?.id ?? "amber"
        }
        lastModified = .now
    }

    /// Unlocks areas, chapters and achievements whose conditions are now met.
    mutating func refreshMilestones(now: Date = .now) -> MilestoneChanges {
        var changes = MilestoneChanges()
        let minutes = totalMinutes

        for area in content.areas where !unlockedAreas.contains(area.id) && minutes >= area.unlockMinutes {
            unlockedAreas.insert(area.id)
            changes.areas.append(area.id)
            log("The frost lifted from \(area.name).", symbol: "map.fill", date: now)
        }

        let companionsBefore = Set(presentCompanions.map(\.id))
        for chapter in content.chapters where chapters[chapter.id] == nil && isTriggered(chapter.trigger) {
            chapters[chapter.id] = now
            changes.chapters.append(chapter.id)
        }
        changes.companionsArrived = presentCompanions.map(\.id).filter { !companionsBefore.contains($0) }
        for id in changes.companionsArrived where content.companion(id)?.homeLandmark == nil {
            if let c = content.companion(id) { log("\(c.name) the \(c.species.lowercased()) arrived at the hearth.", symbol: "pawprint.fill", date: now) }
        }

        for achievement in content.achievements where achievements[achievement.id] == nil && isEarned(achievement.id) {
            achievements[achievement.id] = now
            changes.achievements.append(achievement.id)
        }
        return changes
    }

    private func isTriggered(_ trigger: ChapterTrigger) -> Bool {
        switch trigger {
        case .start: return true
        case .firstSession: return sessions.contains { $0.minutes >= 1 }
        case .firstRestoration: return !restored.isEmpty
        case .areaUnlocked(let id): return unlockedAreas.contains(id)
        case .pathChosen: return path != nil
        case .landmark(let id): return restored[id] != nil
        case .curio(let id): return curios[id] != nil
        case .allRestored: return restored.count >= content.landmarks.count
        }
    }

    private func isEarned(_ id: String, calendar: Calendar = .current) -> Bool {
        let counted = sessions.filter { $0.minutes >= 1 }
        switch id {
        case "firstSpark": return !counted.isEmpty
        case "hourOfGlow": return totalMinutes >= 60
        case "tenHours": return totalMinutes >= 600
        case "fiftyHours": return totalMinutes >= 3000
        case "hundredHours": return totalMinutes >= 6000
        case "deepDive": return counted.contains { $0.minutes >= 60 }
        case "earlyBird": return counted.contains { calendar.component(.hour, from: $0.start) < 8 }
        case "nightOwl": return counted.contains { calendar.component(.hour, from: $0.end) >= 22 }
        case "wellRounded": return Set(counted.map(\.category)).count >= 4
        case "steadyWeek":
            let byWeek = Dictionary(grouping: counted) { Self.weekKey($0.start, calendar: calendar) }
            return byWeek.values.contains { Set($0.map { calendar.startOfDay(for: $0.start) }).count >= 5 }
        case "pathfinder": return path != nil
        case "elder": return stageIndex >= 4
        case "restorer": return restored.count >= 6
        case "explorer": return unlockedAreas.count >= content.areas.count
        case "trueFriend": return content.companions.contains { hearts($0.id) >= 10 }
        case "collector": return curios.count >= 12
        case "rekindled": return restored.count >= content.landmarks.count
        default: return false
        }
    }
}

// MARK: - Utilities

/// Deterministic generator so daily quests are stable for the whole day.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed &+ 0x9E3779B97F4A7C15 }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

extension String {
    /// `hashValue` is randomized per launch; this one is stable (FNV-1a).
    var hashValueStable: Int {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in utf8 { hash = (hash ^ UInt64(byte)) &* 0x100000001b3 }
        return Int(truncatingIfNeeded: hash >> 1)
    }
}
