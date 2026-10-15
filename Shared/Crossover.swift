import Foundation

/// The switch from hand-split tablets to a measured solution.
///
/// This is a prerequisite rather than an upgrade. A 1 mg target cannot be hit
/// with tablets: hand-splitting a 10 mg tablet carries an error wider than the
/// entire dose being aimed at, and the five products in rotation run 10–18 mg
/// nominal with commercial 7-OH measuring 32–81% of label. On the Low and Hold
/// schedule the last fortnight is simply not executable from a pill.
///
/// The dangerous part is not the chemistry, it's the direction of the error.
enum Crossover {

    /// Weigh a mass large enough that the scale's error is small, then dilute.
    /// Weighing 5 mg directly on a milligram scale is ±20%; weighing 100 mg is
    /// ±1%, and the dilution carries that accuracy down to every dose.
    struct Recipe {
        var powderMg: Double = 100
        var purity: Double = 0.95
        var volumeML: Double = 100

        var contentMg: Double { powderMg * purity }
        var concentrationMgPerML: Double { contentMg / volumeML }

        func millilitresFor(mg: Double) -> Double {
            guard concentrationMgPerML > 0 else { return 0 }
            return mg / concentrationMgPerML
        }

        /// Scale error as a percentage of the weighed mass, for a given scale
        /// resolution. The point of weighing big is that this number gets small.
        func errorPercent(scaleResolutionMg: Double) -> Double {
            guard powderMg > 0 else { return 0 }
            return (scaleResolutionMg / powderMg) * 100
        }
    }

    /// Fraction of the nominal tablet dose to start a converted slot at.
    ///
    /// **The critical safety number.** A nominal 5 mg of hand-split retail tablet
    /// is really somewhere around 1.6–4 mg of 7-OH, because commercial product
    /// measures well under label. Solution from 95% powder is genuinely what it
    /// says. So crossing over at face value is not a like-for-like swap — it can
    /// be a real increase of 25% to 200%, and the error that matters here is the
    /// one that goes up: tolerance is set by what you have actually been taking,
    /// not by what the bottle claims.
    static let startingFraction: Double = 0.6

    static func startingDoseMg(nominalSlotMg: Double) -> Double {
        (nominalSlotMg * startingFraction * 100).rounded() / 100
    }

    /// Order to convert the day's slots in.
    ///
    /// Midday first. It is the most forgiving slot to be wrong in: an
    /// underestimate shows up as afternoon discomfort with the evening dose
    /// close behind, and you learn the real strength before it matters. The
    /// morning dose goes last because morning withdrawal is the strongest
    /// relapse driver in this drug, and finding out the solution is weak at 7am
    /// is the worst version of that lesson.
    static func conversionOrder(slotCount: Int) -> [Int] {
        switch slotCount {
        case 0, 1: return Array(0..<slotCount)
        case 2:    return [1, 0]
        default:   return [1, slotCount - 1] + Array(0..<slotCount).filter { $0 != 1 && $0 != slotCount - 1 }
        }
    }

    static func slotName(_ index: Int) -> String {
        ["Morning", "Midday", "Evening"][safe: index] ?? "Slot \(index + 1)"
    }

    /// Days to hold a converted slot before converting the next one.
    static let settleDaysPerSlot = 2

    struct Step: Identifiable {
        var id: Int { order }
        let order: Int
        let slotIndex: Int
        let startMg: Double
        let targetMg: Double
    }

    static func plan(slotCount: Int, perSlotTargetMg: Double) -> [Step] {
        conversionOrder(slotCount: slotCount).enumerated().map { order, slot in
            Step(
                order: order,
                slotIndex: slot,
                startMg: startingDoseMg(nominalSlotMg: perSlotTargetMg),
                targetMg: perSlotTargetMg
            )
        }
    }
}
