import Foundation
import AppIntents
import SwiftData
import WidgetKit

/// "Log my noon dose."
///
/// This exists separately from `LogSpecificDoseIntent` for one reason: **App
/// Shortcut phrases only reliably match a parameter that is non-optional and
/// drawn from a closed set.** The other intent has every parameter optional so
/// it composes well in the Shortcuts app, and that same optionality is what
/// makes it a poor target for a spoken phrase. Splitting them lets each be good
/// at its own job instead of mediocre at both.
struct LogSlotDoseIntent: AppIntent {
    static var title: LocalizedStringResource = "Log a slot's dose"
    static var description = IntentDescription("Logs the planned dose for a named slot.")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Slot")
    var slot: DoseSlotChoice

    static var parameterSummary: some ParameterSummary {
        Summary("Log my \(\.$slot) dose")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let result = try DoseWriter.log(slotIndex: slot.slotIndex, milligrams: nil, preparationID: nil)
        return .result(dialog: "\(result)")
    }
}

/// Shared write path so the widget button, the control, Siri, and the watch all
/// produce identical rows — and all inherit the same duplicate guard.
@MainActor
enum DoseWriter {

    static let duplicateWindow: TimeInterval = 90

    static func log(
        slotIndex: Int?,
        milligrams: Double?,
        preparationID: UUID?,
        at timestamp: Date = Date()
    ) throws -> String {
        let context = ModelContext(SharedStore.container)

        guard let plan = try context.fetch(FetchDescriptor<TaperPlan>()).first else {
            return "No taper plan set up yet."
        }

        let dayStart = Calendar.current.startOfDay(for: timestamp)
        var descriptor = FetchDescriptor<Intake>(
            predicate: #Predicate { $0.timestamp >= dayStart },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        descriptor.fetchLimit = 20
        let todays = try context.fetch(descriptor)
            .filter { $0.substanceRaw == Substance.sevenOH.rawValue }

        // A named slot is an explicit instruction, so it isn't a duplicate even
        // if something was logged moments ago. An unnamed one might well be.
        if slotIndex == nil, milligrams == nil,
           let last = todays.first,
           timestamp.timeIntervalSince(last.timestamp) < duplicateWindow {
            return "Already logged a moment ago."
        }

        if let slotIndex, todays.contains(where: { $0.slotIndex == slotIndex }) {
            let name = ["morning", "noon", "evening"][safe: slotIndex] ?? "that"
            return "Your \(name) dose is already logged."
        }

        let preparations = try context.fetch(FetchDescriptor<Preparation>())
        let lastID = SharedStore.defaults.string(forKey: "lastPreparationID") ?? ""
        let prep = preparationID.flatMap { id in preparations.first { $0.id == id } }
            ?? preparations.first { $0.id.uuidString == lastID }
            ?? preparations.first { $0.substanceRaw == Substance.sevenOH.rawValue && $0.isActive }

        let filled = Set(todays.compactMap(\.slotIndex))
        let resolvedSlot = slotIndex ?? (0..<plan.slotMinutes.count).first { !filled.contains($0) }

        let targetMg = milligrams ?? plan.perSlotTargetMg
        let strength = prep?.strengthPerUnit ?? 0
        let units = strength > 0 ? targetMg / strength : targetMg

        let intake = Intake(
            timestamp: timestamp,
            substance: .sevenOH,
            reason: .scheduled,
            amount: units,
            preparation: prep,
            slotIndex: resolvedSlot
        )
        context.insert(intake)
        try context.save()

        if let prep { SharedStore.defaults.set(prep.id.uuidString, forKey: "lastPreparationID") }
        WidgetCenter.shared.reloadAllTimelines()

        let dayTotal = todays.reduce(intake.nominalMg) { $0 + $1.nominalMg }
        let slotName = resolvedSlot.flatMap { ["morning", "noon", "evening"][safe: $0] }
        let lead = slotName.map { "Logged \(intake.nominalMg.doseFormatted) mg for \($0)." }
            ?? "Logged \(intake.nominalMg.doseFormatted) mg."
        return "\(lead) \(dayTotal.doseFormatted) of \(plan.currentTargetMgPerDay.doseFormatted) today."
    }
}
