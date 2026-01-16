import Foundation
import SwiftData

@Model
public final class WorkoutRoutePoint {
    public var id: UUID = UUID()
    public var latitude: Double = 0.0
    public var longitude: Double = 0.0
    public var altitude: Double = 0.0
    public var speed: Double = 0.0
    public var timestamp: Date = Date()
    public var horizontalAccuracy: Double = 0.0
    public var verticalAccuracy: Double = 0.0

    public var workout: Workout?

    public init(
        latitude: Double,
        longitude: Double,
        altitude: Double = 0.0,
        speed: Double = 0.0,
        timestamp: Date = Date(),
        horizontalAccuracy: Double = 0.0,
        verticalAccuracy: Double = 0.0
    ) {
        self.id = UUID()
        self.latitude = latitude
        self.longitude = longitude
        self.altitude = altitude
        self.speed = speed
        self.timestamp = timestamp
        self.horizontalAccuracy = horizontalAccuracy
        self.verticalAccuracy = verticalAccuracy
    }
}
