import Foundation
import SwiftData

@Model
public final class Streak {
    public var id: UUID = UUID()
    public var currentStreak: Int = 0
    public var longestStreak: Int = 0
    public var lastActiveDate: Date?
    public var streakStartDate: Date?
    public var totalDaysActive: Int = 0
    public var createdAt: Date = Date()
    public var updatedAt: Date = Date()

    public init() {
        self.id = UUID()
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    public func recordActivity(on date: Date = Date()) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: date)

        if let lastDate = lastActiveDate {
            let lastDay = calendar.startOfDay(for: lastDate)
            let daysBetween = calendar.dateComponents([.day], from: lastDay, to: today).day ?? 0

            if daysBetween == 0 {
                return
            } else if daysBetween == 1 {
                currentStreak += 1
            } else {
                currentStreak = 1
                streakStartDate = today
            }
        } else {
            currentStreak = 1
            streakStartDate = today
        }

        lastActiveDate = today
        totalDaysActive += 1

        if currentStreak > longestStreak {
            longestStreak = currentStreak
        }

        updatedAt = Date()
    }

    public func checkAndBreakStreak(for date: Date = Date()) {
        guard let lastDate = lastActiveDate else { return }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: date)
        let lastDay = calendar.startOfDay(for: lastDate)
        let daysBetween = calendar.dateComponents([.day], from: lastDay, to: today).day ?? 0

        if daysBetween > 1 {
            currentStreak = 0
            streakStartDate = nil
            updatedAt = Date()
        }
    }

    public var isActiveToday: Bool {
        guard let lastDate = lastActiveDate else { return false }
        return Calendar.current.isDateInToday(lastDate)
    }

    public var streakStatus: StreakStatus {
        if currentStreak == 0 {
            return .inactive
        } else if currentStreak >= 30 {
            return .onFire
        } else if currentStreak >= 7 {
            return .strong
        } else {
            return .building
        }
    }
}

public enum StreakStatus: String {
    case inactive
    case building
    case strong
    case onFire

    public var displayName: String {
        switch self {
        case .inactive: return "Start your streak!"
        case .building: return "Building momentum"
        case .strong: return "Strong streak"
        case .onFire: return "You're on fire!"
        }
    }

    public var systemImage: String {
        switch self {
        case .inactive: return "flame"
        case .building: return "flame.fill"
        case .strong: return "flame.circle"
        case .onFire: return "flame.circle.fill"
        }
    }
}
