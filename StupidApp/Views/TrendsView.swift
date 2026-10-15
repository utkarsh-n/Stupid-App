import SwiftUI
import SwiftData
import Charts

/// Every number on this screen either averages or only accumulates. Nothing here
/// can reset to zero, because a counter that resets after one bad day is a
/// literal instantiation of the all-or-nothing thinking that turns a lapse into
/// a relapse.
struct TrendsView: View {
    @Query private var plans: [TaperPlan]
    @Query(sort: \Intake.timestamp) private var intakes: [Intake]

    private var plan: TaperPlan? { plans.first }

    private var sevenOH: [Intake] {
        intakes.filter { $0.substance == .sevenOH }
    }

    /// Daily nominal totals for the last 30 days, including zero days.
    private var dailyTotals: [(date: Date, mg: Double)] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        guard let start = cal.date(byAdding: .day, value: -29, to: today) else { return [] }

        var buckets: [Date: Double] = [:]
        for intake in sevenOH {
            let day = cal.startOfDay(for: intake.timestamp)
            guard day >= start else { continue }
            buckets[day, default: 0] += intake.nominalMg
        }

        return (0..<30).compactMap { offset in
            guard let day = cal.date(byAdding: .day, value: offset, to: start) else { return nil }
            return (day, buckets[day] ?? 0)
        }
    }

    /// Rolling seven-day mean. The headline metric: a rough day dents it a
    /// couple of points instead of erasing everything.
    private var rollingAverage: [(date: Date, mg: Double)] {
        let totals = dailyTotals
        guard totals.count >= 7 else { return [] }
        return (6..<totals.count).map { i in
            let window = totals[(i - 6)...i].map(\.mg)
            return (totals[i].date, window.reduce(0, +) / 7)
        }
    }

    private var currentAverage: Double { rollingAverage.last?.mg ?? 0 }

    private var percentBelowBaseline: Int {
        guard let baseline = plan?.baselineMgPerDay, baseline > 0, currentAverage > 0 else {
            return plan?.percentBelowBaseline ?? 0
        }
        return Int(((1 - currentAverage / baseline) * 100).rounded())
    }

    /// Milligrams not taken, versus carrying on at baseline. Only goes up.
    ///
    /// Anchored to the earliest logged dose rather than the plan's start date,
    /// because the plan record can be created after logging has been going for a
    /// while and the shorter window would silently under-count.
    private var mgAvoided: Double {
        guard let plan else { return 0 }
        let anchor = min(plan.startDate, sevenOH.first?.timestamp ?? plan.startDate)
        let days = max(0, Calendar.current.dateComponents([.day], from: anchor, to: Date()).day ?? 0)
        let taken = sevenOH.reduce(0) { $0 + $1.nominalMg }
        return max(0, plan.baselineMgPerDay * Double(days) - taken)
    }

    /// Days with any dose logged, out of the last 30.
    ///
    /// Deliberately *not* "on-plan days." Judging a day from three weeks ago
    /// against today's lower target marks it off-plan for having been earlier in
    /// the taper, which is nonsense — and the app doesn't store what the target
    /// was on each past day. Logging coverage is something it can measure
    /// honestly, and it's also the behaviour that actually matters.
    private var loggedDays: (hit: Int, total: Int) {
        let window = dailyTotals.suffix(30)
        return (window.filter { $0.mg > 0 }.count, window.count)
    }

    private var withdrawalDrivenShare: Int? {
        let recent = sevenOH.filter {
            $0.timestamp > Date().addingTimeInterval(-14 * 86400)
        }
        guard recent.count >= 3 else { return nil }
        let driven = recent.filter { $0.reason == .withdrawal || $0.reason == .craving }.count
        return Int((Double(driven) / Double(recent.count) * 100).rounded())
    }

    var body: some View {
        ZStack {
            Theme.ground.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 14) {
                    averageCard
                    statGrid
                    if let share = withdrawalDrivenShare { reasonCard(share) }
                    if sevenOH.isEmpty { emptyNote }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
        }
        .safeAreaInset(edge: .top) { titleBar }
    }

    private var titleBar: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(plan.map { "since \($0.startDate.formatted(.dateTime.month().day()))" } ?? "")
                .font(Theme.label(12, weight: .medium))
                .foregroundStyle(Theme.inkFaint)
            Text("Trends")
                .font(Theme.label(24, weight: .bold))
                .foregroundStyle(Theme.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 22)
        .padding(.bottom, 8)
        .background(Theme.deep.opacity(0.9))
    }

    private var averageCard: some View {
        Card {
            HStack(alignment: .firstTextBaseline) {
                Text("7-day average")
                    .font(Theme.label(13, weight: .bold))
                    .foregroundStyle(Theme.ink)
                Spacer()
                Text("\(currentAverage.doseFormatted) mg")
                    .font(Theme.numeral(20))
                    .foregroundStyle(Theme.tideGlow)
                    .contentTransition(.numericText())
            }

            if rollingAverage.count > 1 {
                Chart(rollingAverage, id: \.date) { point in
                    AreaMark(
                        x: .value("Day", point.date),
                        y: .value("mg", point.mg)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Theme.tide.opacity(0.28), Theme.tide.opacity(0.02)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    LineMark(
                        x: .value("Day", point.date),
                        y: .value("mg", point.mg)
                    )
                    .foregroundStyle(Theme.tide)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine().foregroundStyle(Color.white.opacity(0.06))
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text("\(Int(v))").foregroundStyle(Theme.inkFaint)
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: 7)) { value in
                        AxisValueLabel(format: .dateTime.month().day())
                            .foregroundStyle(Theme.inkFaint)
                    }
                }
                .frame(height: 150)
            } else {
                Text("A week of logs will draw the curve here.")
                    .font(Theme.label(12, weight: .regular))
                    .foregroundStyle(Theme.inkFaint)
                    .frame(height: 60)
            }
        }
    }

    private var statGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
            stat("\(percentBelowBaseline)%", "below baseline")
            stat("\(mgAvoided.rounded().doseFormatted) mg", "not taken since starting")
            stat("\(loggedDays.hit)/\(loggedDays.total)", "days logged, last 30")
            stat(plan.map { "\($0.stepsRemaining)" } ?? "—", "steps to jump-off")
        }
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(Theme.numeral(21))
                .foregroundStyle(Theme.ink)
            Text(label)
                .font(Theme.label(10.5, weight: .regular))
                .foregroundStyle(Theme.inkFaint)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(13)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.07), lineWidth: 1)
        )
    }

    private func reasonCard(_ share: Int) -> some View {
        Card {
            Text("Why you dosed")
                .font(Theme.label(13, weight: .bold))
                .foregroundStyle(Theme.ink)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(share)%")
                    .font(Theme.numeral(26))
                    .foregroundStyle(share > 40 ? Theme.amber : Theme.tideGlow)
                Text("of the last two weeks' doses were withdrawal- or craving-driven rather than scheduled.")
                    .font(Theme.label(12, weight: .regular))
                    .foregroundStyle(Theme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(share > 40
                 ? "That's high enough to be worth a hold. When the schedule stops holding, the step is usually the problem rather than you."
                 : "Mostly on schedule, which is what you want before the next reduction.")
                .font(Theme.label(11.5, weight: .regular))
                .foregroundStyle(Theme.inkFaint)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var emptyNote: some View {
        Text("Log a few doses and this fills in.")
            .font(Theme.label(12.5, weight: .regular))
            .foregroundStyle(Theme.inkFaint)
            .padding(.top, 30)
    }
}
