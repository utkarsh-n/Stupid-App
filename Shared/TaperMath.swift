import Foundation

/// Dose arithmetic for a hyperbolic taper.
///
/// The governing fact: dose-to-receptor-occupancy follows the law of mass action
/// and is therefore hyperbolic, not linear. Equal-milligram cuts remove an
/// ever-larger share of occupancy as the dose falls — in the buprenorphine
/// literature, 16→12 mg drops occupancy about 5 percentage points while 4→0 mg
/// drops it about 54. So every reduction here is a percentage of the *current*
/// dose, never of the original.
enum TaperMath {

    // MARK: - Step sizing

    /// Recommended reduction as a fraction of current dose, given how far into the
    /// taper you are. Steps get gentler as the occupancy curve steepens.
    ///
    /// - Parameter fractionOfBaseline: current daily dose ÷ baseline daily dose.
    static func recommendedStepFraction(fractionOfBaseline: Double) -> Double {
        switch fractionOfBaseline {
        case ..<0.30:  return 0.05   // steep part of the curve — 1–5% every 1–2 weeks
        case ..<0.50:  return 0.06
        default:       return 0.08
        }
    }

    /// Recommended days to hold a step before the next reduction. Longer at the
    /// low end, and never shorter than the delayed-feedback window.
    static func recommendedStepDays(fractionOfBaseline: Double) -> Int {
        fractionOfBaseline < 0.30 ? 12 : 10
    }

    /// The next target dose after applying one step.
    static func nextTarget(current: Double, baseline: Double) -> Double {
        let fraction = baseline > 0 ? current / baseline : 1
        let reduction = recommendedStepFraction(fractionOfBaseline: fraction)
        return round((current * (1 - reduction)) * 100) / 100
    }

    /// Number of steps remaining from `current` down to `jumpOff` at the
    /// recommended pacing. Simulated rather than solved in closed form because the
    /// step fraction changes as you descend.
    static func stepsRemaining(current: Double, baseline: Double, jumpOff: Double) -> Int {
        guard current > jumpOff, baseline > 0, jumpOff > 0 else { return 0 }
        var dose = current
        var steps = 0
        while dose > jumpOff && steps < 500 {
            dose = nextTarget(current: dose, baseline: baseline)
            steps += 1
        }
        return steps
    }

    /// Projected completion date. Deliberately returned as an estimate the UI
    /// should present softly — holds move it, and nothing "falls behind."
    static func projectedFinish(
        current: Double,
        baseline: Double,
        jumpOff: Double,
        from date: Date = Date()
    ) -> Date? {
        guard current > jumpOff, baseline > 0 else { return nil }
        var dose = current
        var days = 0
        var guard_ = 0
        while dose > jumpOff && guard_ < 500 {
            let fraction = dose / baseline
            days += recommendedStepDays(fractionOfBaseline: fraction)
            dose = nextTarget(current: dose, baseline: baseline)
            guard_ += 1
        }
        return Calendar.current.date(byAdding: .day, value: days, to: date)
    }

    // MARK: - Honesty about the numbers

    /// The plausible range of *actual* 7-OH in a nominal dose from retail tablets.
    ///
    /// Quantitative analysis of commercial 7-OH products found measured content
    /// running 32–81% of the stated amount. This returns that band so the UI can
    /// show an honest range instead of a falsely precise number. Returns nil when
    /// the preparation's content is verified (weighed solution), because then the
    /// nominal figure is the real one.
    static func uncertaintyBand(nominalMg: Double, verified: Bool) -> ClosedRange<Double>? {
        guard !verified, nominalMg > 0 else { return nil }
        return (nominalMg * 0.32)...(nominalMg * 0.81)
    }

    /// How wide the daily total's uncertainty is, as a multiple. Used to decide
    /// whether a taper step is even measurable against the noise.
    static func uncertaintyRatio(for intakes: [Intake]) -> Double? {
        let sevenOH = intakes.filter { $0.substance == .sevenOH }
        guard !sevenOH.isEmpty else { return nil }
        guard sevenOH.contains(where: { !$0.isVerifiedAmount }) else { return nil }
        let nominal = sevenOH.reduce(0) { $0 + $1.nominalMg }
        guard nominal > 0 else { return nil }
        return 0.81 / 0.32
    }

    /// Whether a proposed step is large enough to be distinguishable from the
    /// measurement noise. A 5% step off 15 mg is 0.75 mg; if the day-to-day swing
    /// from unverified tablets is several mg, the step is buried and the taper is
    /// not actually being tapered.
    static func stepIsMeasurable(stepMg: Double, dailyNominalMg: Double, verified: Bool) -> Bool {
        if verified { return true }
        let bandWidth = dailyNominalMg * (0.81 - 0.32)
        return stepMg > bandWidth
    }

    // MARK: - Volumetric preparation

    /// Solution recipe for a target concentration, given powder purity.
    ///
    /// Weighing 5 mg directly is the wrong approach — a 1 mg-resolution scale is
    /// ±20% at that mass. Weighing ~100 mg puts the measurement inside the scale's
    /// accurate range (±1%) and the dilution carries the precision the rest of the
    /// way: at 1 mg/mL a 0.25 mg step is 0.25 mL on an oral syringe.
    struct SolutionRecipe {
        var powderMg: Double
        var volumeML: Double
        var concentrationMgPerML: Double
        var activeMg: Double
    }

    static func solutionRecipe(
        powderMg: Double = 100,
        purity: Double = 0.95,
        targetConcentration: Double = 1.0
    ) -> SolutionRecipe {
        let active = powderMg * purity
        let volume = active / targetConcentration
        return SolutionRecipe(
            powderMg: powderMg,
            volumeML: round(volume * 10) / 10,
            concentrationMgPerML: targetConcentration,
            activeMg: round(active * 10) / 10
        )
    }
}
