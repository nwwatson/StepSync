import Foundation
import SwiftData
import HealthKit

/// Service that synchronizes workouts between HealthKit and SwiftData.
/// This ensures workouts that exist in HealthKit (e.g., from Apple Watch) appear in the app
/// even if CloudKit sync failed or was delayed.
@Observable
public final class WorkoutSyncService: @unchecked Sendable {
    public static let shared = WorkoutSyncService()

    private let healthKitManager = HealthKitManager.shared

    public private(set) var isSyncing = false
    public private(set) var lastSyncDate: Date?
    public private(set) var lastSyncError: Error?
    public private(set) var workoutsSyncedCount = 0

    private init() {}

    /// Syncs workouts from HealthKit to SwiftData for the specified number of days.
    /// Creates SwiftData records for any HealthKit workouts that don't already exist.
    /// - Parameters:
    ///   - modelContext: The SwiftData model context to use for saving
    ///   - days: Number of days to look back (default: 30)
    /// - Returns: Number of workouts that were synced (created in SwiftData)
    @MainActor
    public func syncWorkouts(modelContext: ModelContext, days: Int = 30) async -> Int {
        guard !isSyncing else {
            print("WorkoutSyncService: Sync already in progress")
            return 0
        }

        isSyncing = true
        lastSyncError = nil
        workoutsSyncedCount = 0

        defer {
            isSyncing = false
            lastSyncDate = Date()
        }

        do {
            // Fetch workouts from HealthKit
            let healthKitWorkouts = try await healthKitManager.getRecentWorkouts(days: days)
            print("WorkoutSyncService: Found \(healthKitWorkouts.count) workouts in HealthKit")

            if healthKitWorkouts.isEmpty {
                return 0
            }

            // Get existing workout HealthKit IDs from SwiftData
            let existingHealthKitIDs = await fetchExistingHealthKitIDs(modelContext: modelContext)
            print("WorkoutSyncService: Found \(existingHealthKitIDs.count) existing workouts in SwiftData")

            // Find workouts that exist in HealthKit but not in SwiftData
            let missingWorkouts = healthKitWorkouts.filter { !existingHealthKitIDs.contains($0.uuid) }
            print("WorkoutSyncService: Found \(missingWorkouts.count) workouts to sync")

            // Create SwiftData records for missing workouts
            for hkWorkout in missingWorkouts {
                let workout = Workout(
                    type: hkWorkout.workoutType,
                    environment: hkWorkout.environment,
                    startDate: hkWorkout.startDate
                )
                workout.endDate = hkWorkout.endDate
                workout.duration = hkWorkout.duration
                workout.distance = hkWorkout.distance
                workout.stepCount = hkWorkout.stepCount
                workout.activeCalories = hkWorkout.activeCalories
                workout.healthKitWorkoutID = hkWorkout.uuid
                workout.isCompleted = true
                workout.updatedAt = Date()

                modelContext.insert(workout)
                workoutsSyncedCount += 1

                print("WorkoutSyncService: Created workout - type: \(hkWorkout.workoutType.displayName), date: \(hkWorkout.startDate), distance: \(hkWorkout.distance)m")
            }

            // Save all new workouts
            if workoutsSyncedCount > 0 {
                do {
                    try modelContext.save()
                    print("WorkoutSyncService: Successfully saved \(workoutsSyncedCount) workouts to SwiftData")
                } catch {
                    print("WorkoutSyncService: ERROR - Failed to save workouts: \(error)")
                    lastSyncError = error
                    // The workouts are still in memory and will be persisted eventually
                }
            }

            return workoutsSyncedCount

        } catch {
            print("WorkoutSyncService: ERROR - Failed to sync workouts: \(error)")
            lastSyncError = error
            return 0
        }
    }

    /// Fetches the HealthKit UUIDs of all workouts already in SwiftData
    @MainActor
    private func fetchExistingHealthKitIDs(modelContext: ModelContext) async -> Set<UUID> {
        let descriptor = FetchDescriptor<Workout>(
            predicate: #Predicate { $0.healthKitWorkoutID != nil }
        )

        do {
            let existingWorkouts = try modelContext.fetch(descriptor)
            let ids = Set(existingWorkouts.compactMap { $0.healthKitWorkoutID })
            return ids
        } catch {
            print("WorkoutSyncService: ERROR - Failed to fetch existing workouts: \(error)")
            return []
        }
    }

    /// Convenience method to sync and return whether any new workouts were found
    @MainActor
    public func syncAndCheckForNew(modelContext: ModelContext) async -> Bool {
        let count = await syncWorkouts(modelContext: modelContext)
        return count > 0
    }
}
