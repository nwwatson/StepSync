import Foundation

public struct DailyInsight {
    public let date: Date
    public let stepCount: Int
    public let goalTarget: Int
    public let goalAchieved: Bool
    public let distance: Double
    public let calories: Double

    public var progressPercentage: Double {
        guard goalTarget > 0 else { return 0 }
        return min(Double(stepCount) / Double(goalTarget), 1.0)
    }

    public init(
        date: Date,
        stepCount: Int,
        goalTarget: Int,
        goalAchieved: Bool,
        distance: Double,
        calories: Double
    ) {
        self.date = date
        self.stepCount = stepCount
        self.goalTarget = goalTarget
        self.goalAchieved = goalAchieved
        self.distance = distance
        self.calories = calories
    }
}

public struct WeeklyInsight {
    public let weekStartDate: Date
    public let totalSteps: Int
    public let averageSteps: Int
    public let daysWithGoalAchieved: Int
    public let totalDistance: Double
    public let totalCalories: Double
    public let dailyInsights: [DailyInsight]

    public var goalAchievementRate: Double {
        guard dailyInsights.count > 0 else { return 0 }
        return Double(daysWithGoalAchieved) / Double(dailyInsights.count)
    }

    public init(
        weekStartDate: Date,
        totalSteps: Int,
        averageSteps: Int,
        daysWithGoalAchieved: Int,
        totalDistance: Double,
        totalCalories: Double,
        dailyInsights: [DailyInsight]
    ) {
        self.weekStartDate = weekStartDate
        self.totalSteps = totalSteps
        self.averageSteps = averageSteps
        self.daysWithGoalAchieved = daysWithGoalAchieved
        self.totalDistance = totalDistance
        self.totalCalories = totalCalories
        self.dailyInsights = dailyInsights
    }
}

public struct MonthlyInsight {
    public let monthStartDate: Date
    public let totalSteps: Int
    public let averageSteps: Int
    public let daysWithGoalAchieved: Int
    public let totalDistance: Double
    public let totalCalories: Double
    public let weeklyInsights: [WeeklyInsight]

    public var goalAchievementRate: Double {
        let totalDays = weeklyInsights.reduce(0) { $0 + $1.dailyInsights.count }
        guard totalDays > 0 else { return 0 }
        return Double(daysWithGoalAchieved) / Double(totalDays)
    }

    public init(
        monthStartDate: Date,
        totalSteps: Int,
        averageSteps: Int,
        daysWithGoalAchieved: Int,
        totalDistance: Double,
        totalCalories: Double,
        weeklyInsights: [WeeklyInsight]
    ) {
        self.monthStartDate = monthStartDate
        self.totalSteps = totalSteps
        self.averageSteps = averageSteps
        self.daysWithGoalAchieved = daysWithGoalAchieved
        self.totalDistance = totalDistance
        self.totalCalories = totalCalories
        self.weeklyInsights = weeklyInsights
    }
}

public final class InsightsCalculator: Sendable {
    public static let shared = InsightsCalculator()

    private init() {}

    public func calculateDailyInsight(from record: DailyStepRecord) -> DailyInsight {
        DailyInsight(
            date: record.date,
            stepCount: record.stepCount,
            goalTarget: record.goalTarget,
            goalAchieved: record.goalAchieved,
            distance: record.distance,
            calories: record.activeCalories
        )
    }

    public func calculateWeeklyInsight(from records: [DailyStepRecord], weekStartDate: Date) -> WeeklyInsight {
        let dailyInsights = records.map { calculateDailyInsight(from: $0) }
        let totalSteps = records.reduce(0) { $0 + $1.stepCount }
        let averageSteps = records.isEmpty ? 0 : totalSteps / records.count
        let daysWithGoalAchieved = records.filter { $0.goalAchieved }.count
        let totalDistance = records.reduce(0.0) { $0 + $1.distance }
        let totalCalories = records.reduce(0.0) { $0 + $1.activeCalories }

        return WeeklyInsight(
            weekStartDate: weekStartDate,
            totalSteps: totalSteps,
            averageSteps: averageSteps,
            daysWithGoalAchieved: daysWithGoalAchieved,
            totalDistance: totalDistance,
            totalCalories: totalCalories,
            dailyInsights: dailyInsights
        )
    }

