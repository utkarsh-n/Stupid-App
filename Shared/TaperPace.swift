import Foundation

/// How fast to run the taper.
///
/// The evidence favours slow: reductions under 5% a week outperform faster ones,
/// and tapers running 12–52 weeks are roughly 3.6× more likely to finish than
/// short ones. But that evidence comes overwhelmingly from *involuntary*,
/// clinician-led tapers in chronic-pain patients who did not choose to stop, and
/// it is not a physical law. A person who has already taken themselves from 45 mg
/// to 15 mg has real information about their own tolerance that a population
/// average does not contain.
///
/// So the pace is a choice with the consequences stated plainly, rather than a
/// number the app imposes. What the app does enforce is the part that isn't
/// negotiable: the symptom check gates each reduction regardless of pace.
enum TaperPace: String, CaseIterable, Identifiable {
    case sprint      // to jump-off within ~2 weeks
    case lowAndHold  // fast down to a floor, then hold there before jumping
    case measured    // ~10 days per step
    case evidence    // the literature default

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sprint:     return "Sprint"
        case .lowAndHold: return "Low and hold"
        case .measured:   return "Measured"
        case .evidence:   return "Evidence default"
        }
    }

    var summary: String {
        switch self {
        case .sprint:     return "To jump-off in about two weeks"
        case .lowAndHold: return "Down to 1 mg fast, then hold a month"
        case .measured:   return "About six weeks"
        case .evidence:   return "Five to six months"
        }
    }

    /// Fraction of the current dose removed at each step.
    var stepFraction: Double {
        switch self {
        case .sprint:     return 0.18
        case .lowAndHold: return 0.155
        case .measured:   return 0.12
        case .evidence:   return 0.05
        }
    }

    /// Days held between reductions.
    var stepDays: Int {
        switch self {
        case .sprint:     return 1
        case .lowAndHold: return 1
        case .measured:   return 3
        case .evidence:   return 11
        }
    }

    /// Dose to descend to before stopping the cuts.
    var floorMg: Double {
        switch self {
        case .sprint:     return 0.8
        case .lowAndHold: return 1.0
        case .measured:   return 2.0
        case .evidence:   return 5.0
        }
    }

    /// Days to hold at the floor before jumping off entirely.
    var holdAtFloorDays: Int {
        switch self {
        case .sprint:     return 3
        case .lowAndHold: return 28
        case .measured:   return 10
        case .evidence:   return 14
        }
    }

    /// The honest cost of choosing this. No pace is presented as free.
    var tradeoff: String {
        switch self {
        case .sprint:
            return "Roughly four times the reduction rate the evidence supports. Expect real withdrawal most days, and expect the last few steps to be the hardest part of the whole taper — occupancy falls fastest at the bottom. The failure mode to watch for is overshooting into withdrawal, dosing to fix it, and landing above where you started."
        case .lowAndHold:
            return "The aggressive descent is front-loaded where you have the most room, then a month at 1 mg lets the receptors adapt before the jump instead of doing both at once. Structurally the most defensible of the fast options."
        case .measured:
            return "Still faster than the literature supports, but each step gets three days to land — enough to tell a rough patch from a step that didn't settle."
        case .evidence:
            return "The rate with the best completion odds. Tapers this length are roughly 3.6× more likely to finish than short ones. It is also five months of this being a thing you think about."
        }
    }

    /// Whether the schedule requires sub-tablet precision, which matters because
    /// it isn't optional — a 10 mg tablet cannot be split into 1 mg by hand.
    func requiresSolution(from dose: Double) -> Bool {
        floorMg < 2.5
    }

    // MARK: - Schedule

    struct Day: Identifiable {
        var id: Int { dayOffset }
        let dayOffset: Int
        let date: Date
        let mg: Double
        let isFloorHold: Bool
    }

    /// Day-by-day schedule from the current dose to zero.
    func schedule(from currentMg: Double, startingOn start: Date = Date()) -> [Day] {
        var days: [Day] = []
        var dose = currentMg
        var offset = 0
        let cal = Calendar.current

        // Descent.
        while dose > floorMg && offset < 400 {
            let date = cal.date(byAdding: .day, value: offset, to: start) ?? start
            days.append(Day(dayOffset: offset, date: date, mg: round(dose * 100) / 100, isFloorHold: false))
            for _ in 0..<stepDays {
                offset += 1
            }
            dose *= (1 - stepFraction)
        }

        // Hold at the floor.
        let floorStart = offset
        for i in 0..<holdAtFloorDays {
            let date = cal.date(byAdding: .day, value: floorStart + i, to: start) ?? start
            days.append(Day(dayOffset: floorStart + i, date: date, mg: floorMg, isFloorHold: true))
        }

        return days
    }

    func finishDate(from currentMg: Double, startingOn start: Date = Date()) -> Date? {
        guard let last = schedule(from: currentMg, startingOn: start).last else { return nil }
        return Calendar.current.date(byAdding: .day, value: 1, to: last.date)
    }

    /// The dose the schedule puts you on today.
    func doseOn(day: Int, from currentMg: Double) -> Double {
        let sched = schedule(from: currentMg)
        return sched.last { $0.dayOffset <= day }?.mg ?? currentMg
    }
}
