import SwiftUI

/// Shared state for managing quick start workout flow from complications
@MainActor
@Observable
final class QuickStartState {
    static let shared = QuickStartState()

    var pendingWorkoutType: WorkoutType?
    var showQuickStartPicker: Bool = false

    private init() {}

    /// Handles a deep link URL from a complication
    /// - Parameter url: The URL to handle (e.g., stepsync://workout/start?type=walking)
    /// - Returns: true if the URL was handled successfully
    @discardableResult
    func handleURL(_ url: URL) -> Bool {
        print("QuickStartState: Handling URL: \(url)")

        // Parse the URL
        guard url.scheme == "stepsync",
              url.host == "workout",
              url.pathComponents.contains("start") else {
            print("QuickStartState: Invalid URL format - scheme: \(url.scheme ?? "nil"), host: \(url.host ?? "nil"), path: \(url.pathComponents)")
            return false
        }

        // Extract workout type from query parameters
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let typeParam = components.queryItems?.first(where: { $0.name == "type" })?.value,
              let workoutType = WorkoutType(rawValue: typeParam) else {
            print("QuickStartState: Could not parse workout type from URL")
            return false
        }

        print("QuickStartState: Setting pending workout type to \(workoutType.displayName)")
        pendingWorkoutType = workoutType
        showQuickStartPicker = true
        return true
    }

    /// Clears the pending workout state
    func clear() {
        pendingWorkoutType = nil
        showQuickStartPicker = false
    }
}
