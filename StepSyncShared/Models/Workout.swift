import Foundation
import SwiftData

public enum WorkoutType: String, Codable, CaseIterable, Sendable {
    case walking
    case running

    public var displayName: String {
        switch self {
        case .walking: return "Walking"
        case .running: return "Running"
        }
    }

    public var systemImage: String {
        switch self {
        case .walking: return "figure.walk"
        case .running: return "figure.run"
        }
    }
}

public enum WorkoutEnvironment: String, Codable, CaseIterable, Sendable {
    case outdoor
    case indoor

    public var displayName: String {
        switch self {
        case .outdoor: return "Outdoor"
        case .indoor: return "Indoor"
        }
    }
}

@Model
public final class Workout {
    public var id: UUID = UUID()
    public var workoutTypeRaw: String = WorkoutType.walking.rawValue
    public var environmentRaw: String = WorkoutEnvironment.outdoor.rawValue
    public var startDate: Date = Date()
    public var endDate: Date?
    public var duration: TimeInterval = 0
    public var distance: Double = 0.0
    public var stepCount: Int = 0
    public var activeCalories: Double = 0.0
    public var averageHeartRate: Double?
    public var maxHeartRate: Double?
    public var averagePace: Double?
    public var averageCadence: Double?
    public var averageStrideLength: Double?
    public var elevationGain: Double?
    public var healthKitWorkoutID: UUID?
    public var isCompleted: Bool = false
    public var notes: String?
    public var createdAt: Date = Date()
    public var updatedAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \WorkoutRoutePoint.workout)
    public var routePoints: [WorkoutRoutePoint]?

    @Relationship(deleteRule: .cascade, inverse: \HeartRateSample.workout)
    public var heartRateSamples: [HeartRateSample]?

    public init(
        type: WorkoutType = .walking,
        environment: WorkoutEnvironment = .outdoor,
        startDate: Date = Date()
    ) {
        self.id = UUID()
        self.workoutTypeRaw = type.rawValue
        self.environmentRaw = environment.rawValue
        self.startDate = startDate
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    public var workoutType: WorkoutType {
        get { WorkoutType(rawValue: workoutTypeRaw) ?? .walking }
        set { workoutTypeRaw = newValue.rawValue }
    }

    public var environment: WorkoutEnvironment {
        get { WorkoutEnvironment(rawValue: environmentRaw) ?? .outdoor }
        set { environmentRaw = newValue.rawValue }
    }

    public var formattedDuration: String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }

    public var formattedDistance: String {
        let distanceInMiles = distance / 1609.34
        return String(format: "%.2f mi", distanceInMiles)
    }

    public var formattedPace: String? {
        guard let pace = averagePace, pace > 0 else { return nil }
        let paceMinutes = Int(pace) / 60
        let paceSeconds = Int(pace) % 60
        return String(format: "%d'%02d\"/mi", paceMinutes, paceSeconds)
    }

    /// Marks the workout as completed.
    /// - Parameters:
    ///   - endDate: The end date of the workout. Defaults to now.
    ///   - preserveDuration: If true, keeps the existing duration value (useful when duration
    ///                       is set from HealthKit which accounts for pauses). If false, calculates
    ///                       duration from startDate to endDate.
    public func complete(endDate: Date = Date(), preserveDuration: Bool = false) {
        self.endDate = endDate
        if !preserveDuration || self.duration == 0 {
            self.duration = endDate.timeIntervalSince(startDate)
        }
        self.isCompleted = true
        self.updatedAt = Date()
    }
}
