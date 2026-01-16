import Foundation

public struct PaceZone: Identifiable, Sendable {
    public let id = UUID()
    public let name: String
    public let minPace: Double
    public let maxPace: Double
    public let color: String

    public static let zones: [PaceZone] = [
        PaceZone(name: "Recovery", minPace: 15, maxPace: .infinity, color: "blue"),
        PaceZone(name: "Easy", minPace: 12, maxPace: 15, color: "green"),
        PaceZone(name: "Moderate", minPace: 10, maxPace: 12, color: "yellow"),
        PaceZone(name: "Tempo", minPace: 8, maxPace: 10, color: "orange"),
        PaceZone(name: "Speed", minPace: 0, maxPace: 8, color: "red")
    ]

    public static func zone(for pace: Double) -> PaceZone {
        zones.first { pace >= $0.minPace && pace < $0.maxPace } ?? zones[0]
    }
}

public struct StrideAnalysis {
    public let averageStrideLength: Double
    public let minStrideLength: Double
    public let maxStrideLength: Double
    public let consistency: Double

    public var formattedAverage: String {
        String(format: "%.2f m", averageStrideLength)
    }

    public var formattedRange: String {
        String(format: "%.2f - %.2f m", minStrideLength, maxStrideLength)
    }

    public var consistencyRating: String {
        if consistency >= 0.9 {
            return "Excellent"
        } else if consistency >= 0.75 {
            return "Good"
        } else if consistency >= 0.5 {
            return "Fair"
        } else {
            return "Needs Work"
        }
    }
}

public struct PersonalRecord {
    public let type: RecordType
    public let value: Double
    public let date: Date
    public let workoutId: UUID?

    public enum RecordType: String, CaseIterable {
        case longestDistance
        case fastestPace
        case mostStepsInDay
        case longestWorkout
        case highestElevationGain
        case mostCaloriesBurned

        public var displayName: String {
            switch self {
            case .longestDistance: return "Longest Distance"
            case .fastestPace: return "Fastest Pace"
            case .mostStepsInDay: return "Most Steps in a Day"
            case .longestWorkout: return "Longest Workout"
            case .highestElevationGain: return "Highest Elevation Gain"
            case .mostCaloriesBurned: return "Most Calories Burned"
            }
        }

        public var systemImage: String {
            switch self {
            case .longestDistance: return "map"
            case .fastestPace: return "speedometer"
            case .mostStepsInDay: return "shoeprints.fill"
            case .longestWorkout: return "timer"
            case .highestElevationGain: return "mountain.2"
            case .mostCaloriesBurned: return "flame"
            }
        }
    }
}

public final class TrendAnalyzer: Sendable {
    public static let shared = TrendAnalyzer()

    private init() {}

    public func analyzePaceDistribution(from workouts: [Workout]) -> [PaceZone: Int] {
        var distribution: [PaceZone: Int] = [:]

        for zone in PaceZone.zones {
            distribution[zone] = 0
        }

        for workout in workouts {
            guard let pace = workout.averagePace else { continue }
            let zone = PaceZone.zone(for: pace / 60)
            distribution[zone, default: 0] += 1
        }

        return distribution
    }

    public func analyzeWeekdayPattern(from records: [DailyStepRecord]) -> [Int: Int] {
        var pattern: [Int: Int] = [:]
        var counts: [Int: Int] = [:]

        for i in 1...7 {
            pattern[i] = 0
            counts[i] = 0
        }

        let calendar = Calendar.current
        for record in records {
            let weekday = calendar.component(.weekday, from: record.date)
            pattern[weekday, default: 0] += record.stepCount
            counts[weekday, default: 0] += 1
        }

        var averages: [Int: Int] = [:]
        for (weekday, total) in pattern {
            let count = counts[weekday, default: 1]
            averages[weekday] = count > 0 ? total / count : 0
        }

        return averages
    }

