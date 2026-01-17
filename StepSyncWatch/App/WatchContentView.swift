import SwiftUI
import SwiftData

struct WatchContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(WorkoutSessionManager.self) private var sessionManager
    @Environment(QuickStartState.self) private var quickStartState

    @State private var currentWorkout: Workout?
    @State private var selectedTab: Int = 0

    var body: some View {
        @Bindable var quickStart = quickStartState

        NavigationStack {
            TabView(selection: $selectedTab) {
                WatchDashboardView()
                    .tag(0)

                WatchWorkoutView()
                    .tag(1)

                WatchSummaryView()
                    .tag(2)
            }
            .tabViewStyle(.verticalPage)
        }
        .fullScreenCover(isPresented: $quickStart.showQuickStartPicker) {
            if let workoutType = quickStartState.pendingWorkoutType {
                QuickStartEnvironmentPicker(
                    workoutType: workoutType,
                    onEnvironmentSelected: { environment in
                        startWorkout(type: workoutType, environment: environment)
                    },
                    onCancel: {
                        quickStartState.clear()
                    }
                )
            }
        }
        .onChange(of: sessionManager.isSessionActive) { wasActive, isActive in
            // Navigate back to dashboard when workout ends
            if wasActive && !isActive {
                selectedTab = 0
            }
        }
    }

    /// Starts a workout with the given type and environment
    private func startWorkout(type: WorkoutType, environment: WorkoutEnvironment) {
        quickStartState.clear()

        Task {
            do {
                try await sessionManager.startWorkout(type: type, environment: environment)

                await MainActor.run {
                    let workout = Workout(type: type, environment: environment)
                    modelContext.insert(workout)
                    try? modelContext.save()
                    currentWorkout = workout

                    // Navigate to the workout tab to show the active workout
                    selectedTab = 1
                }
            } catch {
                print("Failed to start workout from complication: \(error)")
            }
        }
    }
}

#Preview {
    WatchContentView()
}
