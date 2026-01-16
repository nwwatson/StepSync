import SwiftUI
import SwiftData
import Charts

struct InsightsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DailyStepRecord.date, order: .reverse) private var records: [DailyStepRecord]
    @Query(sort: \Workout.startDate, order: .reverse) private var workouts: [Workout]

    @State private var selectedTab: InsightTab = .steps

    enum InsightTab: String, CaseIterable {
        case steps = "Steps"
        case workouts = "Workouts"
        case trends = "Trends"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Picker("Category", selection: $selectedTab) {
                        ForEach(InsightTab.allCases, id: \.self) { tab in
                            Text(tab.rawValue).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    switch selectedTab {
                    case .steps:
                        stepsInsights
                    case .workouts:
                        workoutInsights
                    case .trends:
                        trendsInsights
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Insights")
        }
    }

    private var stepsInsights: some View {
        VStack(spacing: 20) {
            weeklyStepChart

            monthlyOverview

            weekdayPattern
        }
        .padding(.horizontal)
    }

    private var weeklyStepChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Weekly Steps")
                .font(.headline)

            let weekRecords = getRecordsForPeriod(days: 7)

            Chart(weekRecords, id: \.date) { record in
                BarMark(
                    x: .value("Day", record.date, unit: .day),
                    y: .value("Steps", record.stepCount)
                )
                .foregroundStyle(record.goalAchieved ? Color.green : Color.primary.opacity(0.5))
            }
            .frame(height: 200)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { value in
                    AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }

    private var monthlyOverview: some View {
        let monthRecords = getRecordsForPeriod(days: 30)
        let totalSteps = monthRecords.reduce(0) { $0 + $1.stepCount }
        let averageSteps = monthRecords.isEmpty ? 0 : totalSteps / monthRecords.count
        let goalsAchieved = monthRecords.filter { $0.goalAchieved }.count

        return VStack(alignment: .leading, spacing: 12) {
            Text("30-Day Overview")
                .font(.headline)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                InsightStatCard(
                    title: "Total Steps",
                    value: totalSteps.formatted()
                )

                InsightStatCard(
                    title: "Daily Average",
                    value: averageSteps.formatted()
                )

                InsightStatCard(
                    title: "Goals Met",
                    value: "\(goalsAchieved)/\(monthRecords.count)"
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }

    private var weekdayPattern: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Weekday Pattern")
                .font(.headline)

            let pattern = TrendAnalyzer.shared.analyzeWeekdayPattern(from: Array(records.prefix(90)))
            let weekdays = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

            Chart {
                ForEach(1...7, id: \.self) { day in
                    BarMark(
                        x: .value("Day", weekdays[day - 1]),
                        y: .value("Average", pattern[day] ?? 0)
                    )
                    .foregroundStyle(Color.primary.opacity(0.6))
                }
            }
            .frame(height: 150)
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }

    private var workoutInsights: some View {
        VStack(spacing: 20) {
            workoutSummary

            if !workouts.isEmpty {
                paceZoneDistribution

                workoutTimePattern
            }
        }
        .padding(.horizontal)
    }

    private var workoutSummary: some View {
        let monthWorkouts = getWorkoutsForPeriod(days: 30)
        let totalDuration = monthWorkouts.reduce(0) { $0 + $1.duration }
        let totalDistance = monthWorkouts.reduce(0) { $0 + $1.distance }

        return VStack(alignment: .leading, spacing: 12) {
            Text("30-Day Summary")
                .font(.headline)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                InsightStatCard(
                    title: "Workouts",
                    value: "\(monthWorkouts.count)"
                )

                InsightStatCard(
                    title: "Total Time",
                    value: formatDuration(totalDuration)
                )

                InsightStatCard(
                    title: "Distance",
                    value: String(format: "%.1f mi", totalDistance / 1609.34)
                )

                InsightStatCard(
                    title: "Calories",
                    value: String(format: "%.0f", monthWorkouts.reduce(0) { $0 + $1.activeCalories })
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }

    private var paceZoneDistribution: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Pace Zones")
                .font(.headline)

            let distribution = TrendAnalyzer.shared.analyzePaceDistribution(from: Array(workouts))

            ForEach(PaceZone.zones, id: \.name) { zone in
                let count = distribution[zone] ?? 0
                HStack {
                    Text(zone.name)
                        .font(.subheadline)

                    Spacer()

                    Text("\(count)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }

    private var workoutTimePattern: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Preferred Workout Time")
                .font(.headline)

            let pattern = TrendAnalyzer.shared.analyzeHourlyPattern(from: Array(workouts))
            let peakHour = pattern.max(by: { $0.value < $1.value })?.key ?? 12

            HStack {
                Image(systemName: peakHour < 12 ? "sunrise" : (peakHour < 18 ? "sun.max" : "moon.stars"))
                    .font(.title2)

                VStack(alignment: .leading) {
                    Text("Most Active Time")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text(formatHour(peakHour))
                        .font(.headline)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }

    private var trendsInsights: some View {
        VStack(spacing: 20) {
            trendCard

            personalRecords

            if let strideAnalysis = TrendAnalyzer.shared.calculateStrideAnalysis(from: Array(workouts)) {
                strideAnalysisCard(strideAnalysis)
            }
        }
        .padding(.horizontal)
    }

    private var trendCard: some View {
        let trend = InsightsCalculator.shared.calculateTrend(from: Array(records.prefix(30)))

        return VStack(alignment: .leading, spacing: 12) {
            Text("Step Trend")
                .font(.headline)

            HStack {
                Image(systemName: trend.systemImage)
                    .font(.title)
                    .foregroundStyle(trend == .up ? .green : (trend == .down ? .red : .secondary))

                VStack(alignment: .leading) {
                    Text(trend.displayName)
                        .font(.headline)

                    Text("Based on last 30 days")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }

    private var personalRecords: some View {
        let prs = TrendAnalyzer.shared.findPersonalRecords(from: Array(records), workouts: Array(workouts))

        return VStack(alignment: .leading, spacing: 12) {
            Text("Personal Records")
                .font(.headline)

            ForEach(prs.prefix(4), id: \.type.rawValue) { record in
                HStack {
                    Image(systemName: record.type.systemImage)
                        .foregroundStyle(.orange)
                        .frame(width: 24)

                    VStack(alignment: .leading) {
                        Text(record.type.displayName)
                            .font(.subheadline)

                        Text(record.date.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text(formatRecordValue(record))
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }

    private func strideAnalysisCard(_ analysis: StrideAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Stride Analysis")
                .font(.headline)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                VStack(alignment: .leading) {
                    Text("Average")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(analysis.formattedAverage)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }

                VStack(alignment: .leading) {
                    Text("Consistency")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(analysis.consistencyRating)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }

    private func getRecordsForPeriod(days: Int) -> [DailyStepRecord] {
        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        return records.filter { $0.date >= startDate }
    }

    private func getWorkoutsForPeriod(days: Int) -> [Workout] {
        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        return workouts.filter { $0.startDate >= startDate && $0.isCompleted }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    private func formatHour(_ hour: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h a"
        let date = Calendar.current.date(from: DateComponents(hour: hour)) ?? Date()
        return formatter.string(from: date)
    }

    private func formatRecordValue(_ record: PersonalRecord) -> String {
        switch record.type {
        case .mostStepsInDay:
            return Int(record.value).formatted()
        case .longestDistance:
            return String(format: "%.2f mi", record.value / 1609.34)
        case .fastestPace:
            let minutes = Int(record.value) / 60
            let seconds = Int(record.value) % 60
            return String(format: "%d:%02d/mi", minutes, seconds)
        case .longestWorkout:
            return formatDuration(record.value)
        case .highestElevationGain:
            return String(format: "%.0f m", record.value)
        case .mostCaloriesBurned:
            return String(format: "%.0f cal", record.value)
        }
    }
}

struct InsightStatCard: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(.headline, design: .rounded))

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

#Preview {
    InsightsView()
        .modelContainer(for: [DailyStepRecord.self, Workout.self])
}
