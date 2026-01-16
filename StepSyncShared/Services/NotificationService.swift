import Foundation
import UserNotifications

public final class NotificationService: @unchecked Sendable {
    public static let shared = NotificationService()

    public enum NotificationCategory: String {
        case goalAchieved = "GOAL_ACHIEVED"
        case streakReminder = "STREAK_REMINDER"
        case dailyReminder = "DAILY_REMINDER"
        case inactivityReminder = "INACTIVITY_REMINDER"
    }

    public enum NotificationAction: String {
        case share = "SHARE_ACTION"
        case viewDetails = "VIEW_DETAILS"
        case startWorkout = "START_WORKOUT"
        case dismiss = "DISMISS"
    }

    private init() {}

    public func requestAuthorization() async throws -> Bool {
        let center = UNUserNotificationCenter.current()

        let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])

        if granted {
            await registerCategories()
        }

        return granted
    }

    public func registerCategories() async {
        let center = UNUserNotificationCenter.current()

        let shareAction = UNNotificationAction(
            identifier: NotificationAction.share.rawValue,
            title: "Share",
            options: []
        )

        let viewAction = UNNotificationAction(
            identifier: NotificationAction.viewDetails.rawValue,
            title: "View Details",
            options: [.foreground]
        )

        let startWorkoutAction = UNNotificationAction(
            identifier: NotificationAction.startWorkout.rawValue,
            title: "Start Workout",
            options: [.foreground]
        )

        let dismissAction = UNNotificationAction(
            identifier: NotificationAction.dismiss.rawValue,
            title: "Dismiss",
            options: [.destructive]
        )

        let goalAchievedCategory = UNNotificationCategory(
            identifier: NotificationCategory.goalAchieved.rawValue,
            actions: [shareAction, viewAction],
            intentIdentifiers: [],
            options: []
        )

        let streakReminderCategory = UNNotificationCategory(
            identifier: NotificationCategory.streakReminder.rawValue,
            actions: [startWorkoutAction, dismissAction],
            intentIdentifiers: [],
            options: []
        )

        let dailyReminderCategory = UNNotificationCategory(
            identifier: NotificationCategory.dailyReminder.rawValue,
            actions: [viewAction, dismissAction],
            intentIdentifiers: [],
            options: []
        )

        let inactivityReminderCategory = UNNotificationCategory(
            identifier: NotificationCategory.inactivityReminder.rawValue,
            actions: [startWorkoutAction, dismissAction],
            intentIdentifiers: [],
            options: []
        )

        center.setNotificationCategories([
            goalAchievedCategory,
            streakReminderCategory,
            dailyReminderCategory,
            inactivityReminderCategory
        ])
    }

    public func scheduleGoalAchievedNotification(steps: Int) async {
        let content = UNMutableNotificationContent()
        content.title = "Goal Achieved!"
        content.body = "Congratulations! You've reached \(steps.formatted()) steps today."
        content.sound = .default
        content.categoryIdentifier = NotificationCategory.goalAchieved.rawValue

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)

        let request = UNNotificationRequest(
            identifier: "goal-achieved-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )

        try? await UNUserNotificationCenter.current().add(request)
    }

    public func scheduleDailyReminder(at time: Date) async {
        let center = UNUserNotificationCenter.current()

        center.removePendingNotificationRequests(withIdentifiers: ["daily-reminder"])

        let content = UNMutableNotificationContent()
        content.title = "Daily Step Goal"
        content.body = "Start your day off right! Check your progress toward today's step goal."
        content.sound = .default
        content.categoryIdentifier = NotificationCategory.dailyReminder.rawValue

        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: time)

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)

        let request = UNNotificationRequest(
            identifier: "daily-reminder",
            content: content,
            trigger: trigger
        )

        try? await center.add(request)
    }

    public func scheduleStreakReminder(at time: Date, currentStreak: Int) async {
        let center = UNUserNotificationCenter.current()

        center.removePendingNotificationRequests(withIdentifiers: ["streak-reminder"])

        let content = UNMutableNotificationContent()
        content.title = "Don't Break Your Streak!"
        content.body = "You have a \(currentStreak)-day streak. Take a walk to keep it going!"
        content.sound = .default
        content.categoryIdentifier = NotificationCategory.streakReminder.rawValue

        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: time)

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)

        let request = UNNotificationRequest(
            identifier: "streak-reminder",
            content: content,
            trigger: trigger
        )

        try? await center.add(request)
    }

    public func scheduleInactivityReminder(at time: Date) async {
        let center = UNUserNotificationCenter.current()

        center.removePendingNotificationRequests(withIdentifiers: ["inactivity-reminder"])

        let content = UNMutableNotificationContent()
        content.title = "Time to Move!"
        content.body = "You haven't been very active today. How about a quick walk?"
        content.sound = .default
        content.categoryIdentifier = NotificationCategory.inactivityReminder.rawValue

        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: time)

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)

        let request = UNNotificationRequest(
            identifier: "inactivity-reminder",
            content: content,
            trigger: trigger
        )

        try? await center.add(request)
    }

    public func cancelAllReminders() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [
            "daily-reminder",
            "streak-reminder",
            "inactivity-reminder"
        ])
    }

    public func cancelReminder(identifier: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
    }
}
