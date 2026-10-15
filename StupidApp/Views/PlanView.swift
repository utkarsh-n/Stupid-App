import SwiftUI
import SwiftData
import Charts

struct PlanView: View {
    @Environment(\.modelContext) private var context
    @Query private var plans: [TaperPlan]
    @Query(sort: \Intake.timestamp) private var intakes: [Intake]

    @State private var showingPace = false
    @State private var showingCrossover =
        ProcessInfo.processInfo.environment["START_SHEET"] == "crossover"

    private var plan: TaperPlan? { plans.first }

    var body: some View {
        ZStack {
            Theme.ground.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 14) {
                    if let plan {
                        currentStepCard(plan)
                        chartCard(plan)
                        holdCard(plan)
                        crossoverCard
                    } else {
                        Text("No plan yet.")
                            .foregroundStyle(Theme.inkSoft)
                            .padding(.top, 60)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
        }
        .safeAreaInset(edge: .top) { titleBar }
        .sheet(isPresented: $showingPace) {
            if let plan { PaceSheet(plan: plan) }
        }
        .sheet(isPresented: $showingCrossover) {
            CrossoverSheet(plan: plan)
        }
    }

    private var titleBar: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(plan.map { "\($0.baselineMgPerDay.doseFormatted) mg → 0" } ?? "Plan")
                .font(Theme.label(12, weight: .medium))
                .foregroundStyle(Theme.inkFaint)
            Text("Plan")
                .font(Theme.label(24, weight: .bold))
                .foregroundStyle(Theme.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 22)
        .padding(.bottom, 8)
        .background(Theme.deep.opacity(0.9))
    }

    // MARK: - Current step

