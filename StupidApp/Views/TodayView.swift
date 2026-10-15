import SwiftUI
import SwiftData
import WidgetKit

struct TodayView: View {
    @Environment(\.modelContext) private var context
    @Query private var plans: [TaperPlan]
    @Query(sort: \Intake.timestamp, order: .reverse) private var intakes: [Intake]

    @Binding var tabSelection: Int

    @State private var logTarget: LogTarget?
    @State private var editingIntake: Intake?
    @State private var showingStepInfo = false
    @State private var showingDayDoses = false
    @State private var showingSettings = false
    @State private var showingAdjunct = false
    @State private var recoveryNote: String?
    @State private var ringProgress: CGFloat = 0
    @State private var liveActivity = LiveActivityController.shared
    /// Which day is on screen. Today by default; arrows either side of the ring
    /// walk backwards through the record so a missed log can be filled in.
    @State private var selectedDay = Calendar.current.startOfDay(for: Date())

    private var isToday: Bool {
        Calendar.current.isDateInToday(selectedDay)
    }

    private var canGoForward: Bool { !isToday }

    /// The first day with any dose logged — there's nothing to see before it.
    private var earliestDay: Date {
        guard let first = intakes.last?.timestamp else { return selectedDay }
        return Calendar.current.startOfDay(for: first)
    }

    private var canGoBack: Bool { selectedDay > earliestDay }

    private var plan: TaperPlan? { plans.first }

    private var todaysIntakes: [Intake] {
        let cal = Calendar.current
        let start = cal.startOfDay(for: selectedDay)
        guard let end = cal.date(byAdding: .day, value: 1, to: start) else { return [] }
        return intakes.filter {
            $0.timestamp >= start && $0.timestamp < end && $0.substance == .sevenOH
        }
    }

    private var filledSlots: Set<Int> {
        Set(todaysIntakes.compactMap(\.slotIndex))
    }

    private var loggedMg: Double {
        todaysIntakes.reduce(0) { $0 + $1.nominalMg }
    }

    private var targetMg: Double { plan?.currentTargetMgPerDay ?? 15 }
    private var remainingMg: Double { max(0, targetMg - loggedMg) }
    private var isOverPlan: Bool { loggedMg > targetMg }
    private var anyUnverified: Bool { todaysIntakes.contains { !$0.isVerifiedAmount } }

