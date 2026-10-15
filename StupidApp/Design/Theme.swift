import SwiftUI

/// "Tidewater" — deep water, desaturated teal, one big number per screen.
/// Calm by default. Amber, never red, when off-plan: an over-plan dose is a data
/// point, and colouring it like an alarm is how apps teach people to stop logging.
enum Theme {

    // MARK: - Ground

    static let deep = Color(red: 0.047, green: 0.082, blue: 0.149)
    static let deepMid = Color(red: 0.055, green: 0.102, blue: 0.180)
    static let deepLow = Color(red: 0.063, green: 0.125, blue: 0.227)

    static var ground: LinearGradient {
        LinearGradient(
            colors: [deep, deepMid, deepLow],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: - Ink

    static let ink = Color(red: 0.918, green: 0.945, blue: 0.973)
    static let inkSoft = Color(red: 0.725, green: 0.780, blue: 0.839)
    static let inkFaint = Color(red: 0.494, green: 0.576, blue: 0.675)

    // MARK: - Accent

    static let tide = Color(red: 0.345, green: 0.761, blue: 0.710)
    static let tideDeep = Color(red: 0.243, green: 0.612, blue: 0.573)
    static let tideGlow = Color(red: 0.482, green: 0.816, blue: 0.776)

    /// Off-plan. Warm, legible, unalarming.
    static let amber = Color(red: 0.847, green: 0.667, blue: 0.322)

    static var tideGradient: LinearGradient {
        LinearGradient(
            colors: [tideDeep, tide],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    // MARK: - Type

    /// One big number per screen. Rounded because this app is used at 2am by
    /// someone who feels bad, and geometric numerals read colder than they need to.
    static func numeral(_ size: CGFloat) -> Font {
        .system(size: size, weight: .bold, design: .rounded)
    }

    static func label(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

extension View {
    /// The app's ground. Painted explicitly so the view never borrows a host
    /// background it did not choose.
    func tidewaterBackground() -> some View {
        background(Theme.ground.ignoresSafeArea())
    }
}
