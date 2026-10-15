import Foundation
import ActivityKit

/// Live Activity showing the countdown to the next dose window.
///
/// Started deliberately rather than automatically, because the moment it earns
/// its place is the one where you're clock-watching in withdrawal and otherwise
/// opening the app every three minutes. Running it all day would be both useless
/// and indiscreet.
///
/// The countdown itself is rendered by the system from `nextDoseAt` — no timeline
/// entries, no background wakeups, no push. That's what lets it tick accurately
/// for hours while the app is closed.
struct DoseActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        /// When the next window opens. The system renders the countdown from this.
        var nextDoseAt: Date
        /// Reached zero — the window is open.
        var isOpen: Bool
        /// Neutral label. Never the substance, never a milligram figure: this
        /// renders on a lock screen that other people can see.
        var label: String
    }

    /// When the countdown was started, used to size the progress bar.
    var startedAt: Date
}
