import Foundation
import HealthKit

/// Reads the physiological signals that corroborate — or contradict — what you
/// report feeling.
///
/// The point isn't a dashboard. Every taper decision this app makes currently
/// rests on self-report, and self-report is distorted by exactly the thing being
/// measured: withdrawal makes you read yourself worse than you are, and wanting
/// to be finished makes you minimise. Resting heart rate doesn't care which mood
/// you're in.
///
/// Resting pulse is a scored item on the COWS — the clinician-administered
/// withdrawal scale — which is what makes it more than a nice chart. Everything
/// here is compared against the person's own baseline, never a population norm.
@MainActor
@Observable
final class HealthService {

    static let shared = HealthService()

    private let store = HKHealthStore()

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }
    var lastError: String?

    /// HealthKit deliberately never reports whether *read* access was granted —
    /// `authorizationStatus(for:)` returns `.notDetermined` for read types no
    /// matter what, because answering honestly would leak whether the person has
    /// data of that kind. So there is nothing to query on launch, and the flag
    /// has to be remembered on our side instead.
    private static let grantedKey = "healthAuthorizationRequested"

    var isAuthorized: Bool {
        get { SharedStore.defaults.bool(forKey: Self.grantedKey) }
        set { SharedStore.defaults.set(newValue, forKey: Self.grantedKey) }
    }

    // MARK: - Types

    private var readTypes: Set<HKObjectType> {
        var types: Set<HKObjectType> = [
            HKQuantityType(.restingHeartRate),
            HKQuantityType(.heartRateVariabilitySDNN),
            HKQuantityType(.respiratoryRate),
            HKQuantityType(.stepCount),
            HKCategoryType(.sleepAnalysis)
        ]
        // Series 8 and later only; absent elsewhere, so it's added defensively
        // rather than assumed.
        types.insert(HKQuantityType(.appleSleepingWristTemperature))
        return types
    }

    private var writeTypes: Set<HKSampleType> {
        [HKObjectType.stateOfMindType()]
    }

    // MARK: - Authorization

    /// Re-asserts authorization on launch. This is intentionally called every
    /// time: `requestAuthorization` is idempotent and shows no prompt for types
    /// already decided, so it silently restores access rather than making
    /// someone tap Connect again on every cold start.
    func restoreAuthorizationIfGranted() async {
        guard isAvailable, isAuthorized else { return }
        try? await store.requestAuthorization(toShare: writeTypes, read: readTypes)
    }

    func requestAuthorization() async {
        guard isAvailable else {
            lastError = "Health data isn't available on this device."
            return
        }
        do {
            try await store.requestAuthorization(toShare: writeTypes, read: readTypes)
            isAuthorized = true
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    // MARK: - Reads

    /// Daily average of a quantity type across a date range.
    private func dailyAverages(
        for type: HKQuantityType,
        unit: HKUnit,
        from start: Date,
        to end: Date = Date()
    ) async -> [Date: Double] {
        await withCheckedContinuation { continuation in
            let interval = DateComponents(day: 1)
            let anchor = Calendar.current.startOfDay(for: start)
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end)

            let query = HKStatisticsCollectionQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .discreteAverage,
                anchorDate: anchor,
                intervalComponents: interval
            )

            query.initialResultsHandler = { _, results, _ in
                var output: [Date: Double] = [:]
                results?.enumerateStatistics(from: start, to: end) { stats, _ in
                    if let avg = stats.averageQuantity() {
                        output[Calendar.current.startOfDay(for: stats.startDate)] =
                            avg.doubleValue(for: unit)
                    }
                }
                continuation.resume(returning: output)
            }
            store.execute(query)
        }
    }

    /// Hours actually asleep per night, keyed by the morning the night ended.
    private func sleepHours(from start: Date, to end: Date = Date()) async -> [Date: Double] {
        await withCheckedContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
            let query = HKSampleQuery(
                sampleType: HKCategoryType(.sleepAnalysis),
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, _ in
                var totals: [Date: Double] = [:]
                let asleep: Set<Int> = [
                    HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                    HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
                    HKCategoryValueSleepAnalysis.asleepREM.rawValue,
                    HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue
                ]

                for case let sample as HKCategorySample in samples ?? [] {
                    guard asleep.contains(sample.value) else { continue }
                    // Attribute a night to the day it ends, so "last night" lands
                    // on this morning rather than yesterday.
                    let day = Calendar.current.startOfDay(for: sample.endDate)
                    let hours = sample.endDate.timeIntervalSince(sample.startDate) / 3600
                    totals[day, default: 0] += hours
                }
                continuation.resume(returning: totals)
            }
            store.execute(query)
        }
    }

    // MARK: - Snapshot

    struct Snapshot {
        var restingHR: [Date: Double] = [:]
        var hrv: [Date: Double] = [:]
        var respiratoryRate: [Date: Double] = [:]
        var sleep: [Date: Double] = [:]

        var hasAnyData: Bool {
            !restingHR.isEmpty || !hrv.isEmpty || !sleep.isEmpty
        }
    }

    func loadSnapshot(days: Int = 45) async -> Snapshot {
        guard isAvailable else { return Snapshot() }
        let start = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()

        async let hr = dailyAverages(for: HKQuantityType(.restingHeartRate),
                                     unit: .count().unitDivided(by: .minute()),
                                     from: start)
        async let hrv = dailyAverages(for: HKQuantityType(.heartRateVariabilitySDNN),
                                      unit: .secondUnit(with: .milli),
                                      from: start)
        async let rr = dailyAverages(for: HKQuantityType(.respiratoryRate),
                                     unit: .count().unitDivided(by: .minute()),
                                     from: start)
        async let sleep = sleepHours(from: start)

        return Snapshot(
            restingHR: await hr,
            hrv: await hrv,
            respiratoryRate: await rr,
            sleep: await sleep
        )
    }

    // MARK: - Writes

    /// Mirrors a check-in into Health as a State of Mind sample, so the record
    /// survives independently of this app and charts against everything else.
    func writeStateOfMind(valence: Double, at date: Date = Date()) async {
        guard isAvailable else { return }
        let clamped = max(-1, min(1, valence))
        let sample = HKStateOfMind(
            date: date,
            kind: .momentaryEmotion,
            valence: clamped,
            labels: [],
            associations: [.health]
        )
        do {
            try await store.save(sample)
        } catch {
            lastError = error.localizedDescription
        }
    }
}
