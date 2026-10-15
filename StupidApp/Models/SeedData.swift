import Foundation

extension Preparation {
    /// The five products currently in rotation, plus the powder.
    ///
    /// Worth reading the strengths together: halved on the score line, three doses
    /// a day lands anywhere from 15 mg (all Omega) to 27 mg (all KratomHeads) —
    /// an 80% swing from nothing but which bottle is open. That is the whole
    /// argument for the solution.
    static var userProducts: [Preparation] {
        [
            Preparation(label: "Omega Extracts", kind: .tablet, strengthPerUnit: 10),
            Preparation(label: "7-OHMIT", kind: .tablet, strengthPerUnit: 11),
            Preparation(label: "RAW MIT", kind: .tablet, strengthPerUnit: 12),
            Preparation(
                label: "BulkKratomCapsules",
                kind: .capsule,
                strengthPerUnit: 13,
                notes: "No score line — cannot be halved accurately."
            ),
            Preparation(label: "KratomHeads", kind: .tablet, strengthPerUnit: 18),
            Preparation(
                label: "Astral Glitter",
                kind: .powder,
                strengthPerUnit: 1,
                purity: 0.95,
                isActive: false,
                notes: "95%+ purity. The precision this taper needs — see the crossover protocol."
            )
        ]
    }
}
