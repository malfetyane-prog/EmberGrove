import Foundation

struct FocusRecord: Codable, Identifiable, Hashable {
    var id = UUID()
    var start: Date
    var end: Date
    var seconds: Int
    var category: FocusCategory
    var mode: FocusMode
    var reachedTarget: Bool

    var minutes: Int { seconds / 60 }
}

/// The session in progress. Time is derived from dates, never from ticking counters,
/// so it stays correct while the app is suspended or the phone is locked.
struct ActiveSession: Codable, Equatable {
    var id = UUID()
    var mode: FocusMode
    var category: FocusCategory
    var startDate: Date
    var target: TimeInterval?
    var pausedTotal: TimeInterval = 0
    var pausedAt: Date?

    var isPaused: Bool { pausedAt != nil }

    func elapsed(at now: Date = .now) -> TimeInterval {
        let end = pausedAt ?? now
        var value = end.timeIntervalSince(startDate) - pausedTotal
        if let target { value = min(value, target) }
        return max(0, value)
    }

    func remaining(at now: Date = .now) -> TimeInterval? {
        guard let target else { return nil }
        return max(0, target - elapsed(at: now))
    }

    func progress(at now: Date = .now) -> Double? {
        guard let target, target > 0 else { return nil }
        return elapsed(at: now) / target
    }

    /// Wall-clock moment the countdown finishes, if running.
    var endDate: Date? {
        guard let target, pausedAt == nil else { return nil }
        return startDate.addingTimeInterval(pausedTotal + target)
    }

    var effectiveStart: Date { startDate.addingTimeInterval(pausedTotal) }

    func isComplete(at now: Date = .now) -> Bool {
        guard let target else { return false }
        return elapsed(at: now) >= target - 0.5
    }
}

struct JournalEntry: Codable, Identifiable, Hashable {
    var id = UUID()
    var date: Date
    var text: String
    var symbol: String
}

enum AmbientSound: String, Codable, CaseIterable, Identifiable {
    case none, campfire, rain, breeze
    var id: String { rawValue }
    var title: String {
        switch self {
        case .none: "Silence"
        case .campfire: "Campfire"
        case .rain: "Soft Rain"
        case .breeze: "Forest Breeze"
        }
    }
    var symbol: String {
        switch self {
        case .none: "speaker.slash.fill"
        case .campfire: "flame.fill"
        case .rain: "cloud.rain.fill"
        case .breeze: "wind"
        }
    }
}

enum AppearancePreference: String, Codable, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

struct AppSettings: Codable, Equatable {
    var defaultMode: FocusMode = .countdown
    var defaultMinutes: Int = 25
    var defaultCategory: FocusCategory = .studying
    var dailyGoalMinutes: Int = 60
    var ambient: AmbientSound = .campfire
    var ambientVolume: Double = 0.6
    var soundEffects: Bool = true
    var haptics: Bool = true
    var sessionNotifications: Bool = true
    var reminderEnabled: Bool = false
    var reminderHour: Int = 9
    var reminderMinute: Int = 0
    var reduceMotion: Bool = false
    var keepScreenAwake: Bool = true
    var appearance: AppearancePreference = .system
    var iCloudSync: Bool = false
    var hasOnboarded: Bool = false
}

struct GameState: Codable, Equatable {
    var version = 1
    var characterId = "ember"
    var worldId = "grove"
    var createdAt = Date()
    var lastModified = Date()

    // Character
    var emberName = "Ember"
    var xp = 0
    var seeds = 0
    var path: EmberPath?
    var equippedHead: String?
    var equippedNeck: String?
    var equippedFace: String?
    var flameTint = "amber"
    var purchasedCosmetics: Set<String> = []

    // World
    var restored: [String: String] = [:]
    var restoredOrder: [String] = []
    var unlockedAreas: Set<String> = ["clearing"]
    var ownedDecorations: Set<String> = []
    var hiddenDecorations: Set<String> = []
    var friendship: [String: Int] = [:]
    var curios: [String: Date] = [:]

    // Story & progress
    var chapters: [String: Date] = [:]
    var chaptersRead: Set<String> = []
    var achievements: [String: Date] = [:]
    var claimedQuests: Set<String> = []
    var sessions: [FocusRecord] = []
    var journal: [JournalEntry] = []

    var activeSession: ActiveSession?
    var settings = AppSettings()

    var appearance: EmberAppearance {
        EmberAppearance(stage: stageIndex, path: path, head: equippedHead, neck: equippedNeck,
                        face: equippedFace, flameTint: flameTint)
    }
}
