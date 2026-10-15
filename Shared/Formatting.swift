import Foundation

extension Double {
    /// Doses are never shown with trailing zeros — "5" not "5.0" — but keep the
    /// decimal when the taper actually lands on one, because below 7 mg the steps
    /// are fractional and rounding them away would hide the plan.
    var doseFormatted: String {
        if self == rounded() { return String(Int(self)) }
        return String(format: "%.2f", self)
            .replacingOccurrences(of: "0$", with: "", options: .regularExpression)
    }
}

extension Int {
    /// Minutes past midnight as a local clock time.
    var asClockTime: String {
        var comps = DateComponents()
        comps.hour = self / 60
        comps.minute = self % 60
        let date = Calendar.current.date(from: comps) ?? Date()
        return date.formatted(date: .omitted, time: .shortened)
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
