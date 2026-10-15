import Foundation

/// Deterministic keyword scoring of a free-text check-in onto the 16 SOWS items.
///
/// This is the **fallback tier**, not the copilot. The real design puts Apple's
/// on-device model here, but that model applies safety filtering to both prompts
/// and outputs and there are field reports of health and substance terminology
/// tripping refusals — and a guardrail refusal is non-recoverable. So the app
/// needs a path that always works, and this is it. When the model tier lands it
/// will produce better scores; this one guarantees a check-in is never lost.
///
/// It is intentionally conservative: it only scores what it can actually find,
/// leaves everything else at zero, and reports which phrases it matched so the
/// scoring is auditable against the user's own words.
enum SymptomParser {

    struct Match {
        let item: SOWSItem
        let phrase: String
        let score: Int
    }

    struct Result {
        var scores: [Int]
        var matches: [Match]

        var evidence: String {
            matches
                .map { "\($0.item.text.lowercased()) ← \"\($0.phrase)\"" }
                .joined(separator: "; ")
        }
    }

    /// Phrases people actually use, mapped to the item they indicate.
    private static let lexicon: [(SOWSItem, [String])] = [
        (.anxious,       ["anxious", "anxiety", "on edge", "panicky", "panic", "dread", "wired", "keyed up"]),
        (.yawning,       ["yawning", "yawn"]),
        (.perspiring,    ["sweating", "sweaty", "sweat", "clammy", "drenched", "night sweats"]),
        (.teary,         ["watery eyes", "teary", "eyes running", "watering eyes"]),
        (.noseRunning,   ["runny nose", "nose running", "sniffles", "congested", "snotty"]),
        (.goosebumps,    ["goosebumps", "goose bumps", "skin crawling", "gooseflesh"]),
        (.shaking,       ["shaking", "shaky", "tremor", "trembling", "jittery"]),
        (.hotFlushes,    ["hot flush", "hot flash", "overheating", "burning up", "too hot"]),
        (.coldFlushes,   ["chills", "cold flush", "shivering", "freezing", "cold sweat"]),
        (.bonesAche,     ["ache", "aching", "bones hurt", "muscles hurt", "sore", "body hurts", "pain", "joints"]),
        (.restless,      ["restless", "can't sit still", "cant sit still", "legs won't stop", "legs wont stop",
                          "rls", "twitchy legs", "fidgety", "crawling out of my skin"]),
        (.nauseous,      ["nauseous", "nausea", "queasy", "sick to my stomach"]),
        (.vomiting,      ["throwing up", "vomit", "threw up", "puking"]),
        (.musclesTwitch, ["twitching", "twitch", "spasms", "jerking"]),
        (.stomachCramps, ["cramps", "cramping", "stomach hurts", "gut", "diarrhea", "diarrhoea", "the runs"]),
        (.feelLikeUsing, ["want to use", "craving", "crave", "want a dose", "tempted", "want more",
                          "thinking about taking", "need a dose"])
    ]

    /// Words that push a matched symptom up or down the 0–4 scale.
    private static let intensifiers = ["really", "very", "so ", "extremely", "terrible", "awful",
                                       "unbearable", "worst", "brutal", "severe", "can't take"]
    private static let diminishers = ["a bit", "slightly", "a little", "mild", "manageable",
                                      "not too bad", "kind of", "sort of", "barely"]
    private static let negators = ["no ", "not ", "n't", "without", "none", "zero"]

    static func parse(_ text: String) -> Result {
        let lower = text.lowercased()
        var scores = [Int](repeating: 0, count: SOWSItem.allCases.count)
        var matches: [Match] = []

        let hasIntensifier = intensifiers.contains { lower.contains($0) }
        let hasDiminisher = diminishers.contains { lower.contains($0) }

        for (item, phrases) in lexicon {
            for phrase in phrases where lower.contains(phrase) {
                guard !isNegated(phrase: phrase, in: lower) else { continue }

                var score = 2
                if hasIntensifier { score += 1 }
                if hasDiminisher { score -= 1 }
                score = min(4, max(1, score))

                if score > scores[item.rawValue] {
                    scores[item.rawValue] = score
                    matches.removeAll { $0.item == item }
                    matches.append(Match(item: item, phrase: phrase, score: score))
                }
                break
            }
        }

        return Result(scores: scores, matches: matches)
    }

    /// Cheap negation check — looks for a negator in the ~18 characters before the
    /// match, which catches "no nausea" and "not shaking" without needing a parser.
    private static func isNegated(phrase: String, in text: String) -> Bool {
        guard let range = text.range(of: phrase) else { return false }
        let start = text.index(range.lowerBound, offsetBy: -18, limitedBy: text.startIndex)
            ?? text.startIndex
        let window = String(text[start..<range.lowerBound])
        return negators.contains { window.contains($0) }
    }
}
