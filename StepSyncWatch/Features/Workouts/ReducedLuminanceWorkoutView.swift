import SwiftUI

/// Minimal battery-efficient workout view displayed when the always-on display is dimmed.
/// Shows only essential information with a pure black background (OLED pixels off = zero power).
/// HealthKit continues collecting data at full rate - only UI updates are reduced.
struct ReducedLuminanceWorkoutView: View {
    @Environment(WorkoutSessionManager.self) private var sessionManager

    private var workoutColor: Color {
        sessionManager.currentWorkoutType == .running ? .orange : .green
    }

    var body: some View {
        VStack(spacing: 8) {
            // Workout type indicator
            Image(systemName: sessionManager.currentWorkoutType?.systemImage ?? "figure.walk")
                .font(.title2)
                .foregroundStyle(workoutColor.opacity(0.6))

            // Large elapsed time - the primary information needed
            Text(sessionManager.formattedElapsedTime)
                .font(.system(size: 48, weight: .medium, design: .monospaced))
                .foregroundStyle(.primary.opacity(0.8))

            // Pause indicator if workout is paused
            if sessionManager.isPaused {
                Text("PAUSED")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.yellow.opacity(0.7))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }
}

#Preview {
    ReducedLuminanceWorkoutView()
        .environment(WorkoutSessionManager.shared)
}
