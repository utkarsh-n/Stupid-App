import Foundation
import AppIntents
import SwiftData
import WidgetKit

/// Logs the next scheduled dose without opening the app.
///
/// Runs in whichever process invoked it — the widget extension for a tapped
/// button, the app for a Siri phrase or the Action Button. All of them go
/// through here so there is exactly one code path that writes a dose.
struct LogDoseIntent: AppIntent {
    static var title: LocalizedStringResource = "Log a dose"
    static var description = IntentDescription("Logs the next scheduled dose at the planned amount.")

    /// Widgets can fire an intent twice on a fast double-tap, and this app has
    /// already produced one accidental duplicate the hard way. Anything inside
    /// this window is treated as the same tap.
    private static let duplicateWindow: TimeInterval = 90

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = ModelContext(SharedStore.container)

        let plans = try context.fetch(FetchDescriptor<TaperPlan>())
        guard let plan = plans.first else {
            return .result(dialog: "No taper plan set up yet.")
        }

        let dayStart = Calendar.current.startOfDay(for: Date())
        var descriptor = FetchDescriptor<Intake>(
            predicate: #Predicate { $0.timestamp >= dayStart },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        descriptor.fetchLimit = 20
        let todays = try context.fetch(descriptor).filter { $0.substanceRaw == Substance.sevenOH.rawValue }

        if let last = todays.first,
           Date().timeIntervalSince(last.timestamp) < Self.duplicateWindow {
            return .result(dialog: "Already logged a moment ago.")
        }

        let filled = Set(todays.compactMap(\.slotIndex))
        let slot = (0..<plan.slotMinutes.count).first { !filled.contains($0) }

        // Same product as last time — people stay on one bottle until it's empty.
        let lastPrepID = SharedStore.defaults.string(forKey: "lastPreparationID") ?? ""
        let preparations = try context.fetch(FetchDescriptor<Preparation>())
        let prep = preparations.first { $0.id.uuidString == lastPrepID }
            ?? preparations.first { $0.substanceRaw == Substance.sevenOH.rawValue && $0.isActive }

        let targetMg = plan.perSlotTargetMg
        let units = (prep?.strengthPerUnit ?? 0) > 0
            ? targetMg / (prep?.strengthPerUnit ?? 1)
            : targetMg

        let intake = Intake(
            timestamp: Date(),
            substance: .sevenOH,
            reason: .scheduled,
            amount: units,
            preparation: prep,
            slotIndex: slot
        )
        context.insert(intake)
        try context.save()

        WidgetCenter.shared.reloadAllTimelines()

        return .result(dialog: "Logged \(intake.nominalMg.doseFormatted) mg.")
    }
}

