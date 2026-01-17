import Foundation
import WatchConnectivity
import Observation

/// Commands that can be sent between iPhone and Watch
public enum WatchCommand: String, Codable {
    case startWorkout
    case pauseWorkout
    case resumeWorkout
    case endWorkout
    case workoutStarted
    case workoutEnded
    case error
}

/// Data sent with workout commands
public struct WorkoutCommandData: Codable {
    public let command: WatchCommand
    public let workoutType: String?
    public let workoutEnvironment: String?
    public let errorMessage: String?

    public init(
        command: WatchCommand,
        workoutType: String? = nil,
        workoutEnvironment: String? = nil,
        errorMessage: String? = nil
    ) {
        self.command = command
        self.workoutType = workoutType
        self.workoutEnvironment = workoutEnvironment
        self.errorMessage = errorMessage
    }
}

/// Manages WatchConnectivity communication between iPhone and Apple Watch
@Observable
public final class WatchConnectivityManager: NSObject, @unchecked Sendable {
    public static let shared = WatchConnectivityManager()

    private var session: WCSession?

    public private(set) var isReachable = false
    public private(set) var isPaired = false
    public private(set) var isWatchAppInstalled = false
    public private(set) var activationState: WCSessionActivationState = .notActivated
    public private(set) var lastError: Error?

    /// Returns current live state from session (for debugging)
    public var liveSessionState: String {
        guard let session = session else { return "No session" }
        var parts: [String] = []
        parts.append("activated: \(session.activationState == .activated)")
        parts.append("reachable: \(session.isReachable)")
        #if os(iOS)
        parts.append("paired: \(session.isPaired)")
        parts.append("installed: \(session.isWatchAppInstalled)")
        #endif
        return parts.joined(separator: ", ")
    }

    /// Callback for when a workout command is received (used on Watch)
    public var onWorkoutCommandReceived: ((WorkoutCommandData) -> Void)?

    /// Callback for when workout started confirmation is received (used on iPhone)
    public var onWorkoutStartedConfirmation: ((Bool, String?) -> Void)?

    private override init() {
        super.init()
        setupSession()
    }

    private func setupSession() {
        guard WCSession.isSupported() else {
            print("WatchConnectivityManager: WCSession not supported on this device")
            return
        }

        session = WCSession.default
        session?.delegate = self
        session?.activate()

        print("WatchConnectivityManager: Session activation requested")
    }

    /// Check if the Watch is reachable for immediate messaging
    public var canSendMessage: Bool {
        guard let session = session else { return false }
        return session.isReachable
    }

    #if os(iOS)
    /// Check if Watch app is installed and paired (iOS only)
    public var isWatchReady: Bool {
        guard let session = session else { return false }
        return session.isPaired && session.isWatchAppInstalled
    }
    #endif

    // MARK: - Sending Commands

    /// Send a command to start a workout on the Watch
    public func sendStartWorkoutCommand(type: WorkoutType, environment: WorkoutEnvironment) async throws {
        let commandData = WorkoutCommandData(
            command: .startWorkout,
            workoutType: type.rawValue,
            workoutEnvironment: environment.rawValue
        )

        try await sendCommand(commandData)
    }

    /// Send a command to pause the workout
    public func sendPauseWorkoutCommand() async throws {
        let commandData = WorkoutCommandData(command: .pauseWorkout)
        try await sendCommand(commandData)
    }

    /// Send a command to resume the workout
    public func sendResumeWorkoutCommand() async throws {
        let commandData = WorkoutCommandData(command: .resumeWorkout)
        try await sendCommand(commandData)
    }

    /// Send a command to end the workout
    public func sendEndWorkoutCommand() async throws {
        let commandData = WorkoutCommandData(command: .endWorkout)
        try await sendCommand(commandData)
    }

    /// Send confirmation that workout started successfully (from Watch to iPhone)
    public func sendWorkoutStartedConfirmation(success: Bool, errorMessage: String? = nil) {
        let commandData = WorkoutCommandData(
            command: success ? .workoutStarted : .error,
            errorMessage: errorMessage
        )

        guard let data = try? JSONEncoder().encode(commandData) else { return }
        let message = ["workoutCommand": data]

        session?.sendMessage(message, replyHandler: nil) { error in
            print("WatchConnectivityManager: Failed to send confirmation: \(error)")
        }
    }

    /// Send a command with reply handling
    private func sendCommand(_ commandData: WorkoutCommandData) async throws {
        guard let session = session else {
            throw WatchConnectivityError.sessionNotAvailable
        }

        guard session.activationState == .activated else {
            throw WatchConnectivityError.sessionNotActivated
        }

        #if os(iOS)
        guard session.isPaired else {
            throw WatchConnectivityError.watchNotPaired
        }

        guard session.isWatchAppInstalled else {
            throw WatchConnectivityError.watchAppNotInstalled
        }
        #endif

        guard session.isReachable else {
            throw WatchConnectivityError.watchNotReachable
        }

        guard let data = try? JSONEncoder().encode(commandData) else {
            throw WatchConnectivityError.encodingFailed
        }

        let message = ["workoutCommand": data]

        return try await withCheckedThrowingContinuation { continuation in
            session.sendMessage(message, replyHandler: { reply in
                // Check if reply contains success/error
                if let responseData = reply["response"] as? Data,
                   let response = try? JSONDecoder().decode(WorkoutCommandData.self, from: responseData) {
                    if response.command == .error {
                        continuation.resume(throwing: WatchConnectivityError.commandFailed(response.errorMessage ?? "Unknown error"))
                    } else {
                        continuation.resume()
                    }
                } else {
                    continuation.resume()
                }
            }, errorHandler: { error in
                continuation.resume(throwing: WatchConnectivityError.sendFailed(error))
            })
        }
    }
}

