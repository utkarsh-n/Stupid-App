import Foundation

/// Turns raw HealthKit series into a read on where the body is, relative to
/// where it was before the current step.
///
/// Two jobs. First, a gate: symptoms being quiet isn't enough to clear a
/// reduction if resting heart rate is still elevated, because wanting to be
/// finished is a strong enough motivation to under-report. Second, an early
/// warning: autonomic markers tend to move before subjective symptoms peak, and
/// on a fast schedule that's the difference between catching an overshoot and
/// cutting again on top of one you haven't felt yet.
struct Physiology {

    struct Metric {
        let baseline: Double
        let current: Double
        var delta: Double { current - baseline }
        let unit: String
        /// True when a rise is the concerning direction (heart rate), false when
        /// a fall is (HRV, sleep).
        let riseIsBad: Bool

        var isElevated: Bool { riseIsBad ? delta > 0 : delta < 0 }
    }

    var restingHR: Metric?
    var hrv: Metric?
    var sleep: Metric?
    var respiratoryRate: Metric?

    var hasData: Bool {
        restingHR != nil || hrv != nil || sleep != nil
    }

    // MARK: - Thresholds

    /// Resting heart rate is a scored COWS item: 81–100 bpm scores 1, 101–120
    /// scores 2. Against a personal baseline, a few beats is noise and anything
    /// past this is signal.
    static let hrSettledMargin: Double = 3
    static let hrConcernMargin: Double = 5

    /// Whether the body looks like it has adapted to the current dose.
    var readsSettled: Bool {
        guard let restingHR else { return true }   // no data shouldn't block anything
        return restingHR.delta <= Self.hrSettledMargin
    }

    /// The body is registering the cut even though it isn't being felt yet.
    func earlyWarning(daysSinceCut: Int, symptomScore: Int) -> String? {
        guard let restingHR, restingHR.delta >= Self.hrConcernMargin else { return nil }
        guard daysSinceCut <= 3, symptomScore <= 6 else { return nil }
        return "Resting heart rate is \(Int(restingHR.delta.rounded())) bpm above your pre-cut baseline, but you're not reporting much. Autonomic signs usually move before symptoms peak — worth not cutting again until this comes down."
    }

    // MARK: - Build

    static func build(
        from snapshot: HealthService.Snapshot,
        stepStarted: Date,
        now: Date = Date()
    ) -> Physiology {
        Physiology(
            restingHR: metric(snapshot.restingHR, stepStarted: stepStarted, now: now,
                              unit: "bpm", riseIsBad: true),
            hrv: metric(snapshot.hrv, stepStarted: stepStarted, now: now,
                        unit: "ms", riseIsBad: false),
            sleep: metric(snapshot.sleep, stepStarted: stepStarted, now: now,
                          unit: "h", riseIsBad: false),
            respiratoryRate: metric(snapshot.respiratoryRate, stepStarted: stepStarted, now: now,
                                    unit: "br/min", riseIsBad: true)
        )
    }

    /// Baseline is the 21 days before the current step began; current is the
    /// mean of the last three readings, which smooths a single odd night without
    /// blunting a real move.
    private static func metric(
        _ series: [Date: Double],
        stepStarted: Date,
        now: Date,
        unit: String,
        riseIsBad: Bool
    ) -> Metric? {
        guard series.count >= 4 else { return nil }

        let baselineStart = Calendar.current.date(byAdding: .day, value: -21, to: stepStarted) ?? stepStarted
        let baselineValues = series
            .filter { $0.key >= baselineStart && $0.key < stepStarted }
            .map(\.value)

        let recentValues = series
            .sorted { $0.key > $1.key }
            .prefix(3)
            .map(\.value)

        guard !recentValues.isEmpty else { return nil }

        // With no pre-step history, fall back to everything older than the recent
        // window so there's still something to compare against.
        let baseline: [Double]
        if baselineValues.count >= 3 {
            baseline = baselineValues
        } else {
            let older = series.sorted { $0.key > $1.key }.dropFirst(3).map(\.value)
            guard older.count >= 3 else { return nil }
            baseline = Array(older)
        }

        return Metric(
            baseline: baseline.reduce(0, +) / Double(baseline.count),
            current: recentValues.reduce(0, +) / Double(recentValues.count),
            unit: unit,
            riseIsBad: riseIsBad
        )
    }
}
