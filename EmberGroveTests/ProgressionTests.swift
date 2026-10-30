import XCTest
@testable import EmberGrove

final class ProgressionTests: XCTestCase {
    private func record(minutes: Int, at start: Date = .now, mode: FocusMode = .countdown,
                        reached: Bool = true, category: FocusCategory = .studying) -> FocusRecord {
        FocusRecord(start: start, end: start.addingTimeInterval(TimeInterval(minutes * 60)), seconds: minutes * 60,
                    category: category, mode: mode, reachedTarget: reached)
    }

    func testLevelCurve() {
        XCTAssertEqual(Leveling.level(forXP: 0), 1)
        XCTAssertEqual(Leveling.level(forXP: 99), 1)
        XCTAssertEqual(Leveling.level(forXP: 100), 2)
        XCTAssertEqual(Leveling.xpRequired(forLevel: 8), 1540)   // ~2.5 hours to the first evolution choice
        XCTAssertEqual(Leveling.xpRequired(forLevel: 25), 13_440) // ~22 hours to the final form
    }

    func testCountdownSurvivesPause() {
        let start = Date(timeIntervalSince1970: 0)
        var s = ActiveSession(mode: .countdown, category: .reading, startDate: start, target: 1500)
        s.pausedAt = start.addingTimeInterval(600)
        XCTAssertEqual(s.elapsed(at: start.addingTimeInterval(5000)), 600, accuracy: 0.001)
        s.pausedTotal = 300
        s.pausedAt = nil
        XCTAssertEqual(s.endDate, start.addingTimeInterval(1800))
        XCTAssertTrue(s.isComplete(at: start.addingTimeInterval(1800)))
        XCTAssertEqual(s.elapsed(at: start.addingTimeInterval(99_999)), 1500, accuracy: 0.001) // capped at target
    }

    func testFinishingEarlyKeepsEveryMinute() {
        var state = GameState()
        var rng = SeededGenerator(seed: 1)
        let summary = state.applySession(record(minutes: 12, reached: false), rng: &rng)
        XCTAssertEqual(summary.glowLines.first?.amount, 120)
        XCTAssertEqual(state.xp, summary.glowTotal)
        XCTAssertGreaterThanOrEqual(state.xp, 120)
    }

    func testCompletedTimerBonus() {
        var state = GameState()
        var rng = SeededGenerator(seed: 1)
        let summary = state.applySession(record(minutes: 25), rng: &rng)
        XCTAssertTrue(summary.glowLines.contains { $0.label == "Finished your timer" && $0.amount == 50 })
    }

    func testFirstSessionUnlocksChapterAndAchievement() {
        var state = GameState()
        _ = state.refreshMilestones()
        var rng = SeededGenerator(seed: 2)
        let summary = state.applySession(record(minutes: 10), rng: &rng)
        XCTAssertTrue(summary.milestones.chapters.contains("ch2"))
        XCTAssertTrue(summary.milestones.achievements.contains("firstSpark"))
        XCTAssertTrue(state.hearthLit)
    }

    func testRenewalsAndRestoration() {
        var state = GameState()
        var rng = SeededGenerator(seed: 3)
        _ = state.applySession(record(minutes: 50), rng: &rng)
        XCTAssertEqual(state.renewalsAvailable, 1)
        let changes = state.restore("mushroomRing", variant: "crimson")
        XCTAssertEqual(state.restored["mushroomRing"], "crimson")
        XCTAssertEqual(state.renewalsAvailable, 0)
        XCTAssertTrue(changes.chapters.contains("ch3"))
        XCTAssertTrue(state.presentCompanions.contains { $0.id == "mosslings" })
        XCTAssertTrue(state.presentCompanions.contains { $0.id == "tansy" })
        // No renewal left: restoring again is refused.
        _ = state.restore("meadow", variant: "sunflowers")
        XCTAssertNil(state.restored["meadow"])
    }

    func testPathChoiceRequiresLevelEight() {
        var state = GameState()
        _ = state.choosePath(.bloom)
        XCTAssertNil(state.path)
        state.xp = Leveling.xpRequired(forLevel: 8)
        XCTAssertTrue(state.canChoosePath)
        _ = state.choosePath(.bloom)
        XCTAssertEqual(state.path, .bloom)
        XCTAssertEqual(state.stageIndex, 2)
        XCTAssertEqual(state.flameTint, "jade")
    }

    func testAreasUnlockByFocusTime() {
        var state = GameState()
        var rng = SeededGenerator(seed: 4)
        _ = state.applySession(record(minutes: 180), rng: &rng)
        XCTAssertTrue(state.unlockedAreas.contains("brook"))
        XCTAssertFalse(state.unlockedAreas.contains("oak"))
    }

    func testDailyQuestsAreStableWithinADay() {
        let state = GameState()
        let a = state.quests(.daily).map(\.template.id)
        let b = state.quests(.daily).map(\.template.id)
        XCTAssertEqual(a, b)
        XCTAssertEqual(a.count, 3)
    }

    func testGiftDuplicatesBecomeSeeds() {
        var state = GameState()
        _ = state.grant(.cosmetic("knitScarf"))
        let second = state.grant(.cosmetic("knitScarf"))
        XCTAssertEqual(second, .seeds(30))
        XCTAssertEqual(state.seeds, 30)
    }
}
