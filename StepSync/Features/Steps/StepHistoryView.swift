import SwiftUI
import SwiftData

struct StepHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DailyStepRecord.date, order: .reverse) private var records: [DailyStepRecord]

    @State private var selectedPeriod: Period = .week

    enum Period: String, CaseIterable {
        case week = "Week"
        case month = "Month"
        case year = "Year"
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Period", selection: $selectedPeriod) {
                        ForEach(Period.allCases, id: \.self) { period in
                            Text(period.rawValue).tag(period)
                        }
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }

                Section {
                    SummaryCard(records: filteredRecords)
                }

                Section("History") {
                    ForEach(filteredRecords) { record in
                        StepHistoryRow(record: record)
                    }
                }
            }
            .navigationTitle("Step History")
        }
    }

    private var filteredRecords: [DailyStepRecord] {
        let calendar = Calendar.current
        let now = Date()

        let startDate: Date
        switch selectedPeriod {
        case .week:
            startDate = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        case .month:
            startDate = calendar.date(byAdding: .month, value: -1, to: now) ?? now
        case .year:
            startDate = calendar.date(byAdding: .year, value: -1, to: now) ?? now
        }

        return records.filter { $0.date >= startDate }
    }
}

struct SummaryCard: View {
    let records: [DailyStepRecord]

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 24) {
                SummaryItem(
                    title: "Total",
                    value: totalSteps.formatted(),
                    systemImage: "shoeprints.fill"
                )

                SummaryItem(
                    title: "Average",
                    value: averageSteps.formatted(),
                    systemImage: "chart.bar"
                )

                SummaryItem(
                    title: "Best",
                    value: bestDay.formatted(),
                    systemImage: "star.fill"
                )
            }

            Divider()

            HStack {
                Label("\(goalsAchieved) goals achieved", systemImage: "target")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                Text("\(Int(achievementRate * 100))% success rate")
                    .font(.subheadline)
                    .foregroundStyle(achievementRate >= 0.7 ? .green : .secondary)
            }
        }
        .padding()
    }

    private var totalSteps: Int {
        records.reduce(0) { $0 + $1.stepCount }
    }

    private var averageSteps: Int {
        guard !records.isEmpty else { return 0 }
        return totalSteps / records.count
    }

    private var bestDay: Int {
        records.max(by: { $0.stepCount < $1.stepCount })?.stepCount ?? 0
    }

    private var goalsAchieved: Int {
        records.filter { $0.goalAchieved }.count
    }

    private var achievementRate: Double {
        guard !records.isEmpty else { return 0 }
        return Double(goalsAchieved) / Double(records.count)
    }
}

struct SummaryItem: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.system(.headline, design: .rounded))

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct StepHistoryRow: View {
    let record: DailyStepRecord

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(record.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.headline)

                Text("\(record.stepCount.formatted()) steps")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                if record.goalAchieved {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    Text("\(Int(record.progressPercentage * 100))%")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                ProgressView(value: record.progressPercentage)
                    .frame(width: 60)
                    .tint(record.goalAchieved ? .green : .primary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    StepHistoryView()
        .modelContainer(for: DailyStepRecord.self)
}
