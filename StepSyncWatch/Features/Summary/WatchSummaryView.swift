import SwiftUI
import SwiftData

struct WatchSummaryView: View {
    @Query(
        filter: #Predicate<Workout> { $0.isCompleted },
        sort: \Workout.startDate,
        order: .reverse
    ) private var workouts: [Workout]

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                if let lastWorkout = workouts.first {
                    lastWorkoutCard(lastWorkout)
                }

                weekSummary
            }
            .padding()
        }
        .navigationTitle("Summary")
    }

    private func lastWorkoutCard(_ workout: Workout) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: workout.workoutType.systemImage)
                    .foregroundStyle(workout.workoutType == .running ? .orange : .green)

                Text("Last Workout")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(workout.formattedDuration)
                .font(.title2)
                .fontWeight(.bold)

            HStack(spacing: 16) {
                VStack(alignment: .leading) {
                    Text(workout.formattedDistance)
                        .font(.caption)
                        .fontWeight(.medium)
                    Text("Distance")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading) {
                    Text("\(workout.stepCount)")
                        .font(.caption)
                        .fontWeight(.medium)
                    Text("Steps")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Text(workout.startDate.formatted(date: .abbreviated, time: .shortened))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.darkGray).opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var weekSummary: some View {
        let calendar = Calendar.current
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let thisWeekWorkouts = workouts.filter { $0.startDate >= weekAgo }

        let totalDuration = thisWeekWorkouts.reduce(0) { $0 + $1.duration }
        let totalDistance = thisWeekWorkouts.reduce(0) { $0 + $1.distance }

        return VStack(alignment: .leading, spacing: 8) {
            Text("This Week")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 20) {
                VStack(alignment: .leading) {
                    Text("\(thisWeekWorkouts.count)")
                        .font(.title3)
                        .fontWeight(.bold)
                    Text("Workouts")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading) {
                    Text(formatDuration(totalDuration))
                        .font(.title3)
                        .fontWeight(.bold)
                    Text("Time")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.darkGray).opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}

#Preview {
    WatchSummaryView()
        .modelContainer(for: Workout.self)
}
