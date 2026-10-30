import SwiftUI
import Observation
import WidgetKit

/// The single source of truth for the running app: owns the game state, drives the focus
/// timer, and fans changes out to persistence, iCloud, widgets, Live Activities and sound.
@MainActor
@Observable
final class GameStore {
    private(set) var state: GameState
    /// Set when a session finishes; drives the reward sequence.
    var pendingReward: RewardSummary?
    /// Short-lived message for milestones that happen outside a reward sequence.
    var banner: MilestoneChanges?
    /// Where to send the player next (e.g. after a reward sequence).
    var route: Route?
    var selectedTab: AppTab = .home

    enum Route: String, Identifiable {
        case restore, choosePath, focusSetup
        var id: String { rawValue }
    }

    @ObservationIgnored private var ticker: Timer?
    @ObservationIgnored private var cloudObserver: NSObjectProtocol?
    @ObservationIgnored private var rng = SystemRandomNumberGenerator()
    var sound: SoundEngine { SoundEngine.shared }

    var content: GameContent { state.content }
    var settings: AppSettings { state.settings }

    init(preview: GameState? = nil) {
        var loaded = preview ?? Persistence.load() ?? GameState()
        _ = loaded.refreshMilestones()
        state = loaded
        guard preview == nil else { return }
        applySettingsSideEffects()
        if state.settings.iCloudSync { startCloudSync() }
        if state.activeSession != nil { startTicker(); checkCompletion() }
        writeSnapshot()
    }

    // MARK: Mutation

    func update(_ change: (inout GameState) -> Void) {
        change(&state)
        persist()
    }

    private func persist() {
        Persistence.save(state)
        writeSnapshot()
        if state.settings.iCloudSync { CloudSync.push(state) }
    }

    private func writeSnapshot() {
        let s = state
        EmberSnapshot(
            name: s.emberName, level: s.level, stageName: s.stage.name, appearance: s.appearance,
            levelProgress: s.levelProgress, todayMinutes: s.todayMinutes,
            dailyGoalMinutes: s.settings.dailyGoalMinutes, lifetimeHours: Double(s.totalMinutes) / 60,
            restoredCount: s.restored.count, landmarkCount: s.content.landmarks.count,
            pendingChoices: s.pendingChoices, updated: .now
        ).save()
        WidgetCenter.shared.reloadAllTimelines()
    }

    func updateSettings(_ change: (inout AppSettings) -> Void) {
        let old = state.settings
        update { change(&$0.settings) }
        applySettingsSideEffects(previous: old)
    }

    private func applySettingsSideEffects(previous: AppSettings? = nil) {
        let s = state.settings
        Haptics.enabled = s.haptics
        sound.effectsEnabled = s.soundEffects
        if s.reminderEnabled {
            if previous?.reminderEnabled != true || previous?.reminderHour != s.reminderHour || previous?.reminderMinute != s.reminderMinute {
                Notifications.cancelReminder()
                Notifications.scheduleReminder(hour: s.reminderHour, minute: s.reminderMinute, name: state.emberName)
            }
        } else if previous?.reminderEnabled == true {
            Notifications.cancelReminder()
        }
        if s.iCloudSync && previous?.iCloudSync == false { startCloudSync() }
        if let session = state.activeSession, !session.isPaused, previous?.ambient != s.ambient || previous?.ambientVolume != s.ambientVolume {
            sound.setAmbient(s.ambient, volume: s.ambientVolume)
        }
    }

    // MARK: Cloud

    private func startCloudSync() {
        guard cloudObserver == nil else { return }
        cloudObserver = CloudSync.observe { [weak self] in
            Task { @MainActor in self?.mergeFromCloud() }
        }
        mergeFromCloud()
        CloudSync.push(state)
    }

    private func mergeFromCloud() {
        guard var remote = CloudSync.pull(), remote.lastModified > state.lastModified else { return }
        remote.activeSession = state.activeSession
        state = remote
        Persistence.save(state)
        writeSnapshot()
    }

    // MARK: Focus session

    var activeSession: ActiveSession? { state.activeSession }

    func startSession(mode: FocusMode, minutes: Int, category: FocusCategory) {
        let session = ActiveSession(mode: mode, category: category, startDate: .now,
                                    target: mode == .countdown ? TimeInterval(minutes * 60) : nil)
        update {
            $0.activeSession = session
            $0.settings.defaultMode = mode
            $0.settings.defaultCategory = category
            if mode == .countdown { $0.settings.defaultMinutes = minutes }
        }
        sessionDidChange()
        LiveActivities.start(session, name: state.emberName, appearance: state.appearance)
        sound.setAmbient(settings.ambient, volume: settings.ambientVolume)
        sound.play(.start)
        Haptics.tap(.medium)
        startTicker()
        if settings.sessionNotifications {
            Task { _ = await Notifications.requestAuthorization() }
        }
    }

