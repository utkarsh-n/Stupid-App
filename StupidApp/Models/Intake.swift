import Foundation
import SwiftData

/// One logged dose of anything. 7-OH doses and adjunct doses share this model so
/// the copilot can correlate symptoms against the whole intake stream rather than
/// only the substance being tapered.
@Model
final class Intake {
    var id: UUID = UUID()
    var timestamp: Date = Date()
    var substanceRaw: String = Substance.sevenOH.rawValue
    var reasonRaw: String = DoseReason.scheduled.rawValue
    var routeRaw: String = IntakeRoute.oral.rawValue

    /// Amount in the preparation's own units — tablets, mL, mg, or grams.
    var amount: Double = 0

    /// Nominal mg of active, computed at log time from the preparation. "Nominal"
    /// is doing real work in that name: for retail tablets the true content is
    /// somewhere in a wide band around this number. See `TaperMath.uncertaintyBand`.
    var nominalMg: Double = 0

    /// Which of the day's scheduled slots this fills, if any. nil = unscheduled.
    var slotIndex: Int?

    var note: String?

    @Relationship var preparation: Preparation?

    init(
        timestamp: Date = Date(),
        substance: Substance = .sevenOH,
        reason: DoseReason = .scheduled,
        route: IntakeRoute = .oral,
        amount: Double,
        preparation: Preparation? = nil,
        slotIndex: Int? = nil,
        note: String? = nil
    ) {
        self.id = UUID()
        self.timestamp = timestamp
        self.substanceRaw = substance.rawValue
        self.reasonRaw = reason.rawValue
        self.routeRaw = route.rawValue
        self.amount = amount
        self.preparation = preparation
        self.slotIndex = slotIndex
        self.note = note
        self.nominalMg = preparation?.nominalMg(forUnits: amount) ?? amount
    }

    var substance: Substance {
        get { Substance(rawValue: substanceRaw) ?? .sevenOH }
        set { substanceRaw = newValue.rawValue }
    }

    var reason: DoseReason {
        get { DoseReason(rawValue: reasonRaw) ?? .scheduled }
        set { reasonRaw = newValue.rawValue }
    }

    var route: IntakeRoute {
        get { IntakeRoute(rawValue: routeRaw) ?? .oral }
        set { routeRaw = newValue.rawValue }
    }

    /// True when the amount can be trusted as stated — a weighed solution rather
    /// than a hand-split retail tablet.
    var isVerifiedAmount: Bool {
        preparation?.hasVerifiedContent ?? false
    }
}
