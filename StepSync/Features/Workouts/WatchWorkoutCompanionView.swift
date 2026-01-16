import SwiftUI
import SwiftData
import MapKit
import CoreLocation

/// Companion screen that automatically appears on iOS when a workout
/// is started on Apple Watch. Shows real-time metrics with steps
/// prominently displayed, a live map for outdoor workouts, and
/// synchronized pause/stop controls.
struct WatchWorkoutCompanionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(WorkoutMirroringManager.self) private var mirroringManager
    @Environment(LocationManager.self) private var locationManager

    @State private var mapCameraPosition: MapCameraPosition = .automatic
    @State private var showingEndConfirmation = false

    private var isOutdoor: Bool {
        mirroringManager.currentWorkoutEnvironment == .outdoor
    }

    private var workoutTypeDisplayName: String {
        mirroringManager.currentWorkoutType?.displayName ?? "Workout"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Watch indicator banner
            watchIndicatorBanner

            // Scrollable content
            ScrollView {
                VStack(spacing: 24) {
                    // Hero step counter
                    heroStepCounter
                        .padding(.top, 24)

                    // Secondary metrics row
                    secondaryMetricsRow
                        .padding(.horizontal)

                    // Live map (outdoor only)
                    if isOutdoor {
                        liveMapSection
                            .padding(.horizontal)
                    }

                    // Duration display
                    durationDisplay

                    // Spacer for bottom control clearance
                    Spacer(minLength: 120)
                }
            }

            // Fixed bottom control bar
            controlBar
        }
        .background(.background)
        .navigationBarBackButtonHidden(true)
        .confirmationDialog("End Workout?", isPresented: $showingEndConfirmation) {
            Button("End Workout", role: .destructive) {
                endWorkout()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to end this workout?")
        }
        .onAppear {
            if isOutdoor {
                locationManager.startTracking { location in
                    updateMapCamera(for: location)
                }
            }
        }
        .onDisappear {
            if isOutdoor {
                locationManager.stopTracking()
            }
        }
    }

    // MARK: - Watch Indicator Banner

    private var watchIndicatorBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "applewatch")
                .font(.system(size: 16))
                .foregroundStyle(.green)

            Text("\(workoutTypeDisplayName) on Apple Watch")
                .font(.subheadline)
                .fontWeight(.medium)

            Spacer()

            if mirroringManager.isPaused {
                Text("PAUSED")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.2))
                    .clipShape(Capsule())
            } else {
                HStack(spacing: 4) {
                    Circle()
                        .fill(.green)
                        .frame(width: 8, height: 8)
                    Text("LIVE")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.green)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.green.opacity(0.1))
    }

    // MARK: - Hero Step Counter

    private var heroStepCounter: some View {
        VStack(spacing: 4) {
            Text("\(mirroringManager.stepCount)")
                .font(.system(size: 72, weight: .bold, design: .rounded))
                .contentTransition(.numericText())
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: mirroringManager.stepCount)

            Text("STEPS")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .tracking(2)
        }
    }

    // MARK: - Secondary Metrics Row

    private var secondaryMetricsRow: some View {
        HStack(spacing: 12) {
            CompanionMetricCard(
                title: "Distance",
                value: mirroringManager.formattedDistance,
                unit: "mi",
                systemImage: "map"
            )

            CompanionMetricCard(
                title: "Heart Rate",
                value: mirroringManager.formattedHeartRate,
                unit: "bpm",
                systemImage: "heart.fill",
                color: .red
            )

            CompanionMetricCard(
                title: "Calories",
                value: formattedCalories,
                unit: "cal",
                systemImage: "flame.fill",
                color: .orange
            )
        }
    }

    // MARK: - Live Map Section

    private var liveMapSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Route")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)

            Map(position: $mapCameraPosition) {
                // Route polyline
                if locationManager.routePoints.count > 1 {
                    MapPolyline(coordinates: locationManager.routePoints.map { $0.coordinate })
                        .stroke(.blue, lineWidth: 4)
                }

                // Current location marker
                if let currentLocation = locationManager.currentLocation {
                    PulsingLocationAnnotation(coordinate: currentLocation.coordinate)
                }
            }
            .mapStyle(.standard(elevation: .realistic))
            .mapControls {
                MapCompass()
            }
            .frame(height: 200)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    // MARK: - Duration Display

    private var durationDisplay: some View {
        VStack(spacing: 4) {
            Text(mirroringManager.formattedElapsedTime)
                .font(.system(size: 32, weight: .semibold, design: .monospaced))
                .contentTransition(.numericText())

            Text("Duration")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
    }

    // MARK: - Control Bar

    private var controlBar: some View {
        VStack(spacing: 0) {
            Divider()

            HStack(spacing: 24) {
                // Pause/Resume Button
                Button {
                    togglePause()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: mirroringManager.isPaused ? "play.fill" : "pause.fill")
                            .font(.title3)
                        Text(mirroringManager.isPaused ? "Resume" : "Pause")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(.fill.tertiary)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)

                // Stop Button
                Button {
                    showingEndConfirmation = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "stop.fill")
                            .font(.title3)
                        Text("Stop")
                            .fontWeight(.semibold)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.red)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.background)
        }
    }

    // MARK: - Computed Properties

    private var formattedCalories: String {
        guard mirroringManager.activeCalories > 0 else { return "--" }
        return String(format: "%.0f", mirroringManager.activeCalories)
    }

    // MARK: - Actions

    private func togglePause() {
        if mirroringManager.isPaused {
            mirroringManager.resumeWorkout()
        } else {
            mirroringManager.pauseWorkout()
        }
    }

    private func endWorkout() {
        Task {
            // Stop location tracking
            if isOutdoor {
                locationManager.stopTracking()
            }

            // End the mirrored workout session
            try? await mirroringManager.endWorkout()

            // Save workout data
            await MainActor.run {
                saveWorkoutData()
            }
        }
    }

    private func saveWorkoutData() {
        guard let workoutType = mirroringManager.currentWorkoutType,
              let workoutEnvironment = mirroringManager.currentWorkoutEnvironment else {
            return
        }

        let workout = Workout(
            type: workoutType,
            environment: workoutEnvironment,
            startDate: Date().addingTimeInterval(-mirroringManager.elapsedTime)
        )

        workout.complete()
        workout.distance = mirroringManager.distance
        workout.stepCount = mirroringManager.stepCount
        workout.activeCalories = mirroringManager.activeCalories
        workout.averageHeartRate = mirroringManager.averageHeartRate > 0 ? mirroringManager.averageHeartRate : nil
        workout.averagePace = mirroringManager.currentPace > 0 ? mirroringManager.currentPace : nil

        // Save route points for outdoor workouts
        if isOutdoor {
            workout.elevationGain = locationManager.elevationGain > 0 ? locationManager.elevationGain : nil

            var routePointModels: [WorkoutRoutePoint] = []
            for location in locationManager.routePoints {
                let routePoint = WorkoutRoutePoint(
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude,
                    altitude: location.altitude,
                    speed: location.speed,
                    timestamp: location.timestamp,
                    horizontalAccuracy: location.horizontalAccuracy,
                    verticalAccuracy: location.verticalAccuracy
                )
                routePoint.workout = workout
                routePointModels.append(routePoint)
            }
            workout.routePoints = routePointModels
        }

        modelContext.insert(workout)
        try? modelContext.save()
    }

    private func updateMapCamera(for location: CLLocation) {
        withAnimation(.easeInOut(duration: 0.5)) {
            mapCameraPosition = .camera(
                MapCamera(
                    centerCoordinate: location.coordinate,
                    distance: 500,
                    heading: location.course >= 0 ? location.course : 0,
                    pitch: 45
                )
            )
        }
    }
}

#Preview {
    NavigationStack {
        WatchWorkoutCompanionView()
    }
    .environment(WorkoutMirroringManager.shared)
    .environment(LocationManager.shared)
}
