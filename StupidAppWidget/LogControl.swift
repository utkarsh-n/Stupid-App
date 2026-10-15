import WidgetKit
import SwiftUI
import AppIntents

/// One implementation, three surfaces: Control Center, the Lock Screen's bottom
/// slots, and the Action Button.
///
/// This is the lowest-friction path in the whole app — a physical button press
/// logs the dose without unlocking past the press. Which matters, because a
/// logging tool only works if the friction is near zero, and everything else
/// here still costs an unlock and a tap.
@available(iOS 18.0, *)
struct LogControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "LogControl") {
            ControlWidgetButton(action: LogDoseIntent()) {
                // Deliberately unlabelled as to what — this is visible in
                // Control Center to anyone holding the phone.
                Label("Log", systemImage: "circle.hexagongrid.fill")
            }
        }
        .displayName("Log")
        .description("Logs the next scheduled dose.")
    }
}
