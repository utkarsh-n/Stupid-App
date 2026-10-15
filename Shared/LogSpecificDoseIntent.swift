import Foundation
import AppIntents
import SwiftData
import WidgetKit

/// "Log 5 mg of Omega Extracts for my noon dose."
///
/// Every parameter is optional and falls back to something sensible, so the same
/// intent covers the full sentence, a bare "log my noon dose", and a tap from
/// Shortcuts with nothing filled in. Anything missing that actually matters gets
/// asked for rather than guessed.
struct LogSpecificDoseIntent: AppIntent {
    static var title: LocalizedStringResource = "Log a dose"
    static var description = IntentDescription("Logs a dose, optionally naming the amount, product, and slot.")

    /// Opening the app afterwards would defeat the point — the value here is
    /// logging without looking at a screen.
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Milligrams")
    var milligrams: Double?

    @Parameter(title: "Product")
    var product: PreparationEntity?

    @Parameter(title: "Slot")
    var slot: DoseSlotChoice?

    static var parameterSummary: some ParameterSummary {
        Summary("Log \(\.$milligrams) mg of \(\.$product) for the \(\.$slot) dose")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let result = try DoseWriter.log(
            slotIndex: slot?.slotIndex,
            milligrams: milligrams,
            preparationID: product?.id
        )
        return .result(dialog: "\(result)")
    }

}

/// What Siri and Spotlight offer without any setup.
///
/// Phrases have to embed the app name, and the ones carrying a parameter use the
/// slot — a closed set of three words matches from speech far more reliably than
/// an arbitrary number would.
struct StupidAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        // No parameters — the most robust thing to say, so it comes first.
        AppShortcut(
            intent: LogDoseIntent(),
            phrases: [
                "Log a dose in \(.applicationName)",
                "Log it in \(.applicationName)",
                "Log my dose in \(.applicationName)"
            ],
            shortTitle: "Log dose",
            systemImageName: "plus.circle.fill"
        )

        // One required parameter drawn from a closed set of three, which is the
        // shape App Shortcut phrase matching actually handles well.
        AppShortcut(
            intent: LogSlotDoseIntent(),
            phrases: [
                "Log my \(\.$slot) dose in \(.applicationName)",
                "Log \(\.$slot) in \(.applicationName)"
            ],
            shortTitle: "Log a slot",
            systemImageName: "clock.fill"
        )

        AppShortcut(
            intent: StartCountdownIntent(),
            phrases: [
                "Start a countdown in \(.applicationName)",
                "Start my countdown in \(.applicationName)"
            ],
            shortTitle: "Countdown",
            systemImageName: "hourglass"
        )
    }
}

/// Puts the countdown on the Lock Screen without opening anything — the version
/// of this you want at 3am.
struct StartCountdownIntent: AppIntent {
    static var title: LocalizedStringResource = "Start the countdown"
    static var description = IntentDescription("Shows a Lock Screen countdown to the next dose window.")
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = ModelContext(SharedStore.container)
        guard let plan = try context.fetch(FetchDescriptor<TaperPlan>()).first else {
            return .result(dialog: "No plan set up yet.")
        }

        let dayStart = Calendar.current.startOfDay(for: Date())
        let descriptor = FetchDescriptor<Intake>(predicate: #Predicate { $0.timestamp >= dayStart })
        let filled = Set(((try? context.fetch(descriptor)) ?? [])
            .filter { $0.substanceRaw == Substance.sevenOH.rawValue }
            .compactMap(\.slotIndex))

        let cal = Calendar.current
        var next: Date?
        for (index, minutes) in plan.slotMinutes.enumerated() where !filled.contains(index) {
            next = cal.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: Date())
            break
        }
        if next == nil, let first = plan.slotMinutes.first,
           let tomorrow = cal.date(byAdding: .day, value: 1, to: Date()) {
            next = cal.date(bySettingHour: first / 60, minute: first % 60, second: 0, of: tomorrow)
        }

        guard let target = next else { return .result(dialog: "Nothing left to count down to.") }
        LiveActivityController.shared.start(nextDoseAt: target)
        return .result(dialog: "Countdown started.")
    }
}
