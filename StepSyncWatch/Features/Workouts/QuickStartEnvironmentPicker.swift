import SwiftUI
import WatchKit

/// A minimal picker view shown when the Watch app launches from a complication.
/// Allows the user to quickly select indoor/outdoor environment before starting a workout.
struct QuickStartEnvironmentPicker: View {
    let workoutType: WorkoutType
    let onEnvironmentSelected: (WorkoutEnvironment) -> Void
    let onCancel: () -> Void

    private var themeColor: Color {
        workoutType == .running ? .orange : .green
    }

    private var workoutIcon: String {
        workoutType == .running ? "figure.run" : "figure.walk"
    }

    private var workoutName: String {
        workoutType == .running ? "Running" : "Walking"
    }

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Image(systemName: workoutIcon)
                    .foregroundStyle(themeColor)
                Text("Start \(workoutName)")
                    .font(.headline)
            }

            // Environment buttons
            HStack(spacing: 12) {
                environmentButton(environment: .outdoor)
                environmentButton(environment: .indoor)
            }

            // Cancel button
            Button("Cancel", role: .cancel) {
                WKInterfaceDevice.current().play(.click)
                onCancel()
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding()
    }

    private func environmentButton(environment: WorkoutEnvironment) -> some View {
        Button {
            WKInterfaceDevice.current().play(.start)
            onEnvironmentSelected(environment)
        } label: {
            VStack(spacing: 6) {
                Image(systemName: environment == .outdoor ? "sun.max.fill" : "building.2.fill")
                    .font(.title2)
                    .foregroundStyle(environment == .outdoor ? .yellow : .gray)

                Text(environment.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(themeColor.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(themeColor.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    QuickStartEnvironmentPicker(
        workoutType: .walking,
        onEnvironmentSelected: { _ in },
        onCancel: {}
    )
}

#Preview {
    QuickStartEnvironmentPicker(
        workoutType: .running,
        onEnvironmentSelected: { _ in },
        onCancel: {}
    )
}