    private func currentStepCard(_ plan: TaperPlan) -> some View {
        Card {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("Step \(plan.currentStepIndex)")
                    .font(Theme.numeral(28))
                    .foregroundStyle(Theme.ink)
                Text(plan.recommendedStepDays > 1
                     ? "day \(plan.daysOnCurrentStep) of \(plan.recommendedStepDays)"
                     : "day \(plan.daysOnCurrentStep) at this dose")
                    .font(Theme.label(12.5, weight: .regular))
                    .foregroundStyle(Theme.inkFaint)
                Spacer()
                if plan.isHolding {
                    Label("Holding", systemImage: "pause.fill")
                        .font(Theme.label(11, weight: .bold))
                        .foregroundStyle(Theme.amber)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Theme.amber.opacity(0.14)))
                }
            }

            Text("\(plan.currentTargetMgPerDay.doseFormatted) mg/day · \(plan.perSlotTargetMg.doseFormatted) mg × \(plan.slotMinutes.count)")
                .font(Theme.label(13, weight: .medium))
                .foregroundStyle(Theme.inkSoft)

            Button {
                showingPace = true
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "speedometer").font(.system(size: 10.5))
                    Text("\(plan.pace.title) · \(plan.pace.summary)")
                        .font(Theme.label(11.5, weight: .semibold))
                    Image(systemName: "chevron.right").font(.system(size: 9))
                }
                .foregroundStyle(Theme.tideGlow)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Capsule().fill(Theme.tide.opacity(0.12)))
            }
            .buttonStyle(.plain)

            Divider().overlay(Color.white.opacity(0.08)).padding(.vertical, 2)

            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Next target")
                        .font(Theme.label(10.5, weight: .semibold))
                        .foregroundStyle(Theme.inkFaint)
                    Text("\(plan.nextTargetMgPerDay.doseFormatted) mg")
                        .font(Theme.label(15, weight: .bold))
                        .foregroundStyle(Theme.ink)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 1) {
                    Text("Steps left")
                        .font(Theme.label(10.5, weight: .semibold))
                        .foregroundStyle(Theme.inkFaint)
                    Text("~\(plan.stepsRemaining)")
                        .font(Theme.label(15, weight: .bold))
                        .foregroundStyle(Theme.ink)
                }
            }

            if plan.isEligibleForStepDown {
                Button {
                    stepDown(plan)
                } label: {
                    Text("Step down to \(plan.nextTargetMgPerDay.doseFormatted) mg")
                        .font(Theme.label(14, weight: .bold))
                        .foregroundStyle(Theme.deep)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.tide))
                }
                .buttonStyle(.plain)
                .sensoryFeedback(.success, trigger: plan.currentStepIndex)
            } else if !plan.isHolding {
                let daysLeft = max(plan.recommendedStepDays, TaperPlan.delayedFeedbackDays) - plan.daysOnCurrentStep
                Text(daysLeft > 0
                     ? "Next reduction available in \(daysLeft) day\(daysLeft == 1 ? "" : "s")."
                     : "Reduction available once withdrawal is flat or falling.")
                    .font(Theme.label(11.5, weight: .regular))
                    .foregroundStyle(Theme.inkFaint)
            }
        }
    }

    // MARK: - Chart

    private func chartCard(_ plan: TaperPlan) -> some View {
        Card {
            Text("The staircase")
                .font(Theme.label(13, weight: .bold))
                .foregroundStyle(Theme.ink)

            Chart {
                ForEach(projection(plan), id: \.step) { point in
                    LineMark(
                        x: .value("Step", point.step),
                        y: .value("mg", point.mg),
                        series: .value("Series", "planned")
                    )
                    .foregroundStyle(point.isFuture ? Theme.tideDeep.opacity(0.55) : Theme.tide)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineJoin: .round,
                                           dash: point.isFuture ? [4, 4] : []))
                    .interpolationMethod(.stepEnd)
                }

                RuleMark(x: .value("Now", plan.currentStepIndex))
                    .foregroundStyle(Theme.amber.opacity(0.55))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 3]))
                    .annotation(position: .bottom, alignment: .center) {
                        Text("now")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(Theme.inkFaint)
                    }

                PointMark(
                    x: .value("Step", plan.currentStepIndex),
                    y: .value("mg", plan.currentTargetMgPerDay)
                )
                .foregroundStyle(Theme.tideGlow)
                .symbolSize(60)
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
                AxisMarks { value in
                    AxisValueLabel {
                        if let v = value.as(Int.self) {
                            Text("\(v)").foregroundStyle(Theme.inkFaint)
                        }
                    }
                }
            }
            .frame(height: 170)

            if let finish = plan.projectedFinish {
                Text("Rough finish around \(finish.formatted(.dateTime.month(.wide).year())). Holds move this; nothing falls behind.")
                    .font(Theme.label(11.5, weight: .regular))
                    .foregroundStyle(Theme.inkFaint)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private struct ProjectionPoint {
        let step: Int
        let mg: Double
        let isFuture: Bool
    }

    /// Reconstructs the descending staircase: past steps back-calculated from the
    /// baseline, future steps projected forward at the recommended pacing.
    private func projection(_ plan: TaperPlan) -> [ProjectionPoint] {
        var points: [ProjectionPoint] = []

        // Past: interpolate geometrically from baseline down to today.
        let start = plan.currentStepIndex
        if start > 0 {
            for i in 0...start {
                let t = Double(i) / Double(max(start, 1))
                let mg = plan.baselineMgPerDay
                    * pow(plan.currentTargetMgPerDay / plan.baselineMgPerDay, t)
                points.append(ProjectionPoint(step: i, mg: mg, isFuture: false))
            }
        }

        // Future: actual step math forward to the jump-off dose.
        var dose = plan.currentTargetMgPerDay
        var index = start
        while dose > plan.jumpOffMgPerDay && index < start + 60 {
            dose = TaperMath.nextTarget(current: dose, baseline: plan.baselineMgPerDay)
            index += 1
            points.append(ProjectionPoint(step: index, mg: dose, isFuture: true))
        }
        return points
    }

    // MARK: - Hold

    private func holdCard(_ plan: TaperPlan) -> some View {
        Card {
            Button {
                toggleHold(plan)
            } label: {
                Label(
                    plan.isHolding ? "Resume the taper" : "Hold this step",
                    systemImage: plan.isHolding ? "play.fill" : "pause.fill"
                )
                .font(Theme.label(14.5, weight: .bold))
                .foregroundStyle(plan.isHolding ? Theme.tide : Theme.amber)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill((plan.isHolding ? Theme.tide : Theme.amber).opacity(0.10))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .stroke((plan.isHolding ? Theme.tide : Theme.amber).opacity(0.45), lineWidth: 1.5)
                )
            }
            .buttonStyle(.plain)
            .sensoryFeedback(.impact(weight: .medium), trigger: plan.isHolding)

            Text(plan.isHolding
                 ? "You're holding at \(plan.currentTargetMgPerDay.doseFormatted) mg. Resume whenever you're ready — there's no clock on this."
                 : "Repeats \(plan.currentTargetMgPerDay.doseFormatted) mg/day for another cycle. No questions asked — stabilising is part of tapering, and most successful tapers include at least one pause.")
                .font(Theme.label(11.5, weight: .regular))
                .foregroundStyle(Theme.inkFaint)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Crossover

    /// The measurement problem gets its own card because it currently outranks
    /// every other thing on this screen: a 5% step is smaller than the noise.
    private var crossoverCard: some View {
        let recipe = TaperMath.solutionRecipe()
        return Card {
            HStack(spacing: 6) {
                Image(systemName: "flask.fill").font(.system(size: 12))
                Text("Switch to solution")
                    .font(Theme.label(13, weight: .bold))
            }
            .foregroundStyle(Theme.amber)

            Text("Five products at 10, 11, 12, 13 and 18 mg, halved by hand, means a nominal day ranges 15–27 mg depending on which bottle is open. A 5% step is smaller than that spread, so the taper can't be measured until this changes.")
                .font(Theme.label(12, weight: .regular))
                .foregroundStyle(Theme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)

            Divider().overlay(Color.white.opacity(0.08))

            VStack(alignment: .leading, spacing: 4) {
                recipeRow("Weigh", "\(recipe.powderMg.doseFormatted) mg of 95% powder")
                recipeRow("Dissolve into", "\(recipe.volumeML.doseFormatted) mL, acidified")
                recipeRow("Gives", "\(recipe.concentrationMgPerML.doseFormatted) mg/mL")
                recipeRow("A 5 mg dose", "5 mL by syringe")
            }

            Button {
                showingCrossover = true
            } label: {
                Text("Walk me through it")
                    .font(Theme.label(13.5, weight: .bold))
                    .foregroundStyle(Theme.deep)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.amber))
            }
            .buttonStyle(.plain)
        }
    }

    private func recipeRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(Theme.label(11.5, weight: .regular))
                .foregroundStyle(Theme.inkFaint)
            Spacer()
            Text(value)
                .font(Theme.label(12, weight: .semibold))
                .foregroundStyle(Theme.ink)
        }
    }

    // MARK: - Actions

    private func toggleHold(_ plan: TaperPlan) {
        withAnimation(.snappy) {
            plan.isHolding.toggle()
            plan.holdStarted = plan.isHolding ? Date() : nil
        }
        try? context.save()
    }

    private func stepDown(_ plan: TaperPlan) {
        withAnimation(.smooth) {
            plan.currentTargetMgPerDay = plan.nextTargetMgPerDay
            plan.currentStepIndex += 1
            plan.currentStepStarted = Date()
        }
        try? context.save()
    }
}

/// Content-layer card. Deliberately not glass — the HIG reserves that for the
/// navigation layer, and a screen of glass cards is the canonical misuse.
struct Card<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(15)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.07), lineWidth: 1)
        )
    }
}
