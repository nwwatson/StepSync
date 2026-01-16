import Foundation
import SwiftData

@Model
public final class UserSettings {
    public var id: UUID = UUID()
    public var dailyReminderEnabled: Bool = true
    public var dailyReminderTime: Date = Calendar.current.date(from: DateComponents(hour: 8, minute: 0)) ?? Date()
    public var streakReminderEnabled: Bool = true
    public var streakReminderTime: Date = Calendar.current.date(from: DateComponents(hour: 19, minute: 0)) ?? Date()
    public var inactivityReminderEnabled: Bool = true
    public var inactivityReminderTime: Date = Calendar.current.date(from: DateComponents(hour: 14, minute: 0)) ?? Date()
    public var goalAchievedNotificationEnabled: Bool = true
    public var useMetricUnits: Bool = false
    public var hapticFeedbackEnabled: Bool = true
    public var autoDetectWorkouts: Bool = false
    public var showHeartRateDuringWorkout: Bool = true
    public var showCadenceDuringWorkout: Bool = true
    public var showPaceDuringWorkout: Bool = true
    public var createdAt: Date = Date()
    public var updatedAt: Date = Date()

    public init() {
        self.id = UUID()
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    public func update() {
        updatedAt = Date()
    }
}
