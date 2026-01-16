import SwiftUI
import SwiftData

struct AchievementsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Achievement.updatedAt, order: .reverse) private var achievements: [Achievement]
    @Query(sort: \Streak.updatedAt, order: .reverse) private var streaks: [Streak]

    @State private var selectedFilter: AchievementFilter = .all

    enum AchievementFilter: String, CaseIterable {
        case all = "All"
        case unlocked = "Unlocked"
        case inProgress = "In Progress"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    streakSection

                    filterPicker

                    achievementsGrid
                }
                .padding()
            }
            .navigationTitle("Achievements")
            .task {
                await ensureAchievementsExist()
            }
        }
    }

    private var streakSection: some View {
        let currentStreak = streaks.first

        return VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Current Streak")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(currentStreak?.currentStreak ?? 0)")
                            .font(.system(size: 48, weight: .bold, design: .rounded))

                        Text("days")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Longest")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("\(currentStreak?.longestStreak ?? 0)")
                        .font(.title2)
                        .fontWeight(.semibold)
                }
            }

            if let streak = currentStreak {
                HStack {
                    Image(systemName: streak.streakStatus.systemImage)
                        .foregroundStyle(streak.currentStreak >= 7 ? .orange : .secondary)

                    Text(streak.streakStatus.displayName)
                        .font(.subheadline)

                    Spacer()

                    if streak.isActiveToday {
                        Label("Active today", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }

    private var filterPicker: some View {
        Picker("Filter", selection: $selectedFilter) {
            ForEach(AchievementFilter.allCases, id: \.self) { filter in
                Text(filter.rawValue).tag(filter)
            }
        }
        .pickerStyle(.segmented)
    }

    private var achievementsGrid: some View {
        let filteredAchievements: [Achievement]

        switch selectedFilter {
        case .all:
            filteredAchievements = achievements
        case .unlocked:
            filteredAchievements = achievements.filter { $0.isUnlocked }
        case .inProgress:
            filteredAchievements = achievements.filter { !$0.isUnlocked && $0.currentProgress > 0 }
        }

        return LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            ForEach(filteredAchievements) { achievement in
                AchievementCard(achievement: achievement)
            }
        }
    }

    private func ensureAchievementsExist() async {
        let existingTypes = Set(achievements.map { $0.typeRaw })

        for type in AchievementType.allCases {
            if !existingTypes.contains(type.rawValue) {
                let achievement = Achievement(type: type)
                modelContext.insert(achievement)
            }
        }

        if streaks.isEmpty {
            let streak = Streak()
            modelContext.insert(streak)
        }

        try? modelContext.save()
    }
}

struct AchievementCard: View {
    let achievement: Achievement

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(achievement.isUnlocked ? Color.orange.opacity(0.2) : Color(.systemGray5))
                    .frame(width: 60, height: 60)

                Image(systemName: achievement.type.systemImage)
                    .font(.title2)
                    .foregroundStyle(achievement.isUnlocked ? .orange : .secondary)
            }

            VStack(spacing: 4) {
                Text(achievement.type.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)

                if achievement.isUnlocked {
                    if let date = achievement.unlockedDate {
                        Text(date.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    ProgressView(value: achievement.progressPercentage)
                        .tint(.orange)

                    Text("\(achievement.currentProgress)/\(achievement.type.targetValue)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 4, y: 1)
        .opacity(achievement.isUnlocked ? 1.0 : 0.7)
    }
}

#Preview {
    AchievementsView()
        .modelContainer(for: [Achievement.self, Streak.self])
}
