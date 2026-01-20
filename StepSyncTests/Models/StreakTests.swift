import XCTest
@testable import StepSync

final class StreakTests: XCTestCase {

    // MARK: - Initialization Tests

    func testStreakInitialization() {
        let streak = Streak()

        XCTAssertEqual(streak.currentStreak, 0)
        XCTAssertEqual(streak.longestStreak, 0)
        XCTAssertNil(streak.lastActiveDate)
        XCTAssertNil(streak.streakStartDate)
        XCTAssertEqual(streak.totalDaysActive, 0)
    }

    // MARK: - Record Activity Tests

    func testRecordActivityFirstDay() {
        let streak = Streak()

        streak.recordActivity()

        XCTAssertEqual(streak.currentStreak, 1)
        XCTAssertEqual(streak.longestStreak, 1)
        XCTAssertNotNil(streak.lastActiveDate)
        XCTAssertNotNil(streak.streakStartDate)
        XCTAssertEqual(streak.totalDaysActive, 1)
    }

    func testRecordActivityConsecutiveDays() {
        let streak = Streak()
        let calendar = Calendar.current

        // Day 1
        let day1 = calendar.startOfDay(for: Date())
        streak.recordActivity(on: day1)
        XCTAssertEqual(streak.currentStreak, 1)

        // Day 2 (next day)
        guard let day2 = calendar.date(byAdding: .day, value: 1, to: day1) else {
            XCTFail("Failed to create day2")
            return
        }
        streak.recordActivity(on: day2)
        XCTAssertEqual(streak.currentStreak, 2)

        // Day 3 (another consecutive day)
        guard let day3 = calendar.date(byAdding: .day, value: 1, to: day2) else {
            XCTFail("Failed to create day3")
            return
        }
        streak.recordActivity(on: day3)
        XCTAssertEqual(streak.currentStreak, 3)
        XCTAssertEqual(streak.longestStreak, 3)
        XCTAssertEqual(streak.totalDaysActive, 3)
    }

    func testRecordActivityMissedDayResetsStreak() {
        let streak = Streak()
        let calendar = Calendar.current

        // Day 1
        let day1 = calendar.startOfDay(for: Date())
        streak.recordActivity(on: day1)
        XCTAssertEqual(streak.currentStreak, 1)

        // Day 2 (next day)
        guard let day2 = calendar.date(byAdding: .day, value: 1, to: day1) else {
            XCTFail("Failed to create day2")
            return
        }
        streak.recordActivity(on: day2)
        XCTAssertEqual(streak.currentStreak, 2)

        // Day 4 (skipped day 3 - streak should reset)
        guard let day4 = calendar.date(byAdding: .day, value: 2, to: day2) else {
            XCTFail("Failed to create day4")
            return
        }
        streak.recordActivity(on: day4)
        XCTAssertEqual(streak.currentStreak, 1) // Reset to 1, not 3
        XCTAssertEqual(streak.longestStreak, 2) // Previous streak preserved
        XCTAssertEqual(streak.totalDaysActive, 3)
    }

    func testRecordActivitySameDayDoesNotIncrement() {
        let streak = Streak()

        // Record activity twice on same day
        streak.recordActivity()
        XCTAssertEqual(streak.currentStreak, 1)

        streak.recordActivity()
        XCTAssertEqual(streak.currentStreak, 1) // Should still be 1
        XCTAssertEqual(streak.totalDaysActive, 1) // Should still be 1
    }

    func testRecordActivityPreservesLongestStreak() {
        let streak = Streak()
        let calendar = Calendar.current

        // Build a 5-day streak
        var currentDate = calendar.startOfDay(for: Date())
        for _ in 1...5 {
            streak.recordActivity(on: currentDate)
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
        }
        XCTAssertEqual(streak.currentStreak, 5)
        XCTAssertEqual(streak.longestStreak, 5)

        // Skip a day (miss day 6)
        currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!

        // Start a new 2-day streak
        streak.recordActivity(on: currentDate)
        XCTAssertEqual(streak.currentStreak, 1) // Reset
        XCTAssertEqual(streak.longestStreak, 5) // Preserved!

        currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
        streak.recordActivity(on: currentDate)
        XCTAssertEqual(streak.currentStreak, 2)
        XCTAssertEqual(streak.longestStreak, 5) // Still preserved
    }

    // MARK: - Check and Break Streak Tests

