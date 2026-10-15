import WidgetKit
import SwiftUI
import SwiftData
import AppIntents

struct TodayEntry: TimelineEntry {
    var date: Date = Date()
    var loggedMg: Double = 0
    var targetMg: Double = 0
    var filledSlots: Int = 0
    var totalSlots: Int = 3
    var nextSlotAt: Date?
    var percentBelowBaseline: Int = 0
}

struct TodayProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodayEntry {
        TodayEntry(loggedMg: 5, targetMg: 15, filledSlots: 1, percentBelowBaseline: 67)
    }

    func getSnapshot(in context: Context, completion: @escaping (TodayEntry) -> Void) {
        completion(load())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodayEntry>) -> Void) {
        let entry = load()
        // Refresh at the next window, or in an hour if there isn't one left today.
        let next = entry.nextSlotAt ?? Date().addingTimeInterval(3600)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    private func load() -> TodayEntry {
        let context = ModelContext(SharedStore.container)
        guard let plan = try? context.fetch(FetchDescriptor<TaperPlan>()).first else {
            return TodayEntry()
        }

        let dayStart = Calendar.current.startOfDay(for: Date())
        let descriptor = FetchDescriptor<Intake>(
            predicate: #Predicate { $0.timestamp >= dayStart }
        )
        let todays = (try? context.fetch(descriptor))?
            .filter { $0.substanceRaw == Substance.sevenOH.rawValue } ?? []

        let filled = Set(todays.compactMap(\.slotIndex))
        let nextIndex = (0..<plan.slotMinutes.count).first { !filled.contains($0) }
        let nextAt = nextIndex.flatMap { index -> Date? in
            let minutes = plan.slotMinutes[index]
            return Calendar.current.date(
                bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: Date()
            )
        }

        return TodayEntry(
            loggedMg: todays.reduce(0) { $0 + $1.nominalMg },
            targetMg: plan.currentTargetMgPerDay,
            filledSlots: filled.count,
            totalSlots: plan.slotMinutes.count,
            nextSlotAt: nextAt,
            percentBelowBaseline: plan.percentBelowBaseline
        )
    }
}

// MARK: - Small

struct TodaySmallView: View {
    var entry: TodayEntry

    private var remaining: Double { max(0, entry.targetMg - entry.loggedMg) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("TODAY")
                .font(.system(size: 9.5, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.inkFaint)

            Spacer(minLength: 0)

            Text(remaining.doseFormatted)
                .font(.system(size: 38, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.ink)
                .contentTransition(.numericText())

            Text("mg left · \(entry.filledSlots)/\(entry.totalSlots)")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.inkFaint)

            Spacer(minLength: 6)

            Button(intent: LogDoseIntent()) {
                Text("Log")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.deep)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(Theme.tide))
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .containerBackground(for: .widget) { Theme.ground }
    }
}

// MARK: - Medium

struct TodayMediumView: View {
    var entry: TodayEntry

    private var remaining: Double { max(0, entry.targetMg - entry.loggedMg) }

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 0) {
                Text("TODAY")
                    .font(.system(size: 9.5, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.inkFaint)
                Spacer(minLength: 0)
                Text(remaining.doseFormatted)
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.ink)
                Text("mg left of \(entry.targetMg.doseFormatted)")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.inkFaint)
            }

            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 5) {
                    ForEach(0..<entry.totalSlots, id: \.self) { index in
                        Circle()
                            .fill(index < entry.filledSlots ? Theme.tide : Color.white.opacity(0.14))
                            .frame(width: 9, height: 9)
                    }
                }

                if let next = entry.nextSlotAt {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("NEXT")
                            .font(.system(size: 8.5, weight: .heavy, design: .rounded))
                            .foregroundStyle(Theme.inkFaint)
                        Text(next, style: .time)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.ink)
                    }
                } else {
                    Text("All logged")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.tideGlow)
                }

                Text("\(entry.percentBelowBaseline)% below baseline")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.tideGlow)

                Spacer(minLength: 0)

                Button(intent: LogDoseIntent()) {
                    Text("Log dose")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.deep)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(Theme.tide))
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: 150)
        }
        .containerBackground(for: .widget) { Theme.ground }
    }
}

struct TodayWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    var entry: TodayEntry

    var body: some View {
        switch family {
        case .systemMedium: TodayMediumView(entry: entry)
        default:            TodaySmallView(entry: entry)
        }
    }
}

struct TodayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "TodayWidget", provider: TodayProvider()) { entry in
            TodayWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Today")
        .description("What's left today, and a button to log without opening anything.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
