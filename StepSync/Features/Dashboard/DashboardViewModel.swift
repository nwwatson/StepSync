import Foundation
import SwiftData
import Observation

@Observable
@MainActor
final class DashboardViewModel {
    private var modelContext: ModelContext?
    private let healthKitManager: HealthKitManager
    private let stepCountService: StepCountService

    var todaySteps: Int = 0
    var dailyGoal: Int = 10000
    var todayDistance: Double = 0
    var todayCalories: Double = 0
    var currentStreak: Int = 0
    var weeklySteps: [Date: Int] = [:]
    var isLoading = false
    var showGoalAchievedAnimation = false

    init(healthKitManager: HealthKitManager = .shared, stepCountService: StepCountService = StepCountService()) {
        self.healthKitManager = healthKitManager
        self.stepCountService = stepCountService
    }

    func configure(with modelContext: ModelContext) {
        self.modelContext = modelContext
        stepCountService.configure(with: modelContext)
    }

    var progressPercentage: Double {
        guard dailyGoal > 0 else { return 0 }
        return min(Double(todaySteps) / Double(dailyGoal), 1.0)
    }

    var remainingSteps: Int {
        max(dailyGoal - todaySteps, 0)
    }

    var isGoalAchieved: Bool {
        todaySteps >= dailyGoal
    }

    var formattedSteps: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: todaySteps)) ?? "\(todaySteps)"
    }

    var formattedGoal: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: dailyGoal)) ?? "\(dailyGoal)"
    }

    var formattedDistance: String {
        let distanceInMiles = todayDistance / 1609.34
        return String(format: "%.2f mi", distanceInMiles)
    }

    var formattedCalories: String {
        return String(format: "%.0f", todayCalories)
    }

    var progressMessage: String {
        if isGoalAchieved {
            return "Goal achieved!"
        } else {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            let remaining = formatter.string(from: NSNumber(value: remainingSteps)) ?? "\(remainingSteps)"
            return "\(remaining) steps to go"
        }
    }

    @MainActor
    func refreshData() async {
        isLoading = true

        await stepCountService.refreshTodayData()
        todaySteps = stepCountService.todayStepCount
        todayDistance = stepCountService.todayDistance
        todayCalories = stepCountService.todayCalories

        await loadGoal()
        await loadStreak()
        await loadWeeklySteps()

        checkGoalAchievement()

        isLoading = false
    }

    @MainActor
    private func loadGoal() async {
        guard let modelContext = modelContext else { return }

        let descriptor = FetchDescriptor<StepGoal>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )

        do {
            let goals = try modelContext.fetch(descriptor)
            if let currentGoal = goals.first {
                dailyGoal = currentGoal.dailyTarget
            } else {
                let suggestedGoal = try? await healthKitManager.suggestInitialStepGoal()
                let newGoal = StepGoal(dailyTarget: suggestedGoal ?? 10000)
                modelContext.insert(newGoal)
                try? modelContext.save()
                dailyGoal = newGoal.dailyTarget
            }
        } catch {
            print("Failed to load goal: \(error)")
        }
    }

    @MainActor
    private func loadStreak() async {
        guard let modelContext = modelContext else { return }

        let descriptor = FetchDescriptor<Streak>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )

        do {
            let streaks = try modelContext.fetch(descriptor)
            if let streak = streaks.first {
                currentStreak = streak.currentStreak
            } else {
                let newStreak = Streak()
                modelContext.insert(newStreak)
                try? modelContext.save()
                currentStreak = 0
            }
        } catch {
            print("Failed to load streak: \(error)")
        }
    }

    @MainActor
    private func loadWeeklySteps() async {
        weeklySteps = await stepCountService.getWeeklySteps()
    }

    private func checkGoalAchievement() {
        if isGoalAchieved && !showGoalAchievedAnimation {
            showGoalAchievedAnimation = true
        }
    }

    func dismissGoalAnimation() {
        showGoalAchievedAnimation = false
    }
}
