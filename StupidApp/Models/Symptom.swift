import Foundation

/// The symptoms worth tracking during a 7-OH taper, as tappable capsules.
///
/// Typing a paragraph is the wrong ask at 3am with restless legs. Each of these
/// is one tap, and tapping again raises severity, so a full check-in is a few
/// seconds of thumb work.
///
/// Where a symptom corresponds to a SOWS item it carries that mapping, so the
/// validated scale still gets computed underneath without anyone filling in a
/// sixteen-item form. The ones with no mapping are real 7-OH features the 1987
/// scale doesn't cover — insomnia and anhedonia especially, which providers
/// consistently report as worse and longer-lasting here than in classic opioid
/// withdrawal.
enum Symptom: String, Codable, CaseIterable, Identifiable {
    // Physical
    case bodyAches
    case restlessLegs
    case muscleCramps
    case twitching
    case shaking
    case sweating
    case chills
    case hotFlashes
    case goosebumps
    case runnyNose
    case wateryEyes
    case yawning
    case nausea
    case vomiting
    case stomachCramps
    case diarrhea
    case noAppetite
    case headache
    case dizzy
    case racingHeart

    // Mental
    case insomnia
    case fatigue
    case anxious
    case irritable
    case lowMood
    case anhedonia
    case brainFog
    case craving

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .bodyAches:     return "Body aches"
        case .restlessLegs:  return "Restless legs"
        case .muscleCramps:  return "Cramps"
        case .twitching:     return "Twitching"
        case .shaking:       return "Shaking"
        case .sweating:      return "Sweating"
        case .chills:        return "Chills"
        case .hotFlashes:    return "Hot flashes"
        case .goosebumps:    return "Goosebumps"
        case .runnyNose:     return "Runny nose"
        case .wateryEyes:    return "Watery eyes"
        case .yawning:       return "Yawning"
        case .nausea:        return "Nausea"
        case .vomiting:      return "Vomiting"
        case .stomachCramps: return "Stomach cramps"
        case .diarrhea:      return "Diarrhea"
        case .noAppetite:    return "No appetite"
        case .headache:      return "Headache"
        case .dizzy:         return "Dizzy"
        case .racingHeart:   return "Racing heart"
        case .insomnia:      return "Can't sleep"
        case .fatigue:       return "Exhausted"
        case .anxious:       return "Anxious"
        case .irritable:     return "Irritable"
        case .lowMood:       return "Low"
        case .anhedonia:     return "Nothing feels good"
        case .brainFog:      return "Brain fog"
        case .craving:       return "Craving"
        }
    }

    var symbolName: String {
        switch self {
        case .bodyAches:     return "figure.walk"
        case .restlessLegs:  return "figure.run"
        case .muscleCramps:  return "bolt.fill"
        case .twitching:     return "waveform.path"
        case .shaking:       return "hand.raised.fill"
        case .sweating:      return "drop.fill"
        case .chills:        return "snowflake"
        case .hotFlashes:    return "thermometer.sun.fill"
        case .goosebumps:    return "circle.grid.3x3.fill"
        case .runnyNose:     return "nose.fill"
        case .wateryEyes:    return "eye.fill"
        case .yawning:       return "mouth.fill"
        case .nausea:        return "tornado"
        case .vomiting:      return "arrow.up.circle.fill"
        case .stomachCramps: return "bolt.horizontal.fill"
        case .diarrhea:      return "toilet.fill"
        case .noAppetite:    return "fork.knife"
        case .headache:      return "brain.head.profile"
        case .dizzy:         return "arrow.trianglehead.2.clockwise"
        case .racingHeart:   return "heart.fill"
        case .insomnia:      return "moon.zzz.fill"
        case .fatigue:       return "battery.25percent"
        case .anxious:       return "wind"
        case .irritable:     return "exclamationmark.bubble.fill"
        case .lowMood:       return "cloud.rain.fill"
        case .anhedonia:     return "circle.slash"
        case .brainFog:      return "cloud.fog.fill"
        case .craving:       return "target"
        }
    }

    enum Category: String, CaseIterable, Identifiable {
        case physical, mental
        var id: String { rawValue }
        var displayName: String { self == .physical ? "Body" : "Head" }
    }

    var category: Category {
        switch self {
        case .insomnia, .fatigue, .anxious, .irritable,
             .lowMood, .anhedonia, .brainFog, .craving:
            return .mental
        default:
            return .physical
        }
    }

    /// Corresponding SOWS item, where one exists.
    var sowsItem: SOWSItem? {
        switch self {
        case .anxious:       return .anxious
        case .yawning:       return .yawning
        case .sweating:      return .perspiring
        case .wateryEyes:    return .teary
        case .runnyNose:     return .noseRunning
        case .goosebumps:    return .goosebumps
        case .shaking:       return .shaking
        case .hotFlashes:    return .hotFlushes
        case .chills:        return .coldFlushes
        case .bodyAches:     return .bonesAche
        case .restlessLegs:  return .restless
        case .nausea:        return .nauseous
        case .vomiting:      return .vomiting
        case .twitching:     return .musclesTwitch
        case .stomachCramps: return .stomachCramps
        case .craving:       return .feelLikeUsing
        default:             return nil
        }
    }

    /// Craving is tracked apart from the physical picture so a craving spike
    /// can't masquerade as withdrawal and trigger a hold on its own.
    var isCraving: Bool { self == .craving }

    static var physical: [Symptom] { allCases.filter { $0.category == .physical } }
    static var mental: [Symptom] { allCases.filter { $0.category == .mental } }
}

/// Tap once for mild, again for moderate, again for bad, again to clear.
enum Severity: Int, Codable, CaseIterable {
    case none = 0, mild = 1, moderate = 2, bad = 3

    var next: Severity { Severity(rawValue: (rawValue + 1) % 4) ?? .none }

    var displayName: String {
        switch self {
        case .none:     return "—"
        case .mild:     return "Mild"
        case .moderate: return "Moderate"
        case .bad:      return "Bad"
        }
    }

    /// SOWS uses 0–4; this uses 0–3 to keep tapping quick. Bad maps to 4 rather
    /// than 3 so a maxed-out capsule reaches the top of the validated scale.
    var sowsValue: Int {
        switch self {
        case .none: return 0
        case .mild: return 1
        case .moderate: return 2
        case .bad: return 4
        }
    }
}
