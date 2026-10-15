import Foundation

/// Reads symptom check-ins against where the taper actually is, and says whether
/// what you're feeling is the expected cost of the last cut or a sign the step
/// was too big.
///
/// The whole thing turns on 7-OH's timing. Withdrawal onset runs 8–12 hours after
/// a dose drop and peaks at 24–72 hours, so a symptom spike on days 1–3 after a
/// reduction is the reduction working, not the reduction failing. What matters is
/// whether it *settles*. Symptoms still climbing on day 4+ mean the body hasn't
/// adapted to the new level, and the answer to that is a hold, not willpower.
///
/// Everything is judged against the person's own pre-cut baseline. The SOWS has
/// no validated absolute cut-points and was built to measure change within one
/// person over time; treating some fixed number as "bad" would be inventing a
/// threshold the instrument doesn't have.
enum TaperAssessment {

    enum Verdict {
        case notEnoughData
        case settled        // quiet, and the step has had time to land
        case expected       // rough, but it's the acute window
        case notSettling    // past the acute window and still climbing
        case tooSteep       // severe, or sustained well past where it should ease
    }

    struct Result {
        var verdict: Verdict
        var headline: String
        var detail: String
        var recommendsHold: Bool
        var clearsStepDown: Bool
        var symptomScore: Int
        var trend: Int          // change vs the pre-cut reference
    }

    /// Days after a reduction during which a symptom spike is expected rather
    /// than alarming — the acute window for a drug with this half-life.
    static let acuteWindowDays = 3

    static func evaluate(
        checkIns: [CheckIn],
        plan: TaperPlan,
        physiology: Physiology? = nil,
        now: Date = Date()
    ) -> Result {
        let recent = checkIns
            .filter { $0.timestamp <= now }
            .sorted { $0.timestamp > $1.timestamp }

        guard let latest = recent.first else {
            return Result(
                verdict: .notEnoughData,
                headline: "No check-ins yet",
                detail: "Tap how you're feeling and this starts reading your pattern against the taper.",
                recommendsHold: false,
                clearsStepDown: false,
                symptomScore: 0,
                trend: 0
            )
        }

        let symptomScore = latest.symptomScore
        let daysSinceCut = max(0, Calendar.current.dateComponents(
            [.day], from: plan.currentStepStarted, to: now
        ).day ?? 0)

        // Reference point: how things sat just before the current step began.
        let priorToCut = recent.filter { $0.timestamp < plan.currentStepStarted }
        let reference = priorToCut.isEmpty
            ? averageSymptomScore(Array(recent.dropFirst().prefix(3)))
            : averageSymptomScore(Array(priorToCut.prefix(3)))
        let trend = symptomScore - reference

        let severeCount = latest.symptoms.filter { $0.severity == .bad }.count
        let inAcuteWindow = daysSinceCut <= acuteWindowDays

        // The body registering a cut before it's being felt. Checked before the
        // symptom branches precisely because symptoms are still quiet here —
        // nothing else in this function would catch it.
        if let warning = physiology?.earlyWarning(daysSinceCut: daysSinceCut, symptomScore: symptomScore) {
            return Result(
                verdict: .expected,
                headline: "Your body noticed before you did",
                detail: warning,
                recommendsHold: false,
                clearsStepDown: false,
                symptomScore: symptomScore,
                trend: trend
            )
        }

        // Severe and sustained, or severe well past the acute window.
        if severeCount >= 4 && !inAcuteWindow {
            return Result(
                verdict: .tooSteep,
                headline: "This step is too steep",
                detail: "Day \(daysSinceCut) and \(severeCount) symptoms are still at the top of the scale. That's past the window where a cut should be easing. Holding here is the protocol, not a setback.",
                recommendsHold: true,
                clearsStepDown: false,
                symptomScore: symptomScore,
                trend: trend
            )
        }

        // Still climbing after the acute window should have started resolving.
        if trend > 4 && !inAcuteWindow {
            return Result(
                verdict: .notSettling,
                headline: "Not settling yet",
                detail: "You're \(daysSinceCut) days past the cut and still above where you were before it. Withdrawal from this should peak by day 3 and ease after. Worth holding until it comes down.",
                recommendsHold: true,
                clearsStepDown: false,
                symptomScore: symptomScore,
                trend: trend
            )
        }

        // Rough, but it's the acute window — this is the cut working.
        if symptomScore > reference + 2 && inAcuteWindow {
            return Result(
                verdict: .expected,
                headline: "Expected for day \(daysSinceCut)",
                detail: "Symptoms peak 24–72 hours after a reduction, so this is the cut landing rather than going wrong. If it's still climbing on day \(acuteWindowDays + 1), that changes the answer.",
                recommendsHold: false,
                clearsStepDown: false,
                symptomScore: symptomScore,
                trend: trend
            )
        }

        // Quiet enough, and the step has had time.
        let hadTime = daysSinceCut >= max(plan.recommendedStepDays, TaperPlan.delayedFeedbackDays)
        if symptomScore <= reference + 2 {
            // Symptoms being quiet isn't sufficient on its own. Wanting to be
            // finished is motivation enough to under-report, and resting heart
            // rate doesn't share the motivation.
            let bodySettled = physiology?.readsSettled ?? true
            if hadTime && !bodySettled, let hr = physiology?.restingHR {
                return Result(
                    verdict: .expected,
                    headline: "You feel fine, your pulse doesn't",
                    detail: "Symptoms are near baseline but resting heart rate is still \(Int(hr.delta.rounded())) bpm above where it sat before this cut. Elevated pulse is a scored withdrawal sign. Worth another day before reducing again.",
                    recommendsHold: false,
                    clearsStepDown: false,
                    symptomScore: symptomScore,
                    trend: trend
                )
            }

            return Result(
                verdict: .settled,
                headline: hadTime ? "Settled — clear to step down" : "Settled at this dose",
                detail: hadTime
                    ? "Symptoms are back near your pre-cut baseline\(physiology?.restingHR != nil ? " and your resting heart rate has come back with them" : "") and the step has had time to land. The next reduction is available whenever you want it."
                    : "Symptoms are near baseline. Day \(daysSinceCut) of \(plan.recommendedStepDays) — the wait is for the accumulation to catch up, not for you.",
                recommendsHold: false,
                clearsStepDown: hadTime,
                symptomScore: symptomScore,
                trend: trend
            )
        }

        return Result(
            verdict: .expected,
            headline: "Elevated, holding steady",
            detail: "Above your baseline but not climbing. Worth watching for another day before deciding anything.",
            recommendsHold: false,
            clearsStepDown: false,
            symptomScore: symptomScore,
            trend: trend
        )
    }

    private static func averageSymptomScore(_ entries: [CheckIn]) -> Int {
        guard !entries.isEmpty else { return 0 }
        return entries.reduce(0) { $0 + $1.symptomScore } / entries.count
    }
}
