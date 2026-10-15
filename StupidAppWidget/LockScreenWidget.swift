import WidgetKit
import SwiftUI

/// Lock Screen complications: the ring's number, at a glance, without unlocking.
///
/// Accessory families render monochrome and get tinted by the system, so there's
/// no colour to lean on — the shapes have to carry it. And nothing here names
/// the substance, because this sits on a screen other people can see.
struct LockScreenWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "LockScreenWidget", provider: TodayProvider()) { entry in
            LockScreenView(entry: entry)
        }
        .configurationDisplayName("Left today")
        .description("How much is left, on the Lock Screen.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

struct LockScreenView: View {
    @Environment(\.widgetFamily) private var family
    var entry: TodayEntry

    private var remaining: Double { max(0, entry.targetMg - entry.loggedMg) }
    private var progress: Double {
        entry.targetMg > 0 ? min(1, entry.loggedMg / entry.targetMg) : 0
    }

    var body: some View {
        switch family {
        case .accessoryCircular:
            circular
        case .accessoryInline:
            Text("\(remaining.doseFormatted) mg left")
        default:
            rectangular
        }
    }

    private var circular: some View {
        Gauge(value: progress) {
            Text("mg")
        } currentValueLabel: {
            Text(remaining.doseFormatted)
                .font(.system(.title3, design: .rounded, weight: .semibold))
                .minimumScaleFactor(0.6)
        }
        .gaugeStyle(.accessoryCircular)
        .containerBackground(for: .widget) { }
    }

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 4) {
                Text(remaining.doseFormatted)
                    .font(.system(.title2, design: .rounded, weight: .bold))
                Text("mg left")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let next = entry.nextSlotAt {
                Text("next \(next, style: .time) · \(entry.filledSlots)/\(entry.totalSlots)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                Text("all logged · \(entry.percentBelowBaseline)% below baseline")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .containerBackground(for: .widget) { }
    }
}