    public func calculateMonthlyInsight(from records: [DailyStepRecord], monthStartDate: Date) -> MonthlyInsight {
        let calendar = Calendar.current

        var weeklyRecords: [[DailyStepRecord]] = []
        var currentWeekRecords: [DailyStepRecord] = []
        var currentWeekStart = monthStartDate

        for record in records.sorted(by: { $0.date < $1.date }) {
            let weekOfRecord = calendar.component(.weekOfYear, from: record.date)
            let weekOfStart = calendar.component(.weekOfYear, from: currentWeekStart)

            if weekOfRecord != weekOfStart && !currentWeekRecords.isEmpty {
                weeklyRecords.append(currentWeekRecords)
                currentWeekRecords = []
                currentWeekStart = record.date
            }
            currentWeekRecords.append(record)
        }
        if !currentWeekRecords.isEmpty {
            weeklyRecords.append(currentWeekRecords)
        }

        var weekStartDate = monthStartDate
        let weeklyInsights = weeklyRecords.map { weekRecords -> WeeklyInsight in
            let insight = calculateWeeklyInsight(from: weekRecords, weekStartDate: weekStartDate)
            weekStartDate = calendar.date(byAdding: .weekOfYear, value: 1, to: weekStartDate) ?? weekStartDate
            return insight
        }

        let totalSteps = records.reduce(0) { $0 + $1.stepCount }
        let averageSteps = records.isEmpty ? 0 : totalSteps / records.count
        let daysWithGoalAchieved = records.filter { $0.goalAchieved }.count
        let totalDistance = records.reduce(0.0) { $0 + $1.distance }
        let totalCalories = records.reduce(0.0) { $0 + $1.activeCalories }

        return MonthlyInsight(
            monthStartDate: monthStartDate,
            totalSteps: totalSteps,
            averageSteps: averageSteps,
            daysWithGoalAchieved: daysWithGoalAchieved,
            totalDistance: totalDistance,
            totalCalories: totalCalories,
            weeklyInsights: weeklyInsights
        )
    }

    public func findBestDay(from records: [DailyStepRecord]) -> DailyStepRecord? {
        records.max(by: { $0.stepCount < $1.stepCount })
    }

    public func findAverageSteps(from records: [DailyStepRecord]) -> Int {
        guard !records.isEmpty else { return 0 }
        let total = records.reduce(0) { $0 + $1.stepCount }
        return total / records.count
    }

    public func calculateTrend(from records: [DailyStepRecord]) -> TrendDirection {
        guard records.count >= 7 else { return .neutral }

        let sortedRecords = records.sorted(by: { $0.date < $1.date })
        let halfIndex = sortedRecords.count / 2

        let firstHalf = Array(sortedRecords.prefix(halfIndex))
        let secondHalf = Array(sortedRecords.suffix(sortedRecords.count - halfIndex))

        let firstAverage = findAverageSteps(from: firstHalf)
        let secondAverage = findAverageSteps(from: secondHalf)

        let percentChange = Double(secondAverage - firstAverage) / Double(max(firstAverage, 1)) * 100

        if percentChange > 10 {
            return .up
        } else if percentChange < -10 {
            return .down
        } else {
            return .neutral
        }
    }
}

public enum TrendDirection {
    case up
    case down
    case neutral

    public var displayName: String {
        switch self {
        case .up: return "Improving"
        case .down: return "Declining"
        case .neutral: return "Stable"
        }
    }

    public var systemImage: String {
        switch self {
        case .up: return "arrow.up.right"
        case .down: return "arrow.down.right"
        case .neutral: return "arrow.right"
        }
    }
}
