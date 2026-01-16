import Foundation
import SwiftData

@Model
public final class HeartRateSample {
    public var id: UUID = UUID()
    public var beatsPerMinute: Double = 0.0
    public var timestamp: Date = Date()

    public var workout: Workout?

    public init(
        beatsPerMinute: Double,
        timestamp: Date = Date()
    ) {
        self.id = UUID()
        self.beatsPerMinute = beatsPerMinute
        self.timestamp = timestamp
    }
}
