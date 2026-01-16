import SwiftUI
import SwiftData

struct NewWorkoutSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(WorkoutMirroringManager.self) private var mirroringManager

    @State private var selectedType: WorkoutType = .walking
    @State private var selectedEnvironment: WorkoutEnvironment = .outdoor
    @State private var startOnWatch: Bool = true
    @State private var isStartingWorkout = false
    @State private var errorMessage: String?
    @State private var showingError = false

    var onWorkoutStarted: ((Workout, Bool) -> Void)?

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                workoutTypeSelection

                environmentSelection

                watchToggle

                Spacer()

                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                startButton
            }
            .padding()
            .navigationTitle("New Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Unable to Start Workout", isPresented: $showingError) {
                Button("OK") {}
            } message: {
                Text(errorMessage ?? "An unknown error occurred")
            }
        }
    }

    private var workoutTypeSelection: some View {
        VStack(spacing: 16) {
            Text("Workout Type")
                .font(.headline)

            HStack(spacing: 16) {
                WorkoutTypeButton(
                    type: .walking,
                    isSelected: selectedType == .walking
                ) {
                    selectedType = .walking
                }

                WorkoutTypeButton(
                    type: .running,
                    isSelected: selectedType == .running
                ) {
                    selectedType = .running
                }
            }
        }
    }

    private var environmentSelection: some View {
        VStack(spacing: 16) {
            Text("Environment")
                .font(.headline)

            HStack(spacing: 16) {
                EnvironmentButton(
                    environment: .outdoor,
                    isSelected: selectedEnvironment == .outdoor
                ) {
                    selectedEnvironment = .outdoor
                }

                EnvironmentButton(
                    environment: .indoor,
                    isSelected: selectedEnvironment == .indoor
                ) {
                    selectedEnvironment = .indoor
                }
            }
        }
    }

    private var watchToggle: some View {
        VStack(spacing: 12) {
            Toggle(isOn: $startOnWatch) {
                HStack(spacing: 12) {
                    Image(systemName: "applewatch")
                        .font(.title2)
                        .foregroundStyle(startOnWatch ? .green : .secondary)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Start on Apple Watch")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        Text("Uses Watch sensors for accurate metrics")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .tint(.green)
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private var startButton: some View {
        Button {
            startWorkout()
        } label: {
            HStack {
                if isStartingWorkout {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: startOnWatch ? "applewatch" : "play.fill")
                    Text(startOnWatch ? "Start on Watch" : "Start \(selectedType.displayName)")
                }
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding()
            .background(selectedType == .running ? .orange : .green)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .disabled(isStartingWorkout)
    }

    private func startWorkout() {
        isStartingWorkout = true
        errorMessage = nil

        let workout = Workout(
            type: selectedType,
            environment: selectedEnvironment,
            startDate: Date()
        )
        modelContext.insert(workout)

        if startOnWatch {
            // Start workout on Apple Watch via mirroring
            Task {
                do {
                    try await mirroringManager.startMirroredWorkout(
                        type: selectedType,
                        environment: selectedEnvironment
                    )

                    await MainActor.run {
                        try? modelContext.save()
                        onWorkoutStarted?(workout, true)
                        dismiss()
                    }
                } catch {
                    await MainActor.run {
                        isStartingWorkout = false
                        errorMessage = error.localizedDescription

                        // If mirroring fails, offer to start on phone only
                        if let mirroringError = error as? WorkoutMirroringError {
                            switch mirroringError {
                            case .watchNotReachable, .mirroringFailed:
                                errorMessage = "Could not connect to Apple Watch. Make sure your Watch is nearby, unlocked, and has StpnSzn installed."
                            default:
                                errorMessage = mirroringError.localizedDescription
                            }
                        }
                        showingError = true
                    }
                }
            }
        } else {
            // Start workout on iPhone only
            try? modelContext.save()
            onWorkoutStarted?(workout, false)
            dismiss()
        }
    }
}

struct WorkoutTypeButton: View {
    let type: WorkoutType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: type.systemImage)
                    .font(.system(size: 40))

                Text(type.displayName)
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .background(isSelected ? (type == .running ? Color.orange.opacity(0.1) : Color.green.opacity(0.1)) : Color(.systemGray6))
            .foregroundStyle(isSelected ? (type == .running ? .orange : .green) : .primary)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? (type == .running ? Color.orange : Color.green) : Color.clear, lineWidth: 2)
            )
        }
    }
}

struct EnvironmentButton: View {
    let environment: WorkoutEnvironment
    let isSelected: Bool
    let action: () -> Void

    var systemImage: String {
        environment == .outdoor ? "sun.max" : "building.2"
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.title2)

                Text(environment.displayName)
                    .font(.subheadline)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(isSelected ? Color.primary.opacity(0.1) : Color(.systemGray6))
            .foregroundStyle(isSelected ? .primary : .secondary)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.primary : Color.clear, lineWidth: 2)
            )
        }
    }
}

#Preview {
    NewWorkoutSheet()
        .modelContainer(for: Workout.self)
        .environment(WorkoutMirroringManager.shared)
}
