import Foundation
import UIKit
import UserNotifications
import ActivityKit

// MARK: - Haptics

@MainActor
enum Haptics {
    static var enabled = true

    static func success() {
        guard enabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func tap(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .soft) {
        guard enabled else { return }
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    static func selection() {
        guard enabled else { return }
        UISelectionFeedbackGenerator().selectionChanged()
    }

    /// A rising three-beat pattern for evolutions and big unlocks.
    static func celebrate() {
        guard enabled else { return }
        let gen = UIImpactFeedbackGenerator(style: .rigid)
        gen.prepare()
        for (i, intensity) in [0.5, 0.75, 1.0].enumerated() {
            after(Double(i) * 0.12) {
                gen.impactOccurred(intensity: intensity)
            }
        }
        after(0.42) { success() }
    }
}

// MARK: - Notifications

enum Notifications {
    private static let sessionId = "ember.session.end"
    private static let reminderId = "ember.daily.reminder"

    static func requestAuthorization() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    static func scheduleSessionEnd(at date: Date, name: String) {
        let content = UNMutableNotificationContent()
        content.title = "Session complete"
        content.body = "\(name) kept the fire warm the whole time. Come see what you earned."
        content.sound = .default
        content.interruptionLevel = .timeSensitive
        let interval = max(1, date.timeIntervalSinceNow)
        let request = UNNotificationRequest(identifier: sessionId, content: content,
                                            trigger: UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false))
        UNUserNotificationCenter.current().add(request)
    }

    static func cancelSessionEnd() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [sessionId])
    }

    static func scheduleReminder(hour: Int, minute: Int, name: String) {
        let lines = [
            "\(name) is warming up by the hearth. Ready for a little focus?",
            "The grove is quiet today. A short session might wake something up.",
            "\(name) saved you a spot by the fire.",
        ]
        let content = UNMutableNotificationContent()
        content.title = "Ember Grove"
        content.body = lines.randomElement() ?? lines[0]
        content.sound = .default
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        let request = UNNotificationRequest(identifier: reminderId, content: content,
                                            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true))
        UNUserNotificationCenter.current().add(request)
    }

    static func cancelReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [reminderId])
    }
}

// MARK: - Live Activities

@MainActor
enum LiveActivities {
    private static var current: Activity<FocusActivityAttributes>?

    static func start(_ session: ActiveSession, name: String, appearance: EmberAppearance) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        endAll()
        let attributes = FocusActivityAttributes(emberName: name, appearance: appearance,
                                                 isCountdown: session.mode == .countdown,
                                                 targetDuration: session.target)
        do {
            current = try Activity<FocusActivityAttributes>.request(attributes: attributes,
                                           content: ActivityContent(state: state(for: session), staleDate: nil))
        } catch {
            print("Live Activity failed: \(error)")
        }
    }

    static func update(_ session: ActiveSession) {
        guard let activity = current else { return }
        let content = ActivityContent(state: state(for: session), staleDate: nil)
        Task { await activity.update(content) }
    }

    static func endAll() {
        current = nil
        for activity in Activity<FocusActivityAttributes>.activities {
            Task { await activity.end(nil, dismissalPolicy: .immediate) }
        }
    }

    private static func state(for s: ActiveSession) -> FocusActivityAttributes.ContentState {
        FocusActivityAttributes.ContentState(
            timerStart: s.effectiveStart,
            endDate: s.endDate,
            pausedElapsed: s.isPaused ? s.elapsed() : nil,
            categoryTitle: s.category.title,
            categorySymbol: s.category.symbol
        )
    }
}
