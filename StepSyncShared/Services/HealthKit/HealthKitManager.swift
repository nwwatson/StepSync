import Foundation
import HealthKit
import Observation

@Observable
public final class HealthKitManager: @unchecked Sendable {
    public static let shared = HealthKitManager()

    private let healthStore = HKHealthStore()
    public private(set) var isAuthorized = false
    public private(set) var authorizationError: Error?

    private init() {}

    public var isHealthDataAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    public static let readTypes: Set<HKObjectType> = {
        var types = Set<HKObjectType>()

        if let stepCount = HKQuantityType.quantityType(forIdentifier: .stepCount) {
            types.insert(stepCount)
        }
        if let heartRate = HKQuantityType.quantityType(forIdentifier: .heartRate) {
            types.insert(heartRate)
        }
        if let walkingStepLength = HKQuantityType.quantityType(forIdentifier: .walkingStepLength) {
            types.insert(walkingStepLength)
        }
        if let walkingSpeed = HKQuantityType.quantityType(forIdentifier: .walkingSpeed) {
            types.insert(walkingSpeed)
        }
        if let distance = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning) {
            types.insert(distance)
        }
        if let activeEnergy = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
            types.insert(activeEnergy)
        }
        if let runningStrideLength = HKQuantityType.quantityType(forIdentifier: .runningStrideLength) {
            types.insert(runningStrideLength)
        }

        types.insert(HKObjectType.workoutType())
        types.insert(HKSeriesType.workoutRoute())

        return types
    }()

    public static let writeTypes: Set<HKSampleType> = {
        var types = Set<HKSampleType>()

        if let stepCount = HKQuantityType.quantityType(forIdentifier: .stepCount) {
            types.insert(stepCount)
        }
        if let distance = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning) {
            types.insert(distance)
        }
        if let activeEnergy = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
            types.insert(activeEnergy)
        }

        types.insert(HKObjectType.workoutType())

        return types
    }()

    public func requestAuthorization() async throws {
        guard isHealthDataAvailable else {
            throw HealthKitError.notAvailable
        }

        do {
            try await healthStore.requestAuthorization(toShare: Self.writeTypes, read: Self.readTypes)
            // Check if we actually have read access to step count
            if let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) {
                let status = healthStore.authorizationStatus(for: stepType)
                // Note: .sharingAuthorized only tells us about write access
                // For read access, we need to try a query - authorization status for read is always .notDetermined
                // We'll set isAuthorized to true and let queries fail if not authorized
                isAuthorized = true
                print("HealthKitManager: Authorization requested, step count write status: \(status.rawValue)")
            }
            authorizationError = nil
        } catch {
            authorizationError = error
            isAuthorized = false
            throw error
        }
    }

    /// Enables background delivery for step count updates (call after authorization)
    public func enableBackgroundDelivery() async {
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return }

        do {
            try await healthStore.enableBackgroundDelivery(for: stepType, frequency: .immediate)
            print("HealthKitManager: Background delivery enabled for step count")
        } catch {
            print("HealthKitManager: Failed to enable background delivery: \(error)")
        }
    }

    public func getAuthorizationStatus(for type: HKObjectType) -> HKAuthorizationStatus {
        healthStore.authorizationStatus(for: type)
    }

    public func getStepCount(for date: Date) async throws -> Int {
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
            throw HealthKitError.invalidType
        }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: .strictStartDate)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: stepType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                let steps = result?.sumQuantity()?.doubleValue(for: HKUnit.count()) ?? 0
                continuation.resume(returning: Int(steps))
            }

            healthStore.execute(query)
        }
    }

    public func getStepCounts(from startDate: Date, to endDate: Date) async throws -> [Date: Int] {
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
            throw HealthKitError.invalidType
        }

        let calendar = Calendar.current
        let start = calendar.startOfDay(for: startDate)
        let end = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: endDate)!)

        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let interval = DateComponents(day: 1)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsCollectionQuery(
                quantityType: stepType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum,
                anchorDate: start,
                intervalComponents: interval
            )

            query.initialResultsHandler = { _, results, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                var stepsByDate: [Date: Int] = [:]

                results?.enumerateStatistics(from: start, to: end) { statistics, _ in
                    let steps = statistics.sumQuantity()?.doubleValue(for: HKUnit.count()) ?? 0
                    let date = calendar.startOfDay(for: statistics.startDate)
                    stepsByDate[date] = Int(steps)
                }

                continuation.resume(returning: stepsByDate)
            }

            healthStore.execute(query)
        }
    }

    public func getDistance(for date: Date) async throws -> Double {
        guard let distanceType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning) else {
            throw HealthKitError.invalidType
        }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: .strictStartDate)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: distanceType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                let distance = result?.sumQuantity()?.doubleValue(for: HKUnit.meter()) ?? 0
                continuation.resume(returning: distance)
            }

            healthStore.execute(query)
        }
    }

    public func getActiveCalories(for date: Date) async throws -> Double {
        guard let calorieType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else {
            throw HealthKitError.invalidType
        }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: .strictStartDate)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: calorieType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                let calories = result?.sumQuantity()?.doubleValue(for: HKUnit.kilocalorie()) ?? 0
                continuation.resume(returning: calories)
            }

            healthStore.execute(query)
        }
    }

    public func getAverageWalkingSpeed(for date: Date) async throws -> Double? {
        guard let speedType = HKQuantityType.quantityType(forIdentifier: .walkingSpeed) else {
            throw HealthKitError.invalidType
        }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: .strictStartDate)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: speedType,
                quantitySamplePredicate: predicate,
                options: .discreteAverage
            ) { _, result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                let speed = result?.averageQuantity()?.doubleValue(for: HKUnit.meter().unitDivided(by: HKUnit.second()))
                continuation.resume(returning: speed)
            }

            healthStore.execute(query)
        }
    }

    public func getAverageStepLength(for date: Date) async throws -> Double? {
        guard let stepLengthType = HKQuantityType.quantityType(forIdentifier: .walkingStepLength) else {
            throw HealthKitError.invalidType
        }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: .strictStartDate)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: stepLengthType,
                quantitySamplePredicate: predicate,
                options: .discreteAverage
            ) { _, result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                let stepLength = result?.averageQuantity()?.doubleValue(for: HKUnit.meter())
                continuation.resume(returning: stepLength)
            }

            healthStore.execute(query)
        }
    }

    public func suggestInitialStepGoal() async throws -> Int {
        let calendar = Calendar.current
        let endDate = Date()
        guard let startDate = calendar.date(byAdding: .day, value: -30, to: endDate) else {
            return 10000
        }

        let stepsByDate = try await getStepCounts(from: startDate, to: endDate)
        let stepCounts = stepsByDate.values.sorted()

        guard !stepCounts.isEmpty else {
            return 10000
        }

        let percentileIndex = Int(Double(stepCounts.count) * 0.75)
        let suggestedGoal = stepCounts[min(percentileIndex, stepCounts.count - 1)]

        let roundedGoal = ((suggestedGoal + 250) / 500) * 500
        return max(StepGoal.minimumGoal, min(roundedGoal, StepGoal.maximumGoal))
    }

    public func observeStepCount(updateHandler: @escaping @Sendable (Int) -> Void) -> HKObserverQuery? {
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
            return nil
        }

        let query = HKObserverQuery(sampleType: stepType, predicate: nil) { [weak self] _, completionHandler, error in
            guard error == nil else {
                completionHandler()
                return
            }

            // Fetch step count on background queue and dispatch result to main actor
            guard let self = self else {
                completionHandler()
                return
            }

            let healthStore = self.healthStore
            let calendar = Calendar.current
            let startOfDay = calendar.startOfDay(for: Date())
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
            let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: .strictStartDate)

            let statsQuery = HKStatisticsQuery(
                quantityType: stepType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, result, _ in
                let steps = Int(result?.sumQuantity()?.doubleValue(for: HKUnit.count()) ?? 0)
                DispatchQueue.main.async {
                    updateHandler(steps)
                }
                completionHandler()
            }

            healthStore.execute(statsQuery)
        }

        healthStore.execute(query)
        return query
    }

    public func stopObserving(query: HKQuery) {
        healthStore.stop(query)
    }

    // MARK: - Workout Queries

    /// Represents a workout retrieved from HealthKit
    public struct HealthKitWorkout: Sendable {
        public let uuid: UUID
        public let workoutType: WorkoutType
        public let environment: WorkoutEnvironment
        public let startDate: Date
        public let endDate: Date
        public let duration: TimeInterval
        public let distance: Double // in meters
        public let activeCalories: Double
        public let stepCount: Int

        public init(
            uuid: UUID,
            workoutType: WorkoutType,
            environment: WorkoutEnvironment,
            startDate: Date,
            endDate: Date,
            duration: TimeInterval,
            distance: Double,
            activeCalories: Double,
            stepCount: Int
        ) {
            self.uuid = uuid
            self.workoutType = workoutType
            self.environment = environment
            self.startDate = startDate
            self.endDate = endDate
            self.duration = duration
            self.distance = distance
            self.activeCalories = activeCalories
            self.stepCount = stepCount
        }
    }

    /// Fetches walking and running workouts from HealthKit for the specified date range
    /// - Parameters:
    ///   - startDate: The start date of the range
    ///   - endDate: The end date of the range (defaults to now)
    /// - Returns: Array of HealthKitWorkout objects
    public func getWorkouts(from startDate: Date, to endDate: Date = Date()) async throws -> [HealthKitWorkout] {
        let workoutType = HKObjectType.workoutType()

        // Create predicate for date range and activity types (walking and running)
        let datePredicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let walkingPredicate = HKQuery.predicateForWorkouts(with: .walking)
        let runningPredicate = HKQuery.predicateForWorkouts(with: .running)
        let activityPredicate = NSCompoundPredicate(orPredicateWithSubpredicates: [walkingPredicate, runningPredicate])
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [datePredicate, activityPredicate])

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: workoutType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
            ) { _, samples, error in
                if let error = error {
                    print("HealthKitManager: Failed to fetch workouts: \(error)")
                    continuation.resume(throwing: HealthKitError.queryFailed(error))
                    return
                }

                guard let workouts = samples as? [HKWorkout] else {
                    continuation.resume(returning: [])
                    return
                }

                let healthKitWorkouts = workouts.map { workout -> HealthKitWorkout in
                    // Determine workout type
                    let type: WorkoutType = workout.workoutActivityType == .running ? .running : .walking

                    // Determine environment (indoor/outdoor)
                    let environment: WorkoutEnvironment
                    if let metadata = workout.metadata,
                       let indoorWorkout = metadata[HKMetadataKeyIndoorWorkout] as? Bool {
                        environment = indoorWorkout ? .indoor : .outdoor
                    } else {
                        environment = .outdoor // Default to outdoor
                    }

                    // Get distance
                    let distance: Double
                    if let distanceQuantity = workout.statistics(for: HKQuantityType(.distanceWalkingRunning))?.sumQuantity() {
                        distance = distanceQuantity.doubleValue(for: .meter())
                    } else {
                        distance = 0
                    }

                    // Get calories
                    let calories: Double
                    if let caloriesQuantity = workout.statistics(for: HKQuantityType(.activeEnergyBurned))?.sumQuantity() {
                        calories = caloriesQuantity.doubleValue(for: .kilocalorie())
                    } else {
                        calories = 0
                    }

                    // Get step count
                    let stepCount: Int
                    if let stepsQuantity = workout.statistics(for: HKQuantityType(.stepCount))?.sumQuantity() {
                        stepCount = Int(stepsQuantity.doubleValue(for: .count()))
                    } else {
                        stepCount = 0
                    }

                    return HealthKitWorkout(
                        uuid: workout.uuid,
                        workoutType: type,
                        environment: environment,
                        startDate: workout.startDate,
                        endDate: workout.endDate,
                        duration: workout.duration,
                        distance: distance,
                        activeCalories: calories,
                        stepCount: stepCount
                    )
                }

                print("HealthKitManager: Found \(healthKitWorkouts.count) workouts in HealthKit")
                continuation.resume(returning: healthKitWorkouts)
            }

            healthStore.execute(query)
        }
    }

    /// Fetches workouts from the last N days
    public func getRecentWorkouts(days: Int = 30) async throws -> [HealthKitWorkout] {
        let calendar = Calendar.current
        guard let startDate = calendar.date(byAdding: .day, value: -days, to: Date()) else {
            return []
        }
        return try await getWorkouts(from: startDate)
    }
}

public enum HealthKitError: LocalizedError {
    case notAvailable
    case notAuthorized
    case invalidType
    case queryFailed(Error)

    public var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "HealthKit is not available on this device"
        case .notAuthorized:
            return "HealthKit access has not been authorized"
        case .invalidType:
            return "Invalid HealthKit data type"
        case .queryFailed(let error):
            return "HealthKit query failed: \(error.localizedDescription)"
        }
    }
}