// MARK: - WCSessionDelegate

extension WatchConnectivityManager: WCSessionDelegate {
    public func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        // Capture values before async dispatch to avoid data race
        let capturedActivationState = activationState
        let isReachable = session.isReachable
        #if os(iOS)
        let isPaired = session.isPaired
        let isWatchAppInstalled = session.isWatchAppInstalled
        #endif

        DispatchQueue.main.async { [weak self] in
            self?.activationState = capturedActivationState

            if let error = error {
                self?.lastError = error
                print("WatchConnectivityManager: Activation failed: \(error)")
            } else {
                print("WatchConnectivityManager: Session activated with state: \(capturedActivationState.rawValue)")
                self?.isReachable = isReachable
                #if os(iOS)
                self?.isPaired = isPaired
                self?.isWatchAppInstalled = isWatchAppInstalled
                print("WatchConnectivityManager: State updated - paired: \(isPaired), installed: \(isWatchAppInstalled), reachable: \(isReachable)")
                #else
                print("WatchConnectivityManager: State updated - reachable: \(isReachable)")
                #endif
            }
        }
    }

    #if os(iOS)
    public func sessionDidBecomeInactive(_ session: WCSession) {
        print("WatchConnectivityManager: Session became inactive")
    }

    public func sessionDidDeactivate(_ session: WCSession) {
        print("WatchConnectivityManager: Session deactivated")
        // Reactivate for switching watches
        WCSession.default.activate()
    }

    public func sessionWatchStateDidChange(_ session: WCSession) {
        // Capture values before async dispatch
        let isReachable = session.isReachable
        let isPaired = session.isPaired
        let isWatchAppInstalled = session.isWatchAppInstalled

        DispatchQueue.main.async { [weak self] in
            self?.isReachable = isReachable
            self?.isPaired = isPaired
            self?.isWatchAppInstalled = isWatchAppInstalled
            print("WatchConnectivityManager: State updated - paired: \(isPaired), installed: \(isWatchAppInstalled), reachable: \(isReachable)")
        }
    }
    #endif

    public func sessionReachabilityDidChange(_ session: WCSession) {
        // Capture value before async dispatch
        let isReachable = session.isReachable

        DispatchQueue.main.async { [weak self] in
            self?.isReachable = isReachable
            print("WatchConnectivityManager: Reachability changed: \(isReachable)")
        }
    }

    public func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        handleReceivedMessage(message, replyHandler: nil)
    }

    public func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        handleReceivedMessage(message, replyHandler: replyHandler)
    }

    private func handleReceivedMessage(_ message: [String: Any], replyHandler: (([String: Any]) -> Void)?) {
        guard let data = message["workoutCommand"] as? Data,
              let commandData = try? JSONDecoder().decode(WorkoutCommandData.self, from: data) else {
            print("WatchConnectivityManager: Failed to decode message")
            return
        }

        print("WatchConnectivityManager: Received command: \(commandData.command)")

        DispatchQueue.main.async { [weak self] in
            switch commandData.command {
            case .startWorkout, .pauseWorkout, .resumeWorkout, .endWorkout:
                // Forward to the workout command handler (used on Watch)
                self?.onWorkoutCommandReceived?(commandData)

            case .workoutStarted:
                // Confirmation received (used on iPhone)
                self?.onWorkoutStartedConfirmation?(true, nil)

            case .error:
                // Error received
                self?.onWorkoutStartedConfirmation?(false, commandData.errorMessage)

            case .workoutEnded:
                break
            }
        }

        // Send acknowledgment if reply handler provided
        if let replyHandler = replyHandler {
            let ack = WorkoutCommandData(command: .workoutStarted)
            if let ackData = try? JSONEncoder().encode(ack) {
                replyHandler(["response": ackData])
            } else {
                replyHandler([:])
            }
        }
    }
}

// MARK: - Errors

public enum WatchConnectivityError: LocalizedError {
    case sessionNotAvailable
    case sessionNotActivated
    case watchNotPaired
    case watchAppNotInstalled
    case watchNotReachable
    case encodingFailed
    case sendFailed(Error)
    case commandFailed(String)

    public var errorDescription: String? {
        switch self {
        case .sessionNotAvailable:
            return "WatchConnectivity session is not available"
        case .sessionNotActivated:
            return "WatchConnectivity session is not activated"
        case .watchNotPaired:
            return "Apple Watch is not paired with this iPhone"
        case .watchAppNotInstalled:
            return "StepSync is not installed on your Apple Watch"
        case .watchNotReachable:
            return "Apple Watch is not reachable. Make sure it's nearby and unlocked."
        case .encodingFailed:
            return "Failed to encode command data"
        case .sendFailed(let error):
            return "Failed to send command: \(error.localizedDescription)"
        case .commandFailed(let message):
            return message
        }
    }
}
