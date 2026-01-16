import SwiftUI
import SwiftData

struct ActiveWorkoutView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(WorkoutMirroringManager.self) private var mirroringManager
    @Environment(LocationManager.self) private var locationManager

    let workout: Workout
    let isWatchWorkout: Bool

    @State private var isPaused = false
    @State private var showingEndConfirmation = false

    init(workout: Workout, isWatchWorkout: Bool = false) {
        self.workout = workout
        self.isWatchWorkout = isWatchWorkout
    }

    var body: some View {
        VStack(spacing: 0) {
            if isWatchWorkout {
                watchIndicator
            }

            metricsSection
                .padding()

            Spacer()

            controlsSection
                .padding()
        }
        .background(Color(.systemBackground))
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("End") {
                    showingEndConfirmation = true
                }
                .foregroundStyle(.red)
            }
        }
        .confirmationDialog("End Workout?", isPresented: $showingEndConfirmation) {
            Button("End Workout", role: .destructive) {
                endWorkout()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to end this workout?")
        }
        .onAppear {
            if !isWatchWorkout && workout.environment == .outdoor {
                locationManager.startTracking()
            }
        }
    }

    private var watchIndicator: some View {
        HStack(spacing: 8) {
            Image(systemName: "applewatch")
                .foregroundStyle(.green)
            Text("Running on Apple Watch")
                .font(.caption)
                .foregroundStyle(.secondary)

            if mirroringManager.isPaused {
                Text("• PAUSED")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.yellow)
            }
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(Color.green.opacity(0.1))
    }

    private var metricsSection: some View {
        VStack(spacing: 32) {
            VStack(spacing: 4) {
                Text(isWatchWorkout ? mirroringManager.formattedElapsedTime : formattedDuration)
                    .font(.system(size: 64, weight: .bold, design: .monospaced))

                Text("Duration")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 24) {
                MetricCard(
                    title: "Distance",
                    value: isWatchWorkout ? mirroringManager.formattedDistance : formattedDistance,
                    unit: "mi",
                    systemImage: "map"
                )

                MetricCard(
                    title: "Heart Rate",
                    value: isWatchWorkout ? mirroringManager.formattedHeartRate : "--",
                    unit: "bpm",
                    systemImage: "heart.fill",
                    color: .red
                )

                MetricCard(
                    title: "Pace",
                    value: isWatchWorkout ? mirroringManager.formattedPace : "--:--",
                    unit: "/mi",
                    systemImage: "speedometer"
                )

                MetricCard(
                    title: "Calories",
                    value: isWatchWorkout ? String(format: "%.0f", mirroringManager.activeCalories) : "--",
                    unit: "cal",
                    systemImage: "flame"
                )
            }

            if isWatchWorkout && mirroringManager.stepCount > 0 {
                HStack(spacing: 32) {
                    VStack(spacing: 4) {
                        Text("\(mirroringManager.stepCount)")
                            .font(.title2)
                            .fontWeight(.semibold)
                        Text("Total Steps")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var controlsSection: some View {
        HStack(spacing: 32) {
            Button {
                togglePause()
            } label: {
                Image(systemName: isPaused ? "play.fill" : "pause.fill")
                    .font(.title)
                    .frame(width: 72, height: 72)
                    .background(Color(.systemGray5))
                    .clipShape(Circle())
            }

            Button {
                showingEndConfirmation = true
            } label: {
                Image(systemName: "stop.fill")
                    .font(.title)
                    .foregroundStyle(.white)
                    .frame(width: 72, height: 72)
                    .background(Color.red)
                    .clipShape(Circle())
            }
        }
    }

    private func togglePause() {
        if isWatchWorkout {
            if isPaused {
                mirroringManager.resumeWorkout()
            } else {
                mirroringManager.pauseWorkout()
            }
        }
        isPaused.toggle()
    }

    private func endWorkout() {
        if isWatchWorkout {
            Task {
                try? await mirroringManager.endWorkout()

                await MainActor.run {
                    workout.complete()
                    workout.distance = mirroringManager.distance
                    workout.stepCount = mirroringManager.stepCount
                    workout.activeCalories = mirroringManager.activeCalories
                    workout.averageHeartRate = mirroringManager.averageHeartRate > 0 ? mirroringManager.averageHeartRate : nil
                    workout.averagePace = mirroringManager.currentPace > 0 ? mirroringManager.currentPace : nil

                    try? modelContext.save()
                    dismiss()
                }
            }
        } else {
            locationManager.stopTracking()

            workout.complete()
            workout.distance = locationManager.totalDistance
            workout.elevationGain = locationManager.elevationGain > 0 ? locationManager.elevationGain : nil

            for (latitude, longitude) in locationManager.getRouteCoordinates() {
                let routePoint = WorkoutRoutePoint(latitude: latitude, longitude: longitude)
                routePoint.workout = workout
                modelContext.insert(routePoint)
            }

            try? modelContext.save()
            dismiss()
        }
    }

    // MARK: - Computed Properties for non-watch workouts

    private var formattedDuration: String {
        let duration = Date().timeIntervalSince(workout.startDate)
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }

    private var formattedDistance: String {
        let distanceInMiles = locationManager.totalDistance / 1609.34
        return String(format: "%.2f", distanceInMiles)
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let unit: String
    let systemImage: String
    var color: Color = .primary

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(color == .primary ? .secondary : color)

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(color)

                Text(unit)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    NavigationStack {
        ActiveWorkoutView(workout: Workout(type: .walking, environment: .outdoor), isWatchWorkout: true)
    }
    .environment(WorkoutMirroringManager.shared)
    .environment(LocationManager.shared)
}
