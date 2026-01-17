import SwiftUI
import WidgetKit
import ActivityKit

/// Live Activity widget configuration for workouts
@available(iOS 16.1, *)
struct WorkoutLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutActivityAttributes.self) { context in
            WorkoutLockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded regions
                DynamicIslandExpandedRegion(.leading) {
                    ExpandedLeadingView(context: context)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    ExpandedTrailingView(context: context)
                }

                DynamicIslandExpandedRegion(.center) {
                    ExpandedCenterView(context: context)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    ExpandedBottomView(context: context)
                }
            } compactLeading: {
                CompactLeadingView(context: context)
            } compactTrailing: {
                CompactTrailingView(context: context)
            } minimal: {
                MinimalView(context: context)
            }
        }
    }
}

// MARK: - Lock Screen View

@available(iOS 16.1, *)
struct WorkoutLockScreenView: View {
    let context: ActivityViewContext<WorkoutActivityAttributes>

    private var state: WorkoutActivityAttributes.ContentState {
        context.state
    }

    private var attributes: WorkoutActivityAttributes {
        context.attributes
    }

    private var progress: Double {
        min(state.progressTowardGoal(dailyGoal: attributes.dailyGoal), 1.0)
    }

    private var progressPercentage: Int {
        Int(state.progressTowardGoal(dailyGoal: attributes.dailyGoal) * 100)
    }

    var body: some View {
        HStack(spacing: 16) {
            // Left side - Steps and heart rate
            VStack(alignment: .leading, spacing: 8) {
                // Step count
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(state.stepCount.formatted())")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)

                    HStack(spacing: 4) {
                        Text("steps")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        if state.isPaused {
                            Text("PAUSED")
                                .font(.caption2.bold())
                                .foregroundStyle(.orange)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.orange.opacity(0.2))
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                    }
                }

                // Heart rate
                HStack(spacing: 4) {
                    Image(systemName: "heart.fill")
                        .font(.caption)
                        .foregroundStyle(.red)

                    Text("\(state.formattedHeartRate) bpm")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()
                .frame(height: 80)

            // Right side - Distance, progress, time
            VStack(alignment: .trailing, spacing: 8) {
                // Distance
                Text(state.formattedDistance)
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)

                // Progress bar
                VStack(alignment: .trailing, spacing: 4) {
                    ProgressView(value: progress)
                        .progressViewStyle(.linear)
                        .tint(progress >= 1.0 ? .green : .primary)

                    Text("\(state.totalDailySteps.formatted()) / \(attributes.dailyGoal.formatted())")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                // Elapsed time
                Text(state.formattedElapsedTime)
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .activityBackgroundTint(.black.opacity(0.8))
    }
}

// MARK: - Dynamic Island Compact Views

@available(iOS 16.1, *)
struct CompactLeadingView: View {
    let context: ActivityViewContext<WorkoutActivityAttributes>

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: context.attributes.workoutIcon)
                .font(.caption)

            Text("\(context.state.stepCount.formatted())")
                .font(.caption.monospacedDigit().bold())
        }
    }
}

@available(iOS 16.1, *)
struct CompactTrailingView: View {
    let context: ActivityViewContext<WorkoutActivityAttributes>

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: "heart.fill")
                .font(.caption2)
                .foregroundStyle(.red)

            Text(context.state.formattedHeartRate)
                .font(.caption.monospacedDigit())
        }
    }
}

// MARK: - Dynamic Island Expanded Views

@available(iOS 16.1, *)
struct ExpandedLeadingView: View {
    let context: ActivityViewContext<WorkoutActivityAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Image(systemName: context.attributes.workoutIcon)
                .font(.title2)

            Text(context.attributes.workoutType)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

@available(iOS 16.1, *)
struct ExpandedTrailingView: View {
    let context: ActivityViewContext<WorkoutActivityAttributes>

    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            HStack(spacing: 2) {
                Image(systemName: "heart.fill")
                    .font(.caption)
                    .foregroundStyle(.red)

                Text(context.state.formattedHeartRate)
                    .font(.title3.monospacedDigit().bold())
            }

            Text("bpm")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

@available(iOS 16.1, *)
struct ExpandedCenterView: View {
    let context: ActivityViewContext<WorkoutActivityAttributes>

    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 4) {
                Text("\(context.state.stepCount.formatted())")
                    .font(.title2.bold().monospacedDigit())

                Text("steps")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if context.state.isPaused {
                Text("PAUSED")
                    .font(.caption2.bold())
                    .foregroundStyle(.orange)
            }
        }
    }
}

@available(iOS 16.1, *)
struct ExpandedBottomView: View {
    let context: ActivityViewContext<WorkoutActivityAttributes>

    private var progress: Double {
        min(context.state.progressTowardGoal(dailyGoal: context.attributes.dailyGoal), 1.0)
    }

    var body: some View {
        HStack {
            Text(context.state.formattedDistance)
                .font(.caption.bold())

            Spacer()

            ProgressView(value: progress)
                .progressViewStyle(.linear)
                .tint(progress >= 1.0 ? .green : .white)
                .frame(width: 80)

            Text("\(Int(progress * 100))%")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Spacer()

            Text(context.state.formattedElapsedTime)
                .font(.caption.monospacedDigit())
        }
    }
}

// MARK: - Minimal View

@available(iOS 16.1, *)
struct MinimalView: View {
    let context: ActivityViewContext<WorkoutActivityAttributes>

    var body: some View {
        Image(systemName: context.attributes.workoutIcon)
            .font(.caption)
    }
}

// MARK: - Previews

#if DEBUG
@available(iOS 16.1, *)
#Preview("Lock Screen", as: .content, using: WorkoutActivityAttributes(
    workoutType: "Walking",
    workoutIcon: "figure.walk",
    dailyGoal: 10000
)) {
    WorkoutLiveActivity()
} contentStates: {
    WorkoutActivityAttributes.ContentState(
        stepCount: 2542,
        totalDailySteps: 7542,
        heartRate: 142,
        distanceMiles: 2.45,
        elapsedSeconds: 754,
        isPaused: false
    )
    WorkoutActivityAttributes.ContentState(
        stepCount: 2542,
        totalDailySteps: 7542,
        heartRate: 142,
        distanceMiles: 2.45,
        elapsedSeconds: 754,
        isPaused: true
    )
}
#endif
