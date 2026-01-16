import Foundation
import SwiftData

@Model
public final class DailyStepRecord {
    public var id: UUID = UUID()
    public var date: Date = Date()
    public var stepCount: Int = 0
    public var goalTarget: Int = 10000
    public var goalAchieved: Bool = false
    public var distance: Double = 0.0
    public var activeCalories: Double = 0.0
    public var averageSpeed: Double?
    public var averageStepLength: Double?
    public var createdAt: Date = Date()
    public var updatedAt: Date = Date()

    public init(
        date: Date = Date(),
        stepCount: Int = 0,
        goalTarget: Int = 10000
    ) {
        self.id = UUID()
        self.date = Calendar.current.startOfDay(for: date)
        self.stepCount = stepCount
        self.goalTarget = goalTarget
        self.goalAchieved = stepCount >= goalTarget
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    public var progressPercentage: Double {
        guard goalTarget > 0 else { return 0 }
        return min(Double(stepCount) / Double(goalTarget), 1.0)
    }

    public var remainingSteps: Int {
        max(goalTarget - stepCount, 0)
    }

    public func updateStepCount(_ newCount: Int) {
        stepCount = newCount
        goalAchieved = stepCount >= goalTarget
        updatedAt = Date()
    }

    public func updateMetrics(distance: Double? = nil, activeCalories: Double? = nil, averageSpeed: Double? = nil, averageStepLength: Double? = nil) {
        if let distance = distance { self.distance = distance }
        if let activeCalories = activeCalories { self.activeCalories = activeCalories }
        if let averageSpeed = averageSpeed { self.averageSpeed = averageSpeed }
        if let averageStepLength = averageStepLength { self.averageStepLength = averageStepLength }
        updatedAt = Date()
    }
}