    var body: some View {
        ZStack {
            Theme.ground.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    header
                    ringWithDayNav
                    baselineChip
                    if anyUnverified { honestyNote }
                    slots
                    adjunctStrip
                    if isToday {
                        countdownButton
                        checkInButton
                    }
                }
                .padding(.bottom, 40)
            }
        }
        .safeAreaInset(edge: .bottom) {
            LogIsland(
                slotNames: ["Morning", "Noon", "Evening"],
                filledSlots: filledSlots
            ) { slot in
                logTarget = LogTarget(slotIndex: slot)
            }
        }
        .sheet(item: $logTarget) { target in
            LogSheet(target: target, plan: plan)
        }
        .sheet(item: $editingIntake) { intake in
            IntakeEditSheet(intake: intake, plan: plan)
        }
        .sheet(isPresented: $showingStepInfo) {
            StepInfoSheet(plan: plan)
        }
        .sheet(isPresented: $showingDayDoses) {
            DayDosesSheet(intakes: todaysIntakes, plan: plan)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsSheet()
        }
        .sheet(isPresented: $showingAdjunct) {
            AdjunctSheet()
        }
        .alert("Recovered your old logs", isPresented: .constant(recoveryNote != nil)) {
            Button("OK") { recoveryNote = nil }
        } message: {
            Text(recoveryNote ?? "")
        }
        .onAppear {
            animateRing()
            liveActivity.refreshState()

            // One-time: pull back anything stranded in the pre-App-Group store,
            // then start the rolling snapshots that make this unnecessary again.
            if !LegacyStoreRecovery.hasRun {
                let outcome = LegacyStoreRecovery.run(into: context)
                if outcome.recovered > 0 {
                    recoveryNote = "Found \(outcome.recovered) records in the old database and merged them back in."
                }
            }
            BackupService.autoSnapshot(context: context)
        }
        .onChange(of: loggedMg) { _, _ in
            animateRing()
            // Keep a running countdown pointed at the next window rather than
            // leaving it sitting at zero after a dose lands.
            if liveActivity.isRunning, let next = nextWindowDate {
                liveActivity.advance(to: next)
            }
            WidgetCenter.shared.reloadAllTimelines()
        }
        .sensoryFeedback(.success, trigger: todaysIntakes.count)
    }

    // MARK: - Header

    private var header: some View {
        Button {
            showingStepInfo = true
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(selectedDay.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                    if let plan {
                        Text("· Step \(plan.currentStepIndex)")
                        Image(systemName: "info.circle")
                            .font(.system(size: 10.5))
                    }
                }
                .font(Theme.label(12, weight: .medium))
                .foregroundStyle(Theme.inkFaint)

                Text(headerTitle)
                    .font(Theme.label(24, weight: .bold))
                    .foregroundStyle(Theme.ink)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .overlay(alignment: .trailing) {
            Button {
                showingSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.inkFaint)
                    .frame(width: 40, height: 40)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 22)
        .padding(.top, 8)
    }

    // MARK: - Ring

    private var ring: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.07), lineWidth: 14)

            Circle()
                .trim(from: 0, to: ringProgress)
                .stroke(
                    isOverPlan ? AnyShapeStyle(Theme.amber) : AnyShapeStyle(Theme.tideGradient),
                    style: StrokeStyle(lineWidth: 14, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: (isOverPlan ? Theme.amber : Theme.tide).opacity(0.4), radius: 10)

            VStack(spacing: 3) {
                Text(remainingMg.doseFormatted)
                    .font(Theme.numeral(54))
                    .foregroundStyle(Theme.ink)
                    .contentTransition(.numericText())
                Text(isOverPlan
                     ? "\(loggedMg.doseFormatted) logged · plan was \(targetMg.doseFormatted)"
                     : "mg left of \(targetMg.doseFormatted) planned")
                    .font(Theme.label(12, weight: .medium))
                    .foregroundStyle(Theme.inkFaint)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 150)
            }
        }
        .frame(width: 210, height: 210)
        .contentShape(Circle())
        .onTapGesture { showingDayDoses = true }
    }

    /// The ring flanked by day arrows. Backwards is bounded by the first logged
    /// day and forwards by today — there is nothing useful in either direction
    /// past those, and a disabled arrow says so more clearly than an empty screen.
    private var ringWithDayNav: some View {
        HStack(spacing: 6) {
            dayArrow(systemName: "chevron.left", enabled: canGoBack, delta: -1)
            ring
            dayArrow(systemName: "chevron.right", enabled: canGoForward, delta: 1)
        }
        .padding(.top, 18)
    }

    private func dayArrow(systemName: String, enabled: Bool, delta: Int) -> some View {
        Button {
            guard let next = Calendar.current.date(byAdding: .day, value: delta, to: selectedDay) else { return }
            withAnimation(.snappy(duration: 0.25)) {
                selectedDay = Calendar.current.startOfDay(for: next)
            }
            animateRing()
        } label: {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(enabled ? Theme.inkSoft : Theme.inkFaint.opacity(0.25))
                .frame(width: 40, height: 60)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .sensoryFeedback(.selection, trigger: selectedDay)
    }

    private var headerTitle: String {
        let cal = Calendar.current
        if cal.isDateInToday(selectedDay) { return "Today" }
        if cal.isDateInYesterday(selectedDay) { return "Yesterday" }
        return selectedDay.formatted(.dateTime.month(.abbreviated).day())
    }

    private func animateRing() {
        let target = targetMg > 0 ? min(1, loggedMg / targetMg) : 0
        withAnimation(.spring(response: 0.7, dampingFraction: 0.75)) {
            ringProgress = target
        }
    }

    // MARK: - Baseline

    private var baselineChip: some View {
        Group {
            if let plan {
                Text("\(plan.percentBelowBaseline)% below baseline")
                    .font(Theme.label(11.5, weight: .semibold))
                    .foregroundStyle(Theme.tideGlow)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Theme.tide.opacity(0.13)))
                    .overlay(Capsule().stroke(Theme.tide.opacity(0.35), lineWidth: 1))
            }
        }
        .padding(.top, 10)
    }

    // MARK: - Honesty

    /// A nominal milligram figure from hand-split retail tablets is not a
    /// measurement, and showing it as a clean number would be the app's first lie.
    private var honestyNote: some View {
        let band = TaperMath.uncertaintyBand(nominalMg: loggedMg, verified: false)
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 11))
                Text("Nominal, not measured")
                    .font(Theme.label(11.5, weight: .bold))
            }
            .foregroundStyle(Theme.amber)

            if let band {
                Text("Logged from split tablets, so today's real 7-OH is somewhere around \(band.lowerBound.doseFormatted)–\(band.upperBound.doseFormatted) mg. A 5% step is \((targetMg * 0.05).doseFormatted) mg — smaller than that spread.")
                    .font(Theme.label(12, weight: .regular))
                    .foregroundStyle(Theme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Theme.amber.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Theme.amber.opacity(0.25), lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }

    // MARK: - Slots

    private var slots: some View {
        VStack(spacing: 8) {
            ForEach(Array((plan?.slotMinutes ?? [450, 750, 1020]).enumerated()), id: \.offset) { index, minutes in
                slotRow(index: index, minutes: minutes)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 18)
    }

    private func slotRow(index: Int, minutes: Int) -> some View {
        let filled = todaysIntakes.first { $0.slotIndex == index }
        let isDone = filled != nil
        let name = ["Morning", "Noon", "Evening"][safe: index] ?? "Slot \(index + 1)"

        return HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(isDone ? Theme.tide.opacity(0.16) : Color.clear)
                Circle()
                    .strokeBorder(
                        isDone ? Theme.tide.opacity(0.45) : Theme.inkFaint.opacity(0.35),
                        style: StrokeStyle(lineWidth: 1.5, dash: isDone ? [] : [3, 3])
                    )
                if isDone {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Theme.tideGlow)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(width: 27, height: 27)

            VStack(alignment: .leading, spacing: 1) {
                Text(name)
                    .font(Theme.label(13.5, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Text(filled.map { $0.timestamp.formatted(date: .omitted, time: .shortened) }
                     ?? "scheduled \(minutes.asClockTime)")
                    .font(Theme.label(11.5, weight: .regular))
                    .foregroundStyle(Theme.inkFaint)
            }

            Spacer(minLength: 8)

            if let filled {
                Text("\(filled.nominalMg.doseFormatted) mg")
                    .font(Theme.label(13, weight: .medium))
                    .foregroundStyle(Theme.inkSoft)
            } else {
                Text("Log")
                    .font(Theme.label(12, weight: .bold))
                    .foregroundStyle(Theme.deep)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Theme.tide))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.07), lineWidth: 1)
        )
        // The whole row is the tap target, not just the pill. A 6pt-tall button
        // inside a scroll view is a miss waiting to happen.
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .onTapGesture {
            // A filled slot opens the dose for editing rather than doing nothing,
            // so a mis-log is fixable from the screen where you notice it.
            if let filled {
                editingIntake = filled
            } else {
                logTarget = LogTarget(slotIndex: index)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isDone)
    }

    // MARK: - Adjuncts

    /// Everything that isn't the taper. Compact on purpose — it's supporting
    /// information, and the day's 7-OH picture should stay the thing your eye
    /// lands on.
    private var adjunctStrip: some View {
        let others = todaysIntakes.filter { !$0.substance.isTapered }
        return Button {
            showingAdjunct = true
        } label: {
            HStack(spacing: 8) {
                if others.isEmpty {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 12))
                    Text("Also took…")
                        .font(Theme.label(13, weight: .medium))
                    Spacer()
                } else {
                    ForEach(Array(Set(others.map(\.substance))).sorted(by: { $0.displayName < $1.displayName }), id: \.self) { substance in
                        HStack(spacing: 4) {
                            Image(systemName: substance.symbolName)
                                .font(.system(size: 10))
                            Text(substance.displayName)
                                .font(Theme.label(11, weight: .medium))
                        }
                        .foregroundStyle(Theme.inkSoft)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Color.white.opacity(0.06)))
                    }
                    Spacer()
                    Image(systemName: "plus.circle")
                        .font(.system(size: 12))
                }
            }
            .foregroundStyle(Theme.inkFaint)
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.04))
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    // MARK: - Countdown

    /// For the hours when you're watching the clock. Starting it puts the
    /// countdown on the Lock Screen so checking it doesn't mean opening this.
    private var countdownButton: some View {
        let next = nextWindowDate
        return Button {
            if liveActivity.isRunning {
                liveActivity.stop()
            } else if let next {
                liveActivity.start(nextDoseAt: next)
            }
        } label: {
            HStack(spacing: 7) {
                Image(systemName: liveActivity.isRunning ? "stop.circle.fill" : "hourglass")
                    .font(.system(size: 13, weight: .semibold))
                Text(liveActivity.isRunning ? "Stop the countdown" : "Put a countdown on my Lock Screen")
                    .font(Theme.label(13, weight: .semibold))
            }
            .foregroundStyle(liveActivity.isRunning ? Theme.amber : Theme.tideGlow)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill((liveActivity.isRunning ? Theme.amber : Theme.tide).opacity(0.10))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke((liveActivity.isRunning ? Theme.amber : Theme.tide).opacity(0.4), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(next == nil && !liveActivity.isRunning)
        .opacity(next == nil && !liveActivity.isRunning ? 0.4 : 1)
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .sensoryFeedback(.impact(weight: .light), trigger: liveActivity.isRunning)
    }

    /// The next unfilled slot's time today, or the first slot tomorrow.
    private var nextWindowDate: Date? {
        guard let plan else { return nil }
        let cal = Calendar.current
        for (index, minutes) in plan.slotMinutes.enumerated() where !filledSlots.contains(index) {
            if let at = cal.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: Date()) {
                return at
            }
        }
        guard let first = plan.slotMinutes.first,
              let tomorrow = cal.date(byAdding: .day, value: 1, to: Date()) else { return nil }
        return cal.date(bySettingHour: first / 60, minute: first % 60, second: 0, of: tomorrow)
    }

    // MARK: - Check-in

    private var checkInButton: some View {
        Button {
            tabSelection = 3
        } label: {
            HStack(spacing: 7) {
                Image(systemName: "text.bubble.fill")
                    .font(.system(size: 12))
                Text("Say how you're doing")
                    .font(Theme.label(13, weight: .medium))
            }
            .foregroundStyle(Theme.inkSoft)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.04))
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .padding(.top, 14)
    }
}
