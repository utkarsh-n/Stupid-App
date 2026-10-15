import Foundation
import ActivityKit

/// Starts and stops the dose countdown.
///
/// Deliberately manual. An activity running all day would be noise and would
/// also hit the system's roughly eight-hour ceiling; started on demand for a bad
/// stretch, a countdown to the next window fits comfortably inside it.
@MainActor
@Observable
final class LiveActivityController {
    static let shared = LiveActivityController()

    private(set) var isRunning = false
    var lastError: String?

    private var activity: Activity<DoseActivityAttributes>?

    func refreshState() {
        activity = Activity<DoseActivityAttributes>.activities.first
        isRunning = activity != nil
    }

    var authorizationDenied: Bool {
        !ActivityAuthorizationInfo().areActivitiesEnabled
    }

    func start(nextDoseAt: Date, label: String = "Next window") {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            lastError = "Live Activities are turned off for this app in Settings."
            return
        }
        guard activity == nil else { return }

        let state = DoseActivityAttributes.ContentState(
            nextDoseAt: nextDoseAt,
            isOpen: nextDoseAt <= Date(),
            label: label
        )
        let attributes = DoseActivityAttributes(startedAt: Date())

        do {
            activity = try Activity.request(
                attributes: attributes,
                content: .init(state: state, staleDate: nextDoseAt.addingTimeInterval(1800)),
                pushType: nil
            )
            isRunning = true
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    func stop() {
        Task {
            for activity in Activity<DoseActivityAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
            self.activity = nil
            self.isRunning = false
        }
    }

    /// Advances the countdown to the following window after a dose is logged,
    /// so the activity stays useful instead of sitting at zero.
    func advance(to nextDoseAt: Date, label: String = "Next window") {
        guard let activity else { return }
        Task {
            let state = DoseActivityAttributes.ContentState(
                nextDoseAt: nextDoseAt,
                isOpen: nextDoseAt <= Date(),
                label: label
            )
            await activity.update(.init(state: state, staleDate: nextDoseAt.addingTimeInterval(1800)))
        }
    }
}
