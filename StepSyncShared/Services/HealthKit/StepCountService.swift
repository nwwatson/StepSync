import Foundation
import SwiftData
import HealthKit
import Observation

@Observable
@MainActor
public final class StepCountService: @unchecked Sendable {
    private let healthKitManager: HealthKitManager
    private var modelContext: ModelContext?
    private var observerQuery: HKObserverQuery?
    private var isObserving = false

    public private(set) var todayStepCount: Int = 0
    public private(set) var todayDistance: Double = 0
    public private(set) var todayCalories: Double = 0
    public private(set) var isLoading = false
    public private(set) var lastError: Error?
    public private(set) var isAuthorized = false

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
        } catch {
            await MainActor.run {
                lastError = error
                isLoading = false
            }
        }
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
