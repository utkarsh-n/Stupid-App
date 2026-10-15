import SwiftUI

/// What your body is doing, against what it was doing before the current cut.
///
/// Deliberately shows deltas rather than absolute numbers. A resting heart rate
/// of 68 means nothing without knowing yours normally sits at 58; the whole
/// value here is the comparison to your own baseline.
struct PhysiologyCard: View {
    let physiology: Physiology
    let isAuthorized: Bool
    let onConnect: () -> Void

    var body: some View {
        Card {
            HStack(spacing: 6) {
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 12, weight: .semibold))
                Text("What your body says")
                    .font(Theme.label(13, weight: .bold))
                Spacer()
                if physiology.hasData {
                    Text("vs before this cut")
                        .font(Theme.label(10, weight: .medium))
                        .foregroundStyle(Theme.inkFaint)
                }
            }
            .foregroundStyle(Theme.ink)

            if !isAuthorized {
                Text("Your Watch already measures resting heart rate, sleep, and HRV every night. Reading them gives the taper a second opinion that doesn't change with your mood.")
                    .font(Theme.label(12, weight: .regular))
                    .foregroundStyle(Theme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)

                Button(action: onConnect) {
                    Text("Connect Health")
                        .font(Theme.label(13, weight: .bold))
                        .foregroundStyle(Theme.tide)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Theme.tide.opacity(0.10))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Theme.tide.opacity(0.4), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)

            } else if !physiology.hasData {
                Text("Connected, but there isn't enough history yet. A few nights of wearing the Watch to bed and this fills in.")
                    .font(Theme.label(12, weight: .regular))
                    .foregroundStyle(Theme.inkFaint)
                    .fixedSize(horizontal: false, vertical: true)

            } else {
                VStack(spacing: 8) {
                    if let hr = physiology.restingHR {
                        row("Resting heart rate", hr, format: "%.0f")
                    }
                    if let sleep = physiology.sleep {
                        row("Sleep", sleep, format: "%.1f")
                    }
                    if let hrv = physiology.hrv {
                        row("HRV", hrv, format: "%.0f")
                    }
                    if let rr = physiology.respiratoryRate {
                        row("Breathing rate", rr, format: "%.1f")
                    }
                }
            }
        }
    }

    private func row(_ label: String, _ metric: Physiology.Metric, format: String) -> some View {
        let concerning = metric.isElevated && abs(metric.delta) > (metric.riseIsBad ? 3 : 0.5)
        let arrow = metric.delta > 0 ? "arrow.up" : (metric.delta < 0 ? "arrow.down" : "equal")

        return HStack(spacing: 8) {
            Text(label)
                .font(Theme.label(12.5, weight: .regular))
                .foregroundStyle(Theme.inkSoft)

            Spacer(minLength: 6)

            Text(String(format: format, metric.current) + " \(metric.unit)")
                .font(Theme.label(13, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .monospacedDigit()

            HStack(spacing: 2) {
                Image(systemName: arrow)
                    .font(.system(size: 8.5, weight: .bold))
                Text(String(format: format, abs(metric.delta)))
                    .font(Theme.label(11.5, weight: .bold))
                    .monospacedDigit()
            }
            .foregroundStyle(concerning ? Theme.amber : Theme.tideGlow)
            .frame(width: 46, alignment: .trailing)
        }
    }
}
