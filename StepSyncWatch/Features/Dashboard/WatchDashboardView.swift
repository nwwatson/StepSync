import SwiftUI
import SwiftData

struct WatchDashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(StepCountService.self) private var stepCountService
    @Environment(HealthKitManager.self) private var healthKitManager
    @Query(sort: \StepGoal.createdAt, order: .reverse) private var goals: [StepGoal]
    @Query(sort: \Streak.createdAt, order: .reverse) private var streaks: [Streak]

    @State private var isRefreshing = false

    private var currentGoal: Int {
        goals.first?.dailyTarget ?? 10000
    }

    private var progressPercentage: Double {
        guard currentGoal > 0 else { return 0 }
        return min(Double(stepCountService.todayStepCount) / Double(currentGoal), 1.0)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if stepCountService.isLoading {
                    ProgressView()
                        .frame(height: 120)
                } else {
                    stepProgressRing
                }

                statsRow

                streakBadge

                if let error = stepCountService.lastError {
                    Text("Error: \(error.localizedDescription)")
                        .font(.caption2)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }
            }
            .padding()
        }
        .navigationTitle("StpnSzn")
        .task {
            // Refresh data when view appears
            await stepCountService.refreshTodayData()
        }
        .refreshable {
            await stepCountService.refreshTodayData()
        }
    }

    private var stepProgressRing: some View {
        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.3), lineWidth: 12)

            Circle()
                .trim(from: 0, to: progressPercentage)
                .stroke(
                    progressPercentage >= 1.0 ? Color.green : Color.primary,
                    style: StrokeStyle(lineWidth: 12, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.spring(duration: 0.5), value: progressPercentage)

            VStack(spacing: 2) {
                Text(stepCountService.formattedStepCount)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.5)

                Text("of \(currentGoal.formatted())")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(height: 120)
    }

    private var statsRow: some View {
        HStack(spacing: 16) {
            VStack(spacing: 2) {
                Image(systemName: "map")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(stepCountService.formattedDistance)
                    .font(.caption2)
                    .fontWeight(.medium)
            }

            VStack(spacing: 2) {
                Image(systemName: "flame")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(stepCountService.formattedCalories)
                    .font(.caption2)
                    .fontWeight(.medium)
            }
        }
    }

    private var streakBadge: some View {
        let currentStreak = streaks.first?.currentStreak ?? 0

        return HStack(spacing: 4) {
            Image(systemName: currentStreak >= 7 ? "flame.circle.fill" : "flame.fill")
                .foregroundStyle(currentStreak >= 7 ? .orange : .secondary)

            Text("\(currentStreak) day streak")
                .font(.caption)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(.darkGray).opacity(0.3))
        .clipShape(Capsule())
    }
}

#Preview {
    WatchDashboardView()
        .modelContainer(for: [StepGoal.self, Streak.self])
        .environment(StepCountService())
        .environment(HealthKitManager.shared)
}
