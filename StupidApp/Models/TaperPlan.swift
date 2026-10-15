import Foundation
import SwiftData

/// Where the taper currently stands. There is deliberately no streak counter and
/// no "days behind" anywhere in this model — a hold shifts the projection and
/// nothing else. Progress is measured against baseline, which only accumulates.
@Model
final class TaperPlan {
    var id: UUID = UUID()
    var startDate: Date = Date()

    /// Nominal mg/day at the start of the whole taper.
    var baselineMgPerDay: Double = 45

    /// The current step's target nominal mg/day.
    var currentTargetMgPerDay: Double = 15

    /// When the current step began. Reductions are gated on this plus the
    /// delayed-feedback window.
    var currentStepStarted: Date = Date()

    var currentStepIndex: Int = 1

    /// Dose below which the plan switches from cutting to extending the interval
    /// between doses, per HHS guidance that opioids may be stopped once taken
    /// less often than daily.
    var jumpOffMgPerDay: Double = 5

    /// Scheduled slot times as minutes past midnight. Three slots at 8am/12pm/5pm.
    var slotMinutes: [Int] = [480, 720, 1020]

    var isHolding: Bool = false
    var holdStarted: Date?
    var holdReason: String?

    /// How fast to run this. A choice, not a number the app imposes — see
    /// `TaperPace`.
    var paceRaw: String = TaperPace.evidence.rawValue

    var pace: TaperPace {
        get { TaperPace(rawValue: paceRaw) ?? .evidence }
        set {
            paceRaw = newValue.rawValue
            jumpOffMgPerDay = newValue.floorMg
        }
    }

    init(
        startDate: Date = Date(),
        baselineMgPerDay: Double = 45,
        currentTargetMgPerDay: Double = 15,
        jumpOffMgPerDay: Double = 5,
        slotMinutes: [Int] = [480, 720, 1020]
    ) {
        self.id = UUID()
        self.startDate = startDate
        self.baselineMgPerDay = baselineMgPerDay
        self.currentTargetMgPerDay = currentTargetMgPerDay
        self.currentStepStarted = startDate
        self.jumpOffMgPerDay = jumpOffMgPerDay
        self.slotMinutes = slotMinutes
    }

    var fractionOfBaseline: Double {
        guard baselineMgPerDay > 0 else { return 1 }
        return currentTargetMgPerDay / baselineMgPerDay
    }

    var percentBelowBaseline: Int {
        Int(((1 - fractionOfBaseline) * 100).rounded())
    }

    var perSlotTargetMg: Double {
        guard !slotMinutes.isEmpty else { return currentTargetMgPerDay }
        return currentTargetMgPerDay / Double(slotMinutes.count)
    }

    var daysOnCurrentStep: Int {
        Calendar.current.dateComponents([.day], from: currentStepStarted, to: Date()).day ?? 0
    }

    var recommendedStepDays: Int { pace.stepDays }

    var nextTargetMgPerDay: Double {
        max(pace.floorMg, round(currentTargetMgPerDay * (1 - pace.stepFraction) * 100) / 100)
    }

    var stepsRemaining: Int {
        max(0, pace.schedule(from: currentTargetMgPerDay).filter { !$0.isFloorHold }.count - 1)
    }

    var projectedFinish: Date? {
        pace.finishDate(from: currentTargetMgPerDay)
    }

    /// 7-OH accumulates to a >20 hour effective half-life in daily users, so a cut
    /// can feel fine for two days and bite on the third. No step-down is offered
    /// before this window has passed, regardless of how good the data looks.
    static let delayedFeedbackDays = 4

    var isEligibleForStepDown: Bool {
        !isHolding
            && daysOnCurrentStep >= max(recommendedStepDays, Self.delayedFeedbackDays)
            && currentTargetMgPerDay > jumpOffMgPerDay
    }
}
