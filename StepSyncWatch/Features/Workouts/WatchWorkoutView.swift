import SwiftUI
import SwiftData
import WatchKit

struct WatchWorkoutView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(WorkoutSessionManager.self) private var sessionManager

    @State private var selectedType: WorkoutType = .walking
    @State private var selectedEnvironment: WorkoutEnvironment = .outdoor
    @State private var currentWorkout: Workout?
    @State private var isStarting = false

    var body: some View {
        Group {
            if sessionManager.isSessionActive {
                ActiveWatchWorkoutView(currentWorkout: $currentWorkout)
            } else {
                workoutStartView
            }
        }
    }

    private var workoutStartView: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("Start Workout")
                    .font(.headline)

                // Workout Type Selection
                HStack(spacing: 12) {
                    WorkoutTypeWatchButton(
                        type: .walking,
                        isSelected: selectedType == .walking
                    ) {
                        selectedType = .walking
                        WKInterfaceDevice.current().play(.click)
                    }

                    WorkoutTypeWatchButton(
                        type: .running,
                        isSelected: selectedType == .running
                    ) {
                        selectedType = .running
                        WKInterfaceDevice.current().play(.click)
                    }
                }

                // Environment Selection
                HStack(spacing: 12) {
                    EnvironmentWatchButton(
                        environment: .outdoor,
                        isSelected: selectedEnvironment == .outdoor
                    ) {
                        selectedEnvironment = .outdoor
                        WKInterfaceDevice.current().play(.click)
                    }

                    EnvironmentWatchButton(
                        environment: .indoor,
                        isSelected: selectedEnvironment == .indoor
                    ) {
                        selectedEnvironment = .indoor
                        WKInterfaceDevice.current().play(.click)
                    }
                }

                Button {
                    startWorkout()
                } label: {
                    HStack {
                        if isStarting {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "play.fill")
                        }
                        Text(isStarting ? "Starting..." : "Start")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(selectedType == .running ? .orange : .green)
                .disabled(isStarting)
            }
            .padding()
        }
    }

    private func startWorkout() {
        isStarting = true
        WKInterfaceDevice.current().play(.start)

        Task {
            do {
                try await sessionManager.startWorkout(type: selectedType, environment: selectedEnvironment)

                await MainActor.run {
                    let workout = Workout(type: selectedType, environment: selectedEnvironment)
                    modelContext.insert(workout)
                    try? modelContext.save()
                    currentWorkout = workout
                    isStarting = false
                }
            } catch {
                print("Failed to start workout: \(error)")
                await MainActor.run {
                    isStarting = false
                    WKInterfaceDevice.current().play(.failure)
                }
            }
        }
    }
}

struct WorkoutTypeWatchButton: View {
    let type: WorkoutType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: type.systemImage)
                    .font(.title2)
                    .foregroundStyle(isSelected ? (type == .running ? .orange : .green) : .secondary)

                Text(type.displayName)
                    .font(.caption2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(isSelected ? (type == .running ? Color.orange.opacity(0.2) : Color.green.opacity(0.2)) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? (type == .running ? Color.orange : Color.green) : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

struct EnvironmentWatchButton: View {
    let environment: WorkoutEnvironment
    let isSelected: Bool
    let action: () -> Void

    private var systemImage: String {
        environment == .outdoor ? "sun.max.fill" : "building.2.fill"
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.caption)
                    .foregroundStyle(isSelected ? .primary : .secondary)

                Text(environment.displayName)
                    .font(.caption2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(isSelected ? Color.blue.opacity(0.2) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
}

struct ActiveWatchWorkoutView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(WorkoutSessionManager.self) private var sessionManager

    @Binding var currentWorkout: Workout?
    @State private var showingEndConfirmation = false

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Workout type indicator
                HStack {
                    Image(systemName: sessionManager.currentWorkoutType?.systemImage ?? "figure.walk")
                        .foregroundStyle(sessionManager.currentWorkoutType == .running ? .orange : .green)
                    Text(sessionManager.currentWorkoutType?.displayName ?? "Workout")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if sessionManager.isPaused {
                        Text("PAUSED")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundStyle(.yellow)
                    }
                }

                // Elapsed Time
                Text(sessionManager.formattedElapsedTime)
                    .font(.system(size: 40, weight: .bold, design: .monospaced))
                    .foregroundStyle(sessionManager.isPaused ? .secondary : .primary)

                // Primary metrics
                HStack(spacing: 20) {
                    MetricView(
                        value: sessionManager.formattedDistance,
                        unit: "mi",
                        color: .blue
                    )

                    MetricView(
                        value: sessionManager.formattedHeartRate,
                        unit: "bpm",
                        color: .red
                    )
                }

                // Secondary metrics
                HStack(spacing: 20) {
                    MetricView(
                        value: sessionManager.formattedPace,
                        unit: "/mi",
                        color: .orange
                    )

                    MetricView(
                        value: "\(sessionManager.stepCount)",
                        unit: "steps",
                        color: .green
                    )
                }

                // Calories
                HStack {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(.orange)
                    Text("\(Int(sessionManager.activeCalories)) cal")
                        .font(.caption)
                }
                .padding(.top, 4)

                // Control buttons
                HStack(spacing: 16) {
                    Button {
                        togglePause()
                    } label: {
                        Image(systemName: sessionManager.isPaused ? "play.fill" : "pause.fill")
                            .font(.title3)
                    }
                    .buttonStyle(.bordered)
                    .tint(sessionManager.isPaused ? .green : .yellow)

                    Button {
                        showingEndConfirmation = true
                    } label: {
                        Image(systemName: "stop.fill")
                            .font(.title3)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                }
                .padding(.top, 8)
            }
            .padding()
        }
        .confirmationDialog("End Workout?", isPresented: $showingEndConfirmation) {
            Button("End Workout", role: .destructive) {
                endWorkout()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your workout will be saved.")
        }
    }

    private func togglePause() {
        if sessionManager.isPaused {
            sessionManager.resumeWorkout()
            WKInterfaceDevice.current().play(.start)
        } else {
            sessionManager.pauseWorkout()
            WKInterfaceDevice.current().play(.stop)
        }
    }

    private func endWorkout() {
        WKInterfaceDevice.current().play(.success)

        Task {
            do {
                let hkWorkout = try await sessionManager.endWorkout()

                await MainActor.run {
                    if let workout = currentWorkout {
                        workout.duration = sessionManager.elapsedTime
                        workout.distance = sessionManager.distance
                        workout.stepCount = sessionManager.stepCount
                        workout.activeCalories = sessionManager.activeCalories
                        workout.averageHeartRate = sessionManager.averageHeartRate > 0 ? sessionManager.averageHeartRate : nil
                        workout.averagePace = sessionManager.averagePace > 0 ? sessionManager.averagePace : nil
                        workout.averageCadence = sessionManager.cadence > 0 ? sessionManager.cadence : nil
                        workout.healthKitWorkoutID = hkWorkout?.uuid
                        workout.complete()

                        try? modelContext.save()
                    }
                    currentWorkout = nil
                }
            } catch {
                print("Failed to end workout: \(error)")
                WKInterfaceDevice.current().play(.failure)
            }
        }
    }
}

struct MetricView: View {
    let value: String
    let unit: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(.headline, design: .rounded))
                .fontWeight(.semibold)
                .foregroundStyle(color)

            Text(unit)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    WatchWorkoutView()
        .modelContainer(for: Workout.self)
        .environment(WorkoutSessionManager.shared)
}
