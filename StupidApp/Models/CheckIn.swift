import Foundation
import SwiftData

/// The 16 items of the Subjective Opiate Withdrawal Scale (Handelsman et al.,
/// 1987), each rated 0–4. The scale has no validated absolute cut-points — it is
/// built to measure change within one person over time, which is exactly what a
/// taper needs. Score against your own pre-step baseline, never a fixed threshold.
enum SOWSItem: Int, CaseIterable, Identifiable {
    case anxious, yawning, perspiring, teary, noseRunning, goosebumps
    case shaking, hotFlushes, coldFlushes, bonesAche, restless
    case nauseous, vomiting, musclesTwitch, stomachCramps, feelLikeUsing

    var id: Int { rawValue }

    var text: String {
        switch self {
        case .anxious:        return "I feel anxious"
        case .yawning:        return "I feel like yawning"
        case .perspiring:     return "I am perspiring"
        case .teary:          return "My eyes are teary"
        case .noseRunning:    return "My nose is running"
        case .goosebumps:     return "I have goosebumps"
        case .shaking:        return "I am shaking"
        case .hotFlushes:     return "I have hot flushes"
        case .coldFlushes:    return "I have cold flushes"
        case .bonesAche:      return "My bones and muscles ache"
        case .restless:       return "I feel restless"
        case .nauseous:       return "I feel nauseous"
        case .vomiting:       return "I feel like vomiting"
        case .musclesTwitch:  return "My muscles twitch"
        case .stomachCramps:  return "I have stomach cramps"
        case .feelLikeUsing:  return "I feel like using now"
        }
    }

    /// Item 16 is a craving item, not a physiological one. Kept separate so a
    /// craving spike does not masquerade as withdrawal and trigger a spurious hold.
    var isCraving: Bool { self == .feelLikeUsing }

    static let anchors = ["Not at all", "A little", "Moderately", "Quite a bit", "Extremely"]
}

/// How a set of scores came to exist.
enum CheckInSource: String, Codable {
    /// The user typed or spoke freely and a model scored it.
    case inferred
    /// The user filled in the actual 16-item questionnaire.
    case measured
}

/// A moment of "here's how I feel," whenever it happens.
///
/// The 16-item form is the right instrument and the wrong interface — sixteen taps
/// every evening is the symptomScore that kills logging adherence. So the primary path
/// is free text, scored onto the same items. The real questionnaire runs
/// periodically to keep the inference honest.
@Model
final class CheckIn {
    var id: UUID = UUID()
    var timestamp: Date = Date()

    /// What the user actually said, verbatim. Never overwritten by the model's
    /// interpretation — this is the ground truth the parse is auditable against.
    var text: String = ""

    var sourceRaw: String = CheckInSource.inferred.rawValue
    var wasSpoken: Bool = false

    /// 16 SOWS scores, 0–4. Derived from the tapped capsules.
    var scores: [Int] = []

    /// The capsules that were tapped, and how hard. Parallel arrays because
    /// SwiftData stores those cleanly and a dictionary would need a transformer.
    var symptomCodes: [String] = []
    var symptomLevels: [Int] = []

    /// The model's verbatim justification, so any inferred severity can be checked
    /// against the user's own words.
    var evidence: String?

    /// Set when the model declined to parse. Stored rather than discarded so the
    /// app knows which entries were never analysed and can retry them later.
    var parseFailureReason: String?

    /// Bumped whenever the parsing prompt or schema changes, so stale assessments
    /// are findable and re-runnable.
    var promptVersion: Int = 1

    var userEdited: Bool = false

    init(
        timestamp: Date = Date(),
        text: String,
        source: CheckInSource = .inferred,
        wasSpoken: Bool = false,
        scores: [Int] = []
    ) {
        self.id = UUID()
        self.timestamp = timestamp
        self.text = text
        self.sourceRaw = source.rawValue
        self.wasSpoken = wasSpoken
        self.scores = scores
    }

    var source: CheckInSource {
        get { CheckInSource(rawValue: sourceRaw) ?? .inferred }
        set { sourceRaw = newValue.rawValue }
    }

    var isScored: Bool { scores.count == SOWSItem.allCases.count }

    /// The tapped capsules, rehydrated.
    var symptoms: [(symptom: Symptom, severity: Severity)] {
        zip(symptomCodes, symptomLevels).compactMap { code, level in
            guard let s = Symptom(rawValue: code),
                  let sev = Severity(rawValue: level) else { return nil }
            return (s, sev)
        }
    }

    /// Writes the capsule selection and derives the SOWS scores from it, so the
    /// validated scale stays computed underneath without anyone filling a form.
    func apply(_ selection: [Symptom: Severity]) {
        let active = selection.filter { $0.value != .none }
        symptomCodes = active.keys.map(\.rawValue)
        symptomLevels = active.keys.map { selection[$0]?.rawValue ?? 0 }

        var derived = [Int](repeating: 0, count: SOWSItem.allCases.count)
        for (symptom, severity) in active {
            if let item = symptom.sowsItem {
                derived[item.rawValue] = max(derived[item.rawValue], severity.sowsValue)
            }
        }
        scores = derived
    }

    /// Severity across everything tapped, craving excluded. This is the number
    /// the taper assessment actually watches.
    var symptomScore: Int {
        symptoms
            .filter { !$0.symptom.isCraving }
            .reduce(0) { $0 + $1.severity.rawValue }
    }

    var cravingLevel: Int {
        symptoms.first { $0.symptom.isCraving }?.severity.rawValue ?? 0
    }

    /// Items 1–15. The physiological and affective withdrawal signal.
    var withdrawalScore: Int? {
        guard isScored else { return nil }
        return scores.enumerated()
            .filter { SOWSItem(rawValue: $0.offset)?.isCraving == false }
            .reduce(0) { $0 + $1.element }
    }

    /// Item 16 alone.
    var cravingScore: Int? {
        guard isScored else { return nil }
        return scores[SOWSItem.feelLikeUsing.rawValue]
    }

    /// Full SOWS total, 0–64.
    var totalScore: Int? {
        guard isScored else { return nil }
        return scores.reduce(0, +)
    }
}
