import Foundation

/// Everything the app can log. 7-OH is the only substance with a taper plan
/// attached; the rest are adjuncts logged in the same stream so symptoms can be
/// correlated against them.
enum Substance: String, Codable, CaseIterable, Identifiable {
    case sevenOH
    case cannabis
    case melatonin
    case magnesium
    case zinc
    case glycine
    case lTheanine
    case vitaminC
    case electrolytes
    case nsaid
    case acetaminophen
    case loperamide
    case clonidine
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .sevenOH:       return "7-OH"
        case .cannabis:      return "Cannabis"
        case .melatonin:     return "Melatonin"
        case .magnesium:     return "Magnesium"
        case .zinc:          return "Zinc"
        case .glycine:       return "Glycine"
        case .lTheanine:     return "L-Theanine"
        case .vitaminC:      return "Vitamin C"
        case .electrolytes:  return "Electrolytes"
        case .nsaid:         return "NSAID"
        case .acetaminophen: return "Acetaminophen"
        case .loperamide:    return "Loperamide"
        case .clonidine:     return "Clonidine"
        case .other:         return "Other"
        }
    }

    var symbolName: String {
        switch self {
        case .sevenOH:       return "circle.hexagongrid.fill"
        case .cannabis:      return "leaf.fill"
        case .melatonin:     return "moon.stars.fill"
        case .magnesium:     return "bolt.heart.fill"
        case .zinc:          return "shield.lefthalf.filled"
        case .glycine:       return "bed.double.fill"
        case .lTheanine:     return "cup.and.saucer.fill"
        case .vitaminC:      return "carrot.fill"
        case .electrolytes:  return "drop.fill"
        case .nsaid:         return "pills.fill"
        case .acetaminophen: return "pills.fill"
        case .loperamide:    return "cross.vial.fill"
        case .clonidine:     return "stethoscope"
        case .other:         return "circle.dashed"
        }
    }

    /// The tapered substance. Everything else is an adjunct.
    var isTapered: Bool { self == .sevenOH }


    /// Hard ceilings the app refuses to help you exceed. nil means no fixed cap.
    var dailyCeilingMg: Double? {
        switch self {
        case .loperamide:    return 8      // OTC max; cardiac toxicity above
        case .acetaminophen: return 3000
        case .zinc:          return 40     // above this chronically → copper deficiency
        case .vitaminC:      return 2000
        default:             return nil
        }
    }

    var ceilingRationale: String? {
        switch self {
        case .loperamide:
            return "Above 8 mg/day loperamide causes QT prolongation and ventricular arrhythmia. This is the dose that has killed people in opioid withdrawal."
        case .acetaminophen:
            return "3,000 mg/day is the hepatotoxicity ceiling. Count combination products toward it."
        case .zinc:
            return "Above 40 mg/day for months induces copper deficiency."
        case .vitaminC:
            return "Gram doses raise urinary oxalate and risk nephropathy — a risk that withdrawal diarrhea and dehydration specifically amplify."
        default:
            return nil
        }
    }
}

/// Why a dose was taken. The ratio of scheduled to withdrawal-driven doses is the
/// earliest signal that a taper step is too steep, which is why this is a required
/// field rather than an optional note.
enum DoseReason: String, Codable, CaseIterable, Identifiable {
    case scheduled
    case withdrawal
    case craving
    case symptom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .scheduled:  return "On schedule"
        case .withdrawal: return "Withdrawal"
        case .craving:    return "Craving"
        case .symptom:    return "Symptom"
        }
    }
}

enum IntakeRoute: String, Codable, CaseIterable, Identifiable {
    case oral
    case sublingual
    case inhaled
    case edible

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .oral:       return "Oral"
        case .sublingual: return "Sublingual"
        case .inhaled:    return "Inhaled"
        case .edible:     return "Edible"
        }
    }
}

// MARK: - Dosing presets

extension Substance {
    /// The unit doses are entered in. Cannabis is counted rather than weighed
    /// because what matters for the substitution watch is frequency, not
    /// milligrams nobody can measure anyway.
    var unitLabel: String {
        switch self {
        case .cannabis:     return "×"
        case .electrolytes: return "sachet"
        default:            return "mg"
        }
    }

    /// One-tap amounts, chosen from the evidence rather than from what's on the
    /// shelf. Notably melatonin starts at 0.5 mg: the dose-response curve peaks
    /// near 4 mg and physiologic dosing works at 0.5–1, so the 5 and 10 mg
    /// retail tablets are above the useful range, not below it.
    var commonDoses: [Double] {
        switch self {
        case .melatonin:     return [0.5, 1, 3]
        case .magnesium:     return [200, 300, 400]
        case .zinc:          return [15, 30]
        case .glycine:       return [3000]
        case .lTheanine:     return [100, 200]
        case .vitaminC:      return [250, 500]
        case .electrolytes:  return [1, 2]
        case .nsaid:         return [200, 400, 600]
        case .acetaminophen: return [500, 1000]
        case .loperamide:    return [2, 4]
        case .clonidine:     return [0.1, 0.2]
        case .cannabis:      return [1]
        default:             return [1]
        }
    }

    /// Shown when logging. Short, factual, and honest about weak evidence — most
    /// of these are worth trying and none of them are doing the real work.
    var note: String? {
        switch self {
        case .melatonin:
            return "Timing beats dose: 2–3 hours before bed outperforms 30 minutes. It re-anchors a wrecked schedule rather than sedating you through a bad night."
        case .magnesium:
            return "Glycinate is the form to use — highest dose tolerable without the laxative effect, which matters when the taper is already loosening things."
        case .zinc:
            return "The only supplement here with a positive trial in opioid withdrawal specifically. Take it with food."
        case .glycine:
            return "Improves sleep onset without altering sleep architecture — the direct contrast with THC."
        case .vitaminC:
            return "Nutritional only. The gram-dose withdrawal protocol rests on one unreplicated study and risks oxalate nephropathy, which withdrawal dehydration amplifies."
        case .electrolytes:
            return "The highest-yield, lowest-risk item in the whole list, and the one most people skip."
        case .cannabis:
            return "Inhaled is titratable; edibles are not. Nightly use for sleep is the highest-risk pattern here — tolerance to sedation outpaces tolerance to REM suppression, and stopping produces insomnia that mimics opioid withdrawal."
        case .nsaid:
            return "Fine in bursts, not for months — GI erosion on an already-irritated gut, and renal risk that dehydration compounds."
        case .clonidine:
            return "Prescription. Check blood pressure before each dose, and taper off rather than stopping — abrupt discontinuation causes rebound hypertension."
        default:
            return nil
        }
    }

    /// Adjuncts worth offering, in roughly the order they earn their place.
    static var adjuncts: [Substance] {
        [.electrolytes, .magnesium, .zinc, .glycine, .lTheanine, .melatonin,
         .nsaid, .acetaminophen, .loperamide, .vitaminC, .cannabis, .clonidine]
    }
}