    func testCheckAndBreakStreakWhenNoMissedDays() {
        let streak = Streak()
        let calendar = Calendar.current

        // Record activity today
        streak.recordActivity()
        XCTAssertEqual(streak.currentStreak, 1)

        // Check streak for today - should not break
        streak.checkAndBreakStreak()
        XCTAssertEqual(streak.currentStreak, 1)
    }

    func testCheckAndBreakStreakWhenDaysMissed() {
        let streak = Streak()
        let calendar = Calendar.current

        // Record activity 3 days ago
        guard let threeDaysAgo = calendar.date(byAdding: .day, value: -3, to: Date()) else {
            XCTFail("Failed to create date")
            return
        }
        streak.recordActivity(on: threeDaysAgo)
        XCTAssertEqual(streak.currentStreak, 1)

        // Check streak for today - should break (2 days missed)
        streak.checkAndBreakStreak()
        XCTAssertEqual(streak.currentStreak, 0)
        XCTAssertNil(streak.streakStartDate)
    }

    func testCheckAndBreakStreakWithNoActivity() {
        let streak = Streak()

        // No activity recorded, nothing to break
        streak.checkAndBreakStreak()
        XCTAssertEqual(streak.currentStreak, 0)
    }

    // MARK: - Is Active Today Tests

    func testIsActiveTodayWhenActiveToday() {
        let streak = Streak()

        streak.recordActivity()
        XCTAssertTrue(streak.isActiveToday)
    }

    func testIsActiveTodayWhenNotActive() {
        let streak = Streak()

        XCTAssertFalse(streak.isActiveToday)
    }

    func testIsActiveTodayWhenActiveYesterday() {
        let streak = Streak()
        let calendar = Calendar.current

        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: Date()) else {
            XCTFail("Failed to create yesterday date")
            return
        }

        streak.recordActivity(on: yesterday)
        XCTAssertFalse(streak.isActiveToday)
    }

    // MARK: - Streak Status Tests

    func testStreakStatusInactive() {
        let streak = Streak()

        XCTAssertEqual(streak.streakStatus, .inactive)
        XCTAssertEqual(streak.streakStatus.displayName, "Start your streak!")
    }

    func testStreakStatusBuilding() {
        let streak = Streak()
        let calendar = Calendar.current

        // Build a 3-day streak (less than 7)
        var currentDate = calendar.startOfDay(for: Date())
        for _ in 1...3 {
            streak.recordActivity(on: currentDate)
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
        }

        XCTAssertEqual(streak.streakStatus, .building)
        XCTAssertEqual(streak.streakStatus.displayName, "Building momentum")
    }

    func testStreakStatusStrong() {
        let streak = Streak()
        let calendar = Calendar.current

        // Build a 10-day streak (>= 7, < 30)
        var currentDate = calendar.startOfDay(for: Date())
        for _ in 1...10 {
            streak.recordActivity(on: currentDate)
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
        }

        XCTAssertEqual(streak.streakStatus, .strong)
        XCTAssertEqual(streak.streakStatus.displayName, "Strong streak")
    }

    func testStreakStatusOnFire() {
        let streak = Streak()
        let calendar = Calendar.current

        // Build a 30-day streak
        var currentDate = calendar.startOfDay(for: Date())
        for _ in 1...30 {
            streak.recordActivity(on: currentDate)
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
        }

        XCTAssertEqual(streak.streakStatus, .onFire)
        XCTAssertEqual(streak.streakStatus.displayName, "You're on fire!")
    }

    // MARK: - Edge Cases

    func testStreakUpdatesTimestamp() {
        let streak = Streak()
        let initialUpdatedAt = streak.updatedAt

        // Small delay to ensure timestamp difference
        Thread.sleep(forTimeInterval: 0.01)

        streak.recordActivity()

        XCTAssertGreaterThan(streak.updatedAt, initialUpdatedAt)
    }

    func testLongestStreakOnlyIncreasesNotDecreases() {
        let streak = Streak()
        let calendar = Calendar.current

        // Build a 5-day streak
        var currentDate = calendar.startOfDay(for: Date())
        for _ in 1...5 {
            streak.recordActivity(on: currentDate)
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
        }
        XCTAssertEqual(streak.longestStreak, 5)

        // Break the streak
        currentDate = calendar.date(byAdding: .day, value: 2, to: currentDate)!
        streak.recordActivity(on: currentDate)

        // Build a shorter 3-day streak
        for _ in 1...2 {
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
            streak.recordActivity(on: currentDate)
        }

        XCTAssertEqual(streak.currentStreak, 3)
        XCTAssertEqual(streak.longestStreak, 5) // Still 5, not 3
    }
}