    func pause() {
        guard var s = state.activeSession, !s.isPaused else { return }
        s.pausedAt = .now
        update { $0.activeSession = s }
        sound.stopAmbient()
        Haptics.tap()
        sessionDidChange()
    }

    func resume() {
        guard var s = state.activeSession, let pausedAt = s.pausedAt else { return }
        s.pausedTotal += Date.now.timeIntervalSince(pausedAt)
        s.pausedAt = nil
        update { $0.activeSession = s }
        sound.setAmbient(settings.ambient, volume: settings.ambientVolume)
        Haptics.tap()
        sessionDidChange()
    }

    func setAmbient(_ ambient: AmbientSound) {
        updateSettings { $0.ambient = ambient }
        if ambient == .none { sound.stopAmbient() }
    }

    /// Ends the session and banks every focused minute. Nothing is lost by finishing early.
    func finish(now: Date = .now) {
        guard let s = state.activeSession else { return }
        let elapsed = s.elapsed(at: now)
        let record = FocusRecord(start: s.startDate, end: now, seconds: Int(elapsed), category: s.category,
                                 mode: s.mode, reachedTarget: s.isComplete(at: now))
        stopSessionServices()
        guard record.minutes >= 1 else {
            update { $0.activeSession = nil }
            return
        }
        var summary: RewardSummary!
        update {
            $0.activeSession = nil
            summary = $0.applySession(record, now: now, rng: &rng)
        }
        pendingReward = summary
        sound.play(.complete)
        Haptics.success()
    }

    func discard() {
        stopSessionServices()
        update { $0.activeSession = nil }
    }

    private func stopSessionServices() {
        ticker?.invalidate()
        ticker = nil
        Notifications.cancelSessionEnd()
        LiveActivities.endAll()
        sound.stopAmbient()
        UIApplication.shared.isIdleTimerDisabled = false
    }

    private func sessionDidChange() {
        guard let s = state.activeSession else { return }
        Notifications.cancelSessionEnd()
        if let end = s.endDate, settings.sessionNotifications {
            Notifications.scheduleSessionEnd(at: end, name: state.emberName)
        }
        LiveActivities.update(s)
    }

    private func startTicker() {
        ticker?.invalidate()
        ticker = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.checkCompletion() }
        }
    }

    /// Countdown sessions complete themselves, even if the app was suspended past the end time.
    func checkCompletion() {
        guard let s = state.activeSession, s.mode == .countdown, !s.isPaused,
              let end = s.endDate, Date.now >= end else { return }
        finish(now: end)
    }

    func sceneBecameActive() {
        checkCompletion()
        writeSnapshot()
    }

    // MARK: Progression choices

    func restore(_ landmark: Landmark, variant: LandmarkVariant) {
        var changes = MilestoneChanges()
        update { changes = $0.restore(landmark.id, variant: variant.id) }
        sound.play(.levelUp)
        Haptics.celebrate()
        if !changes.isEmpty { banner = changes }
    }

    func choosePath(_ path: EmberPath) {
        var changes = MilestoneChanges()
        update { changes = $0.choosePath(path) }
        sound.play(.levelUp)
        Haptics.celebrate()
        if !changes.isEmpty { banner = changes }
    }

    func claim(_ quest: QuestStatus) {
        var claimed = false
        var changes = MilestoneChanges()
        update {
            claimed = $0.claim(quest)
            if claimed { changes = $0.refreshMilestones() }
        }
        guard claimed else { return }
        sound.play(.discover)
        Haptics.success()
        if !changes.isEmpty { banner = changes }
    }

    func buy(_ cosmetic: Cosmetic) -> Bool {
        var ok = false
        update { ok = $0.buyCosmetic(cosmetic) }
        if ok { sound.play(.discover); Haptics.success() }
        return ok
    }

    func buy(_ decoration: Decoration) -> Bool {
        var ok = false
        update { ok = $0.buyDecoration(decoration) }
        if ok { sound.play(.discover); Haptics.success() }
        return ok
    }

    func equip(_ cosmetic: Cosmetic?, slot: CosmeticSlot) {
        update { $0.equip(cosmetic, slot: slot) }
        sound.play(.tap)
        Haptics.selection()
    }

    func toggleDecoration(_ id: String) {
        update {
            if $0.hiddenDecorations.contains(id) { $0.hiddenDecorations.remove(id) } else { $0.hiddenDecorations.insert(id) }
        }
        Haptics.selection()
    }

    func markRead(_ chapter: String) {
        guard !state.chaptersRead.contains(chapter) else { return }
        update { $0.chaptersRead.insert(chapter) }
    }

    func rename(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        update { $0.emberName = String(trimmed.prefix(16)) }
    }

    func resetProgress() {
        stopSessionServices()
        let settings = state.settings
        var fresh = GameState()
        fresh.settings = settings
        _ = fresh.refreshMilestones()
        state = fresh
        persist()
    }
}
