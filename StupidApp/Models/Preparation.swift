import Foundation
import SwiftData

enum PreparationKind: String, Codable, CaseIterable, Identifiable {
    case tablet
    case capsule
    case solution
    case powder

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .tablet:   return "Tablet"
        case .capsule:  return "Capsule"
        case .solution: return "Solution"
        case .powder:   return "Powder"
        }
    }

    /// How finely this format can actually be divided in practice.
    ///
    /// Tablets are split on a score line by hand — pharmaceutical studies routinely
    /// find hand-split halves deviating 10-20%+ by mass, and with unevenly
    /// distributed fillers the active split is worse than the mass split. Capsules
    /// have no score line at all. Solution is limited only by the syringe.
    var practicalResolution: String {
        switch self {
        case .tablet:   return "½ tablet, ±10–20%"
        case .capsule:  return "whole capsule only"
        case .solution: return "0.25 mg"
        case .powder:   return "limited by scale"
        }
    }
}

/// A specific product, batch, or solution batch. Logged with every dose because
/// a silent potency change is the most common way a taper signal gets corrupted:
/// commercial 7-OH measures 32–81% of labeled content, with 10–17% variance
/// between tablets in a single bottle. Switching brands at the same nominal mg
/// can be a real 2–3x change in either direction.
@Model
final class Preparation {
    var id: UUID = UUID()
    var label: String = ""
    var kindRaw: String = PreparationKind.tablet.rawValue
    var substanceRaw: String = Substance.sevenOH.rawValue

    /// mg of active per unit. For tablets/capsules this is per tablet; for
    /// solutions it is mg per mL; for powder it is mg per mg (i.e. purity).
    var strengthPerUnit: Double = 0

    /// Stated purity as a fraction, where known. 0.95 for the 95%+ powder.
    var purity: Double?

    var lot: String?
    var batchDate: Date?
    var isActive: Bool = true
    var createdAt: Date = Date()
    var notes: String?

    init(
        label: String,
        kind: PreparationKind,
        substance: Substance = .sevenOH,
        strengthPerUnit: Double,
        purity: Double? = nil,
        lot: String? = nil,
        batchDate: Date? = nil,
        isActive: Bool = true,
        notes: String? = nil
    ) {
        self.id = UUID()
        self.label = label
        self.kindRaw = kind.rawValue
        self.substanceRaw = substance.rawValue
        self.strengthPerUnit = strengthPerUnit
        self.purity = purity
        self.lot = lot
        self.batchDate = batchDate
        self.isActive = isActive
        self.createdAt = Date()
        self.notes = notes
    }

    var kind: PreparationKind {
        get { PreparationKind(rawValue: kindRaw) ?? .tablet }
        set { kindRaw = newValue.rawValue }
    }

    var substance: Substance {
        get { Substance(rawValue: substanceRaw) ?? .sevenOH }
        set { substanceRaw = newValue.rawValue }
    }

    /// Nominal mg of active for a given number of units (tablets, or mL).
    func nominalMg(forUnits units: Double) -> Double {
        strengthPerUnit * units
    }

    /// The unit the amount field is measured in for this preparation.
    var unitLabel: String {
        switch kind {
        case .tablet:   return "tab"
        case .capsule:  return "cap"
        case .solution: return "mL"
        case .powder:   return "mg"
        }
    }

    /// Whether dose amounts from this preparation can be trusted as stated.
    ///
    /// Solutions prepared from weighed high-purity powder are trustworthy; retail
    /// tablets are not, because label accuracy in this product category is poor
    /// and unverifiable from the outside.
    var hasVerifiedContent: Bool {
        kind == .solution || (purity ?? 0) >= 0.9
    }
}
