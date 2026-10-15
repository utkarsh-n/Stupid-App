import Foundation
import UserNotifications
import SwiftData

/// Scheduled nudges.
///
/// Two rules shape all of this. First, **nothing on the lock screen names the
/// substance** — these render where other people can see them, so the copy is
/// deliberately vague and the detail lives inside the app. Second, **volume is
/// capped**: notification fatigue is the documented failure mode for adherence
/// apps, and an ignored notification is worse than no notification because it
/// trains dismissal. Three a day maximum, each one actionable.
@MainActor
final class NotificationService {
    static let shared = NotificationService()

    private let center = UNUserNotificationCenter.current()

    enum Category: String {
        case doseWindow = "DOSE_WINDOW"
        case checkIn = "CHECK_IN"
    }

    enum Action: String {
        case log = "LOG_DOSE"
        case snooze = "SNOOZE"
        case openCheckIn = "OPEN_CHECKIN"
    }

    var isEnabled: Bool {
        get { SharedStore.defaults.bool(forKey: "notificationsEnabled") }
        set { SharedStore.defaults.set(newValue, forKey: "notificationsEnabled") }
    }

    // MARK: - Setup

    func registerCategories() {
        let logAction = UNNotificationAction(
            identifier: Action.log.rawValue,
            title: "Log it",
            options: [],
            icon: .init(systemImageName: "checkmark.circle.fill")
        )
        let snoozeAction = UNNotificationAction(
            identifier: Action.snooze.rawValue,
            title: "In 30 minutes",
            options: [],
            icon: .init(systemImageName: "clock")
        )
        let checkInAction = UNNotificationAction(
            identifier: Action.openCheckIn.rawValue,
            title: "Check in",
            options: [.foreground],
            icon: .init(systemImageName: "text.bubble.fill")
        )

        center.setNotificationCategories([
            UNNotificationCategory(
                identifier: Category.doseWindow.rawValue,
                actions: [logAction, snoozeAction],
                intentIdentifiers: []
            ),
            UNNotificationCategory(
                identifier: Category.checkIn.rawValue,
                actions: [checkInAction],
                intentIdentifiers: []
            )
        ])
    }

    func requestAuthorization() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            isEnabled = granted
            return granted
        } catch {
            isEnabled = false
            return false
        }
    }

    // MARK: - Scheduling

    /// Rebuilds the whole schedule. Cheap, and avoids drift between what the plan
    /// says and what's actually pending.
    func reschedule(plan: TaperPlan) async {
        center.removeAllPendingNotificationRequests()
        guard isEnabled else { return }

        for (index, minutes) in plan.slotMinutes.enumerated() {
            scheduleDoseWindow(index: index, minutes: minutes)
        }
        scheduleEveningCheckIn(plan: plan)
    }

    private func scheduleDoseWindow(index: Int, minutes: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Window open"
        content.body = ["Morning", "Midday", "Evening"][safe: index] ?? "Next window"
        content.categoryIdentifier = Category.doseWindow.rawValue
        content.threadIdentifier = "windows"
        // Worth breaking through a Focus: the whole point of a scheduled dose is
        // that taking it late means interdose withdrawal.
        content.interruptionLevel = .timeSensitive
        content.sound = .default

        var components = DateComponents()
        components.hour = minutes / 60
        components.minute = minutes % 60

        center.add(UNNotificationRequest(
            identifier: "window-\(index)",
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        ))
    }

    /// One evening prompt, timed after the last dose so the day's picture is
    /// complete. Passive: it should be there when you look, not interrupt you.
    private func scheduleEveningCheckIn(plan: TaperPlan) {
        let content = UNMutableNotificationContent()
        content.title = "How did today go?"
        content.body = "A few taps keeps the plan honest."
        content.categoryIdentifier = Category.checkIn.rawValue
        content.threadIdentifier = "checkin"
        content.interruptionLevel = .passive

        let lastSlot = plan.slotMinutes.max() ?? 1020
        let promptAt = min(lastSlot + 240, 22 * 60)   // 4h after the last dose, never past 10pm

        var components = DateComponents()
        components.hour = promptAt / 60
        components.minute = promptAt % 60

        center.add(UNNotificationRequest(
            identifier: "checkin-evening",
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        ))
    }

    /// Fired when the assessment clears a reduction — the one moment the app has
    /// something to say that the person can't work out by looking at a clock.
    func notifyStepDownAvailable(nextMg: Double) {
        guard isEnabled else { return }
        let content = UNMutableNotificationContent()
        content.title = "Ready for the next step"
        content.body = "Settled at this level. Next target is \(nextMg.doseFormatted) mg when you want it."
        content.threadIdentifier = "plan"
        content.interruptionLevel = .active

        center.add(UNNotificationRequest(
            identifier: "stepdown-\(Int(nextMg * 100))",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        ))
    }

    func snooze(minutes: Int = 30) {
        let content = UNMutableNotificationContent()
        content.title = "Window open"
        content.body = "Snoozed reminder."
        content.categoryIdentifier = Category.doseWindow.rawValue
        content.interruptionLevel = .timeSensitive

        center.add(UNNotificationRequest(
            identifier: "snooze-\(UUID().uuidString)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(
                timeInterval: TimeInterval(minutes * 60), repeats: false
            )
        ))
    }
}

/// Handles taps on notification actions, including logging a dose without the
/// app coming to the foreground.
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        switch response.actionIdentifier {
        case NotificationService.Action.log.rawValue:
            _ = try? await LogDoseIntent().perform()
        case NotificationService.Action.snooze.rawValue:
            await NotificationService.shared.snooze()
        default:
            break
        }
    }

    /// Show notifications even with the app open — a dose window matters whether
    /// or not you happen to be looking at this screen.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
