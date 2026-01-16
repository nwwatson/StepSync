import SwiftUI
import SwiftData

struct WorkoutListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(
        filter: #Predicate<Workout> { $0.isCompleted },
        sort: \Workout.startDate,
        order: .reverse
    ) private var workouts: [Workout]

    @State private var showingNewWorkout = false
    @State private var activeWorkout: Workout?
    @State private var isWatchWorkout = false
    @State private var navigationPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            Group {
                if workouts.isEmpty {
                    emptyState
                } else {
                    workoutList
                }
            }
            .navigationTitle("Workouts")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingNewWorkout = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingNewWorkout) {
                NewWorkoutSheet { workout, onWatch in
                    activeWorkout = workout
                    isWatchWorkout = onWatch
                    navigationPath.append("activeWorkout")
                }
            }
            .navigationDestination(for: String.self) { destination in
                if destination == "activeWorkout", let workout = activeWorkout {
                    ActiveWorkoutView(workout: workout, isWatchWorkout: isWatchWorkout)
                }
            }
            .navigationDestination(for: Workout.self) { workout in
                WorkoutDetailView(workout: workout)
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Workouts Yet", systemImage: "figure.walk")
        } description: {
            Text("Start a walking or running workout to see your activity here.")
        } actions: {
            Button("Start Workout") {
                showingNewWorkout = true
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var workoutList: some View {
        List {
            Section {
                thisWeekSummary
            }

            Section("Recent Workouts") {
                ForEach(workouts) { workout in
                    NavigationLink(value: workout) {
                        WorkoutRow(workout: workout)
                    }
                }
                .onDelete(perform: deleteWorkouts)
            }
        }
    }

    private var thisWeekSummary: some View {
        let calendar = Calendar.current
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let thisWeekWorkouts = workouts.filter { $0.startDate >= weekAgo }

        let totalDuration = thisWeekWorkouts.reduce(0) { $0 + $1.duration }
        let totalDistance = thisWeekWorkouts.reduce(0) { $0 + $1.distance }

        return VStack(spacing: 12) {
            Text("This Week")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 24) {
                VStack(spacing: 4) {
                    Text("\(thisWeekWorkouts.count)")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                    Text("Workouts")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 4) {
                    Text(formatDuration(totalDuration))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                    Text("Duration")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 4) {
                    Text(String(format: "%.1f", totalDistance / 1609.34))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                    Text("Miles")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    private func deleteWorkouts(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(workouts[index])
        }
    }
}

struct WorkoutRow: View {
    let workout: Workout

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: workout.workoutType.systemImage)
                .font(.title2)
                .foregroundStyle(workout.workoutType == .running ? .orange : .green)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(workout.workoutType.displayName)
                    .font(.headline)

                Text(workout.startDate.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(workout.formattedDuration)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(workout.formattedDistance)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    WorkoutListView()
        .modelContainer(for: Workout.self)
        .environment(WorkoutMirroringManager.shared)
        .environment(LocationManager.shared)
}
