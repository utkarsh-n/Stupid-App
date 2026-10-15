import WidgetKit
import SwiftUI
import ActivityKit

/// The countdown, on the Lock Screen and in the Dynamic Island.
///
/// Every time value here uses `Text(timerInterval:)` or `ProgressView(timerInterval:)`,
/// which the system advances itself. That's the whole trick: the countdown stays
/// accurate for hours with the app closed, no background execution, no push
/// notifications, nothing to keep alive.
struct DoseCountdownActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DoseActivityAttributes.self) { context in
            lockScreen(context)
                .activityBackgroundTint(Theme.deep.opacity(0.9))
                .activitySystemActionForegroundColor(Theme.tide)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label(context.state.label, systemImage: "hourglass")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.inkSoft)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if context.state.isOpen {
                        Text("Open")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(Theme.tideGlow)
                    } else {
                        Text(timerInterval: Date()...context.state.nextDoseAt, countsDown: true)
                            .font(.title3.weight(.bold))
                            .monospacedDigit()
                            .multilineTextAlignment(.trailing)
                            .foregroundStyle(Theme.tideGlow)
                            .frame(maxWidth: 90)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ProgressView(
                        timerInterval: context.attributes.startedAt...context.state.nextDoseAt,
                        countsDown: false
                    )
                    .tint(Theme.tide)
                    .labelsHidden()
                }
            } compactLeading: {
                Image(systemName: "hourglass")
                    .foregroundStyle(Theme.tide)
            } compactTrailing: {
                if context.state.isOpen {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Theme.tideGlow)
                } else {
                    Text(timerInterval: Date()...context.state.nextDoseAt, countsDown: true)
                        .monospacedDigit()
                        .frame(maxWidth: 46)
                        .foregroundStyle(Theme.tideGlow)
                }
            } minimal: {
                Image(systemName: "hourglass")
                    .foregroundStyle(Theme.tide)
            }
        }
    }

    /// Lock Screen presentation. Deliberately says nothing about what is being
    /// counted down to — this renders where other people can see it.
    private func lockScreen(_ context: ActivityViewContext<DoseActivityAttributes>) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Label(context.state.label, systemImage: "hourglass")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.inkFaint)
                Spacer()
                if context.state.isOpen {
                    Text("Open now")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Theme.tideGlow)
                } else {
                    Text(timerInterval: Date()...context.state.nextDoseAt, countsDown: true)
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .monospacedDigit()
                        .multilineTextAlignment(.trailing)
                        .foregroundStyle(Theme.ink)
                        .frame(maxWidth: 120)
                }
            }

            ProgressView(
                timerInterval: context.attributes.startedAt...context.state.nextDoseAt,
                countsDown: false
            )
            .tint(Theme.tide)
            .labelsHidden()

            HStack {
                Text(context.state.nextDoseAt, style: .time)
                    .font(.caption2)
                    .foregroundStyle(Theme.inkFaint)
                Spacer()
                Text("waves pass")
                    .font(.caption2)
                    .foregroundStyle(Theme.inkFaint)
            }
        }
        .padding(16)
    }
}