    public func analyzeHourlyPattern(from workouts: [Workout]) -> [Int: Int] {
        var pattern: [Int: Int] = [:]

        for i in 0...23 {
            pattern[i] = 0
        }

        let calendar = Calendar.current
        for workout in workouts {
            let hour = calendar.component(.hour, from: workout.startDate)
            pattern[hour, default: 0] += 1
        }

        return pattern
    }

    public func calculateStrideAnalysis(from workouts: [Workout]) -> StrideAnalysis? {
        let strideLengths = workouts.compactMap { $0.averageStrideLength }

        guard !strideLengths.isEmpty else { return nil }

        let average = strideLengths.reduce(0, +) / Double(strideLengths.count)
        let minStride = strideLengths.min() ?? 0
        let maxStride = strideLengths.max() ?? 0

        let variance = strideLengths.reduce(0) { $0 + pow($1 - average, 2) } / Double(strideLengths.count)
        let standardDeviation = sqrt(variance)
        let coefficientOfVariation = average > 0 ? standardDeviation / average : 0
        let consistency = 1 - Swift.min(coefficientOfVariation, 1)

        return StrideAnalysis(
            averageStrideLength: average,
            minStrideLength: minStride,
            maxStrideLength: maxStride,
            consistency: consistency
        )
    }

    public func findPersonalRecords(from records: [DailyStepRecord], workouts: [Workout]) -> [PersonalRecord] {
        var personalRecords: [PersonalRecord] = []

        if let bestStepDay = records.max(by: { $0.stepCount < $1.stepCount }) {
            personalRecords.append(PersonalRecord(
                type: .mostStepsInDay,
                value: Double(bestStepDay.stepCount),
                date: bestStepDay.date,
                workoutId: nil
            ))
        }

        if let longestWorkout = workouts.max(by: { $0.duration < $1.duration }) {
            personalRecords.append(PersonalRecord(
                type: .longestWorkout,
                value: longestWorkout.duration,
                date: longestWorkout.startDate,
                workoutId: longestWorkout.id
            ))
        }

        if let longestDistance = workouts.max(by: { $0.distance < $1.distance }) {
            personalRecords.append(PersonalRecord(
                type: .longestDistance,
                value: longestDistance.distance,
                date: longestDistance.startDate,
                workoutId: longestDistance.id
            ))
        }

        let workoutsWithPace = workouts.filter { $0.averagePace != nil && $0.averagePace! > 0 }
        if let fastestPace = workoutsWithPace.min(by: { ($0.averagePace ?? .infinity) < ($1.averagePace ?? .infinity) }) {
            personalRecords.append(PersonalRecord(
                type: .fastestPace,
                value: fastestPace.averagePace ?? 0,
                date: fastestPace.startDate,
                workoutId: fastestPace.id
            ))
        }

        let workoutsWithElevation = workouts.filter { $0.elevationGain != nil && $0.elevationGain! > 0 }
        if let highestElevation = workoutsWithElevation.max(by: { ($0.elevationGain ?? 0) < ($1.elevationGain ?? 0) }) {
            personalRecords.append(PersonalRecord(
                type: .highestElevationGain,
                value: highestElevation.elevationGain ?? 0,
                date: highestElevation.startDate,
                workoutId: highestElevation.id
            ))
        }

        if let mostCalories = workouts.max(by: { $0.activeCalories < $1.activeCalories }) {
            personalRecords.append(PersonalRecord(
                type: .mostCaloriesBurned,
                value: mostCalories.activeCalories,
                date: mostCalories.startDate,
                workoutId: mostCalories.id
            ))
        }

        return personalRecords
    }

    public func calculateWeekOverWeekChange(currentWeek: [DailyStepRecord], previousWeek: [DailyStepRecord]) -> Double {
        let currentTotal = currentWeek.reduce(0) { $0 + $1.stepCount }
        let previousTotal = previousWeek.reduce(0) { $0 + $1.stepCount }

        guard previousTotal > 0 else { return 0 }

        return Double(currentTotal - previousTotal) / Double(previousTotal) * 100
    }
}

extension PaceZone: Hashable {
    public static func == (lhs: PaceZone, rhs: PaceZone) -> Bool {
        lhs.name == rhs.name
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }
}
