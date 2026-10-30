import Foundation
#if canImport(ActivityKit)
import ActivityKit
#endif

/// Identifiers shared between the app and its widget extension.
/// Change `appGroup` to match the App Group you register in your developer account.
enum AppGroup {
    static let identifier = "group.com.example.embergrove"
    static let snapshotKey = "ember.snapshot"

    static var defaults: UserDefaults {
        UserDefaults(suiteName: identifier) ?? .standard
    }

    static var containerURL: URL {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    }
}

// MARK: - Character appearance

enum EmberPath: String, Codable, CaseIterable, Identifiable, Hashable {
    case hearth, bloom, starlight
    var id: String { rawValue }

    var title: String {
        switch self {
        case .hearth: "Hearth"
        case .bloom: "Bloom"
        case .starlight: "Starlight"
        }
    }

    var tagline: String {
        switch self {
        case .hearth: "A warm, steady keeper who builds and gathers friends around the fire."
        case .bloom: "A gentle gardener whose glow coaxes flowers and creatures out of hiding."
        case .starlight: "A curious wanderer drawn to secrets, maps, and the quiet of the night sky."
        }
    }
}

/// Everything needed to draw Ember. Shared with widgets and Live Activities
/// so the same character appears everywhere.
struct EmberAppearance: Codable, Hashable {
    /// 0 Spark, 1 Kindle, 2–4 path forms.
    var stage: Int = 0
    var path: EmberPath? = nil
    var head: String? = nil
    var neck: String? = nil
    var face: String? = nil
    var flameTint: String = "amber"

    static let starter = EmberAppearance()
}

/// Lightweight state the widget displays. Written by the app after each change.
struct EmberSnapshot: Codable, Hashable {
    var name: String
    var level: Int
    var stageName: String
    var appearance: EmberAppearance
    var levelProgress: Double
    var todayMinutes: Int
    var dailyGoalMinutes: Int
    var lifetimeHours: Double
    var restoredCount: Int
    var landmarkCount: Int
    var pendingChoices: Int
    var updated: Date

    static let placeholder = EmberSnapshot(
        name: "Ember", level: 3, stageName: "Spark", appearance: .starter,
        levelProgress: 0.45, todayMinutes: 25, dailyGoalMinutes: 60,
        lifetimeHours: 2.5, restoredCount: 1, landmarkCount: 12,
        pendingChoices: 0, updated: .now
    )

    static func load() -> EmberSnapshot? {
        guard let data = AppGroup.defaults.data(forKey: AppGroup.snapshotKey) else { return nil }
        return try? JSONDecoder().decode(EmberSnapshot.self, from: data)
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            AppGroup.defaults.set(data, forKey: AppGroup.snapshotKey)
        }
    }
}

// MARK: - Live Activity

#if canImport(ActivityKit)
struct FocusActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        /// Start date shifted forward by paused time, so `now - timerStart` is the focused time.
        var timerStart: Date
        /// For countdowns: when the session finishes (nil while paused or in stopwatch mode).
        var endDate: Date?
        /// Set while paused: the focused time frozen at the moment of pausing.
        var pausedElapsed: TimeInterval?
        var categoryTitle: String
        var categorySymbol: String
    }

    var emberName: String
    var appearance: EmberAppearance
    var isCountdown: Bool
    var targetDuration: TimeInterval?
}
#endif
