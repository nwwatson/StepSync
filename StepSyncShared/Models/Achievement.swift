import Foundation
import SwiftData

public enum AchievementType: String, Codable, CaseIterable {
    case firstSteps
    case firstWorkout
    case first5KWalk
    case first10KWalk
    case first5KRun
    case first10KRun
    case weeklyStreak
    case monthlyStreak
    case yearlyStreak
    case stepMilestone10K
    case stepMilestone50K
    case stepMilestone100K
    case stepMilestone500K
    case stepMilestone1M
    case goalAchiever7Days
    case goalAchiever30Days
    case goalAchiever100Days
    case earlyBird
    case nightOwl
    case weekendWarrior
    case consistencyKing
    case speedDemon
    case marathoner
    case centurion

    public var displayName: String {
        switch self {
        case .firstSteps: return "First Steps"
        case .firstWorkout: return "First Workout"
        case .first5KWalk: return "5K Walker"
        case .first10KWalk: return "10K Walker"
        case .first5KRun: return "5K Runner"
        case .first10KRun: return "10K Runner"
        case .weeklyStreak: return "Week Warrior"
        case .monthlyStreak: return "Month Master"
        case .yearlyStreak: return "Year Legend"
        case .stepMilestone10K: return "10K Steps Club"
        case .stepMilestone50K: return "50K Steps Club"
        case .stepMilestone100K: return "100K Steps Club"
        case .stepMilestone500K: return "500K Steps Club"
        case .stepMilestone1M: return "Million Step Legend"
        case .goalAchiever7Days: return "Goal Achiever"
        case .goalAchiever30Days: return "Goal Master"
        case .goalAchiever100Days: return "Goal Legend"
        case .earlyBird: return "Early Bird"
        case .nightOwl: return "Night Owl"
        case .weekendWarrior: return "Weekend Warrior"
        case .consistencyKing: return "Consistency King"
        case .speedDemon: return "Speed Demon"
        case .marathoner: return "Marathoner"
        case .centurion: return "Centurion"
        }
    }

    public var description: String {
        switch self {
        case .firstSteps: return "Take your first 100 steps"
        case .firstWorkout: return "Complete your first workout"
        case .first5KWalk: return "Complete a 5K walking workout"
        case .first10KWalk: return "Complete a 10K walking workout"
        case .first5KRun: return "Complete a 5K running workout"
        case .first10KRun: return "Complete a 10K running workout"
        case .weeklyStreak: return "Achieve your goal for 7 consecutive days"
        case .monthlyStreak: return "Achieve your goal for 30 consecutive days"
        case .yearlyStreak: return "Achieve your goal for 365 consecutive days"
        case .stepMilestone10K: return "Walk 10,000 total steps"
        case .stepMilestone50K: return "Walk 50,000 total steps"
        case .stepMilestone100K: return "Walk 100,000 total steps"
        case .stepMilestone500K: return "Walk 500,000 total steps"
        case .stepMilestone1M: return "Walk 1,000,000 total steps"
        case .goalAchiever7Days: return "Achieve your daily goal 7 times"
        case .goalAchiever30Days: return "Achieve your daily goal 30 times"
        case .goalAchiever100Days: return "Achieve your daily goal 100 times"
        case .earlyBird: return "Start a workout before 6 AM"
        case .nightOwl: return "Complete a workout after 10 PM"
        case .weekendWarrior: return "Complete 10 weekend workouts"
        case .consistencyKing: return "Work out every day for a month"
        case .speedDemon: return "Achieve a pace under 7 min/mile"
        case .marathoner: return "Walk or run 26.2 miles in a single workout"
        case .centurion: return "Complete 100 workouts"
        }
    }

    public var systemImage: String {
        switch self {
        case .firstSteps: return "shoeprints.fill"
        case .firstWorkout: return "figure.walk"
        case .first5KWalk, .first10KWalk: return "figure.walk.circle.fill"
        case .first5KRun, .first10KRun: return "figure.run.circle.fill"
        case .weeklyStreak: return "flame.fill"
        case .monthlyStreak: return "flame.circle.fill"
        case .yearlyStreak: return "star.circle.fill"
        case .stepMilestone10K, .stepMilestone50K, .stepMilestone100K, .stepMilestone500K, .stepMilestone1M: return "trophy.fill"
        case .goalAchiever7Days, .goalAchiever30Days, .goalAchiever100Days: return "target"
        case .earlyBird: return "sunrise.fill"
        case .nightOwl: return "moon.stars.fill"
        case .weekendWarrior: return "calendar"
        case .consistencyKing: return "crown.fill"
        case .speedDemon: return "bolt.fill"
        case .marathoner: return "medal.fill"
        case .centurion: return "100.circle.fill"
        }
    }

    public var targetValue: Int {
        switch self {
        case .firstSteps: return 100
        case .firstWorkout: return 1
        case .first5KWalk, .first5KRun: return 5000
        case .first10KWalk, .first10KRun: return 10000
        case .weeklyStreak: return 7
        case .monthlyStreak: return 30
        case .yearlyStreak: return 365
        case .stepMilestone10K: return 10000
        case .stepMilestone50K: return 50000
        case .stepMilestone100K: return 100000
        case .stepMilestone500K: return 500000
        case .stepMilestone1M: return 1000000
        case .goalAchiever7Days: return 7
        case .goalAchiever30Days: return 30
        case .goalAchiever100Days: return 100
        case .earlyBird: return 1
        case .nightOwl: return 1
        case .weekendWarrior: return 10
        case .consistencyKing: return 30
        case .speedDemon: return 1
        case .marathoner: return 42195
        case .centurion: return 100
        }
    }
}

@Model
public final class Achievement {
    public var id: UUID = UUID()
    public var typeRaw: String = AchievementType.firstSteps.rawValue
    public var currentProgress: Int = 0
    public var isUnlocked: Bool = false
    public var unlockedDate: Date?
    public var createdAt: Date = Date()
    public var updatedAt: Date = Date()

    public init(type: AchievementType) {
        self.id = UUID()
        self.typeRaw = type.rawValue
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    public var type: AchievementType {
        get { AchievementType(rawValue: typeRaw) ?? .firstSteps }
        set { typeRaw = newValue.rawValue }
    }

    public var progressPercentage: Double {
        guard type.targetValue > 0 else { return 0 }
        return min(Double(currentProgress) / Double(type.targetValue), 1.0)
    }

    public func updateProgress(_ value: Int) {
        currentProgress = value
        if currentProgress >= type.targetValue && !isUnlocked {
            isUnlocked = true
            unlockedDate = Date()
        }
        updatedAt = Date()
    }

    public func incrementProgress(by value: Int = 1) {
        updateProgress(currentProgress + value)
    }
}
