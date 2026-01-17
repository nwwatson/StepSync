import Foundation
import SwiftData
import HealthKit
import Observation
import WidgetKit

@Observable
@MainActor
public final class StepCountService: @unchecked Sendable {
    private let healthKitManager: HealthKitManager
    private var modelContext: ModelContext?
    private var observerQuery: HKObserverQuery?
    private var isObserving = false
    private let appGroupID = "group.com.nwwsolutions.steppingszn"

    public private(set) var todayStepCount: Int = 0
    public private(set) var todayDistance: Double = 0
    public private(set) var todayCalories: Double = 0
    public private(set) var dailyGoal: Int = 10000
    public private(set) var currentStreak: Int = 0
    public private(set) var isLoading = false
    public private(set) var lastError: Error?
    public private(set) var isAuthorized = false

    /// Shared UserDefaults for widget communication
    private var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    public init(healthKitManager: HealthKitManager = .shared) {
        self.healthKitManager = healthKitManager
    }

    public func configure(with modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    /// Starts observing step count changes in real-time
    public func startObservingSteps() {
        guard !isObserving else { return }

        observerQuery = healthKitManager.observeStepCount { [weak self] steps in
            guard let self = self else { return }
            Task { @MainActor [self] in
                self.todayStepCount = steps
                await self.refreshTodayData()
            }
        }

        if observerQuery != nil {
            isObserving = true
            print("StepCountService: Started observing step count changes")
        }
    }

    /// Stops observing step count changes
    public func stopObservingSteps() {
        if let query = observerQuery {
            healthKitManager.stopObserving(query: query)
            observerQuery = nil
            isObserving = false
            print("StepCountService: Stopped observing step count changes")
        }
    }

    public func refreshTodayData() async {
        isLoading = true
        lastError = nil

        do {
            async let steps = healthKitManager.getStepCount(for: Date())
            async let distance = healthKitManager.getDistance(for: Date())
            async let calories = healthKitManager.getActiveCalories(for: Date())

            let (stepsResult, distanceResult, caloriesResult) = try await (steps, distance, calories)

            await MainActor.run {
                todayStepCount = stepsResult
                todayDistance = distanceResult
                todayCalories = caloriesResult
                isLoading = false
            }

            await updateDailyRecord()
            await fetchGoalAndStreak()
            syncToWidgets()
        } catch {
            await MainActor.run {
                lastError = error
                isLoading = false
            }
        }
    }

    /// Fetches the current daily goal and streak from SwiftData
    private func fetchGoalAndStreak() async {
        guard let modelContext = modelContext else { return }

        // Fetch current goal
        let goalDescriptor = FetchDescriptor<StepGoal>(
            sortBy: [SortDescriptor(\StepGoal.createdAt, order: .reverse)]
        )

        do {
            let goals = try modelContext.fetch(goalDescriptor)
            if let currentGoal = goals.first {
                await MainActor.run {
                    self.dailyGoal = currentGoal.dailyTarget
                }
            }
        } catch {
            print("StepCountService: Failed to fetch goal: \(error)")
        }

        // Fetch current streak
        let streakDescriptor = FetchDescriptor<Streak>(
            sortBy: [SortDescriptor(\Streak.updatedAt, order: .reverse)]
        )

        do {
            let streaks = try modelContext.fetch(streakDescriptor)
            if let streak = streaks.first {
                await MainActor.run {
                    self.currentStreak = streak.currentStreak
                }
            } else {
                await MainActor.run {
                    self.currentStreak = 0
                }
            }
        } catch {
            print("StepCountService: Failed to fetch streak: \(error)")
        }
    }

    /// Syncs current data to shared UserDefaults for widgets
    public func syncToWidgets() {
        sharedDefaults?.set(todayStepCount, forKey: "todayStepCount")
        sharedDefaults?.set(dailyGoal, forKey: "dailyGoal")
        sharedDefaults?.set(currentStreak, forKey: "currentStreak")
        sharedDefaults?.synchronize()

        // Request widget timeline reload
        WidgetCenter.shared.reloadAllTimelines()

        print("StepCountService: Synced to widgets - steps: \(todayStepCount), goal: \(dailyGoal), streak: \(currentStreak)")
    }

    private func updateDailyRecord() async {
        guard let modelContext = modelContext else { return }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        let descriptor = FetchDescriptor<DailyStepRecord>(
            predicate: #Predicate { record in
                record.date == today
            }
        )

        do {
            let records = try modelContext.fetch(descriptor)

            if let existingRecord = records.first {
                existingRecord.updateStepCount(todayStepCount)
                existingRecord.updateMetrics(
                    distance: todayDistance,
                    activeCalories: todayCalories
                )
            } else {
                let goalDescriptor = FetchDescriptor<StepGoal>(
                    sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
                )
                let goals = try modelContext.fetch(goalDescriptor)
                let currentGoal = goals.first?.dailyTarget ?? 10000

                let newRecord = DailyStepRecord(
                    date: today,
                    stepCount: todayStepCount,
                    goalTarget: currentGoal
                )
                newRecord.updateMetrics(
                    distance: todayDistance,
                    activeCalories: todayCalories
                )
                modelContext.insert(newRecord)
            }

            try modelContext.save()
        } catch {
            print("Failed to update daily record: \(error)")
        }
    }

    public func getWeeklySteps() async -> [Date: Int] {
        let calendar = Calendar.current
        let today = Date()
        guard let weekAgo = calendar.date(byAdding: .day, value: -7, to: today) else {
            return [:]
        }

        do {
            return try await healthKitManager.getStepCounts(from: weekAgo, to: today)
        } catch {
            lastError = error
            return [:]
        }
    }

    public func getMonthlySteps() async -> [Date: Int] {
        let calendar = Calendar.current
        let today = Date()
        guard let monthAgo = calendar.date(byAdding: .day, value: -30, to: today) else {
            return [:]
        }

        do {
            return try await healthKitManager.getStepCounts(from: monthAgo, to: today)
        } catch {
            lastError = error
            return [:]
        }
    }

    public var formattedStepCount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: todayStepCount)) ?? "\(todayStepCount)"
    }

    public var formattedDistance: String {
        let distanceInMiles = todayDistance / 1609.34
        return String(format: "%.2f mi", distanceInMiles)
    }

    public var formattedCalories: String {
        return String(format: "%.0f cal", todayCalories)
    }
}
