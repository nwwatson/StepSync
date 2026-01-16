import SwiftUI
import SwiftData

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(HealthKitManager.self) private var healthKitManager
    @Environment(StepCountService.self) private var stepCountService

    @State private var viewModel = DashboardViewModel()
    @State private var showingGoalSheet = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    stepProgressCard

                    statsGrid

                    streakCard

                    weeklyChartCard

                    quickStartSection
                }
                .padding()
            }
            .navigationTitle("StpnSzn")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingGoalSheet = true
                    } label: {
                        Image(systemName: "target")
                    }
                }
            }
            .refreshable {
                await viewModel.refreshData()
            }
            .sheet(isPresented: $showingGoalSheet) {
                GoalSettingsSheet()
            }
            .task {
                viewModel.configure(with: modelContext)
                await viewModel.refreshData()
            }
        }
    }

    private var stepProgressCard: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 20)

                Circle()
                    .trim(from: 0, to: viewModel.progressPercentage)
                    .stroke(
                        viewModel.isGoalAchieved ? Color.green : Color.primary,
                        style: StrokeStyle(lineWidth: 20, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(duration: 0.8), value: viewModel.progressPercentage)

                VStack(spacing: 4) {
                    Text(viewModel.formattedSteps)
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .contentTransition(.numericText())

                    Text("of \(viewModel.formattedGoal) steps")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 220, height: 220)

            Text(viewModel.progressMessage)
                .font(.headline)
                .foregroundStyle(viewModel.isGoalAchieved ? .green : .primary)

            if viewModel.isGoalAchieved {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title)
                    .foregroundStyle(.green)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }

    private var statsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            StatCard(
                title: "Distance",
                value: viewModel.formattedDistance,
                systemImage: "map"
            )

            StatCard(
                title: "Calories",
                value: viewModel.formattedCalories,
                systemImage: "flame"
            )

            StatCard(
                title: "Streak",
                value: "\(viewModel.currentStreak)",
                systemImage: "flame.fill"
            )
        }
    }

    private var streakCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Current Streak")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(viewModel.currentStreak)")
                        .font(.system(size: 36, weight: .bold, design: .rounded))

                    Text("days")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Image(systemName: viewModel.currentStreak >= 7 ? "flame.circle.fill" : "flame.fill")
                .font(.system(size: 44))
                .foregroundStyle(viewModel.currentStreak >= 7 ? .orange : .secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }

    private var weeklyChartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("This Week")
                .font(.headline)

            WeeklyStepChart(data: viewModel.weeklySteps, goal: viewModel.dailyGoal)
                .frame(height: 120)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }

    private var quickStartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Start")
                .font(.headline)

            HStack(spacing: 12) {
                QuickStartButton(
                    title: "Walk",
                    systemImage: "figure.walk",
                    color: .green
                ) {
                }

                QuickStartButton(
                    title: "Run",
                    systemImage: "figure.run",
                    color: .orange
                ) {
                }
            }
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.system(.title3, design: .rounded, weight: .semibold))

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 4, y: 1)
    }
}

struct QuickStartButton: View {
    let title: String
    let systemImage: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: systemImage)
                    .font(.title2)

                Text(title)
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(color.opacity(0.1))
            .foregroundStyle(color)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

struct WeeklyStepChart: View {
    let data: [Date: Int]
    let goal: Int

    var body: some View {
        let calendar = Calendar.current
        let today = Date()
        let weekDays = (0..<7).compactMap { calendar.date(byAdding: .day, value: -6 + $0, to: today) }
        let maxSteps = max(data.values.max() ?? goal, goal)

        HStack(alignment: .bottom, spacing: 8) {
            ForEach(weekDays, id: \.self) { date in
                let dayStart = calendar.startOfDay(for: date)
                let steps = data[dayStart] ?? 0
                let height = maxSteps > 0 ? CGFloat(steps) / CGFloat(maxSteps) : 0

                VStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(steps >= goal ? Color.green : Color.primary.opacity(0.3))
                        .frame(height: max(height * 80, 4))

                    Text(dayLabel(for: date))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func dayLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return String(formatter.string(from: date).prefix(1))
    }
}

#Preview {
    DashboardView()
        .modelContainer(for: [StepGoal.self, DailyStepRecord.self, Streak.self])
        .environment(HealthKitManager.shared)
        .environment(StepCountService())
}
