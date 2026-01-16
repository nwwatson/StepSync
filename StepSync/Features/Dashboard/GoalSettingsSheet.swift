import SwiftUI
import SwiftData

struct GoalSettingsSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(HealthKitManager.self) private var healthKitManager

    @Query(sort: \StepGoal.createdAt, order: .reverse) private var goals: [StepGoal]

    @State private var targetSteps: Double = 10000
    @State private var isLoadingSuggestion = false

    private var currentGoal: StepGoal? {
        goals.first
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 20) {
                        Text("\(Int(targetSteps).formatted())")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .contentTransition(.numericText())

                        Text("Daily Step Goal")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Slider(
                            value: $targetSteps,
                            in: Double(StepGoal.minimumGoal)...Double(StepGoal.maximumGoal),
                            step: 500
                        )
                        .tint(.primary)
                    }
                    .padding(.vertical)
                }

                Section {
                    Button {
                        Task {
                            await loadSuggestedGoal()
                        }
                    } label: {
                        HStack {
                            Label("Suggest Goal", systemImage: "wand.and.stars")

                            Spacer()

                            if isLoadingSuggestion {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isLoadingSuggestion)
                } footer: {
                    Text("Based on your 30-day step history")
                }

                if let goal = currentGoal {
                    Section("Progress") {
                        LabeledContent("Current Level", value: "Level \(goal.progressionLevel)")
                        LabeledContent("Consecutive Days", value: "\(goal.consecutiveDaysAchieved)")

                        if goal.consecutiveDaysAchieved > 0 {
                            let daysRemaining = StepGoal.progressionThreshold - goal.consecutiveDaysAchieved
                            if daysRemaining > 0 {
                                Text("\(daysRemaining) more days to level up!")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Automatic Progression", systemImage: "arrow.up.circle")
                            .font(.headline)

                        Text("When you meet your goal for 5 consecutive days, it automatically increases by 10%.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Step Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveGoal()
                        dismiss()
                    }
                }
            }
            .onAppear {
                if let goal = currentGoal {
                    targetSteps = Double(goal.dailyTarget)
                }
            }
        }
    }

    private func loadSuggestedGoal() async {
        isLoadingSuggestion = true

        do {
            let suggested = try await healthKitManager.suggestInitialStepGoal()
            await MainActor.run {
                withAnimation {
                    targetSteps = Double(suggested)
                }
                isLoadingSuggestion = false
            }
        } catch {
            await MainActor.run {
                isLoadingSuggestion = false
            }
        }
    }

    private func saveGoal() {
        if let goal = currentGoal {
            goal.dailyTarget = Int(targetSteps)
            goal.updatedAt = Date()
        } else {
            let newGoal = StepGoal(dailyTarget: Int(targetSteps))
            modelContext.insert(newGoal)
        }

        try? modelContext.save()
    }
}

#Preview {
    GoalSettingsSheet()
        .modelContainer(for: StepGoal.self)
        .environment(HealthKitManager.shared)
}
