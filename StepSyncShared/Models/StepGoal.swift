import Foundation
import SwiftData

@Model
public final class StepGoal {
    public var id: UUID = UUID()
    public var dailyTarget: Int = 10000
    public var progressionLevel: Int = 1
    public var consecutiveDaysAchieved: Int = 0
    public var lastAchievedDate: Date?
    public var createdAt: Date = Date()
    public var updatedAt: Date = Date()

    public init(
        dailyTarget: Int = 10000,
        progressionLevel: Int = 1,
        consecutiveDaysAchieved: Int = 0
    ) {
        self.id = UUID()
        self.dailyTarget = dailyTarget
        self.progressionLevel = progressionLevel
        self.consecutiveDaysAchieved = consecutiveDaysAchieved
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    public static let minimumGoal: Int = 3000
    public static let maximumGoal: Int = 25000
    public static let progressionThreshold: Int = 5
    public static let progressionMultiplier: Double = 1.10

    public func checkAndProgressGoal() -> Bool {
        guard consecutiveDaysAchieved >= Self.progressionThreshold else {
            return false
        }

        let newTarget = Int(Double(dailyTarget) * Self.progressionMultiplier)
        let roundedTarget = (newTarget / 500) * 500

        if roundedTarget <= Self.maximumGoal {
            dailyTarget = roundedTarget
            progressionLevel += 1
            consecutiveDaysAchieved = 0
            updatedAt = Date()
            return true
        }

        return false
    }

    public func recordGoalAchieved(on date: Date = Date()) {
        let calendar = Calendar.current

        if let lastDate = lastAchievedDate {
            let daysBetween = calendar.dateComponents([.day], from: lastDate, to: date).day ?? 0
            if daysBetween == 1 {
                consecutiveDaysAchieved += 1
            } else if daysBetween > 1 {
                consecutiveDaysAchieved = 1
            }
        } else {
            consecutiveDaysAchieved = 1
        }

        lastAchievedDate = date
        updatedAt = Date()
    }

    public func resetStreak() {
        consecutiveDaysAchieved = 0
        updatedAt = Date()
    }
}
