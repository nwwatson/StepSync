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
