import SwiftUI
import SwiftData

/// Tap what's true, hit check in, done.
///
/// Tap once for mild, again for moderate, again for bad, again to clear. The
/// whole point is that this takes seconds — nobody mid-withdrawal is writing
/// paragraphs, and a check-in that doesn't happen tells the taper engine nothing.
struct CopilotView: View {
    @Environment(\.modelContext) private var context
    @Query private var plans: [TaperPlan]
    @Query(sort: \CheckIn.timestamp, order: .reverse) private var checkIns: [CheckIn]

    @State private var selection: [Symptom: Severity] = [:]
    @State private var category: Symptom.Category = .physical
    @State private var health = HealthService.shared
    @State private var physiology = Physiology()

    private var plan: TaperPlan? { plans.first }

    private var assessment: TaperAssessment.Result? {
        guard let plan else { return nil }
        return TaperAssessment.evaluate(
            checkIns: checkIns,
            plan: plan,
            physiology: physiology.hasData ? physiology : nil
        )
    }

    private var activeCount: Int {
        selection.values.filter { $0 != .none }.count
    }

    var body: some View {
        ZStack {
            Theme.ground.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 14) {
                    if let assessment { assessmentCard(assessment) }
                    PhysiologyCard(
                        physiology: physiology,
                        isAuthorized: health.isAuthorized
                    ) {
                        Task {
                            await health.requestAuthorization()
                            await refreshPhysiology()
                        }
                    }
                    capsulePicker
                    history
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
        }
        .safeAreaInset(edge: .top) { titleBar }
        .safeAreaInset(edge: .bottom) { submitBar }
        .task { await refreshPhysiology() }
    }

    private func refreshPhysiology() async {
        guard let plan, health.isAvailable else { return }
        await health.restoreAuthorizationIfGranted()
        let snapshot = await health.loadSnapshot()
        physiology = Physiology.build(from: snapshot, stepStarted: plan.currentStepStarted)
    }

    private var titleBar: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("tap what's true")
                .font(Theme.label(12, weight: .medium))
                .foregroundStyle(Theme.inkFaint)
            Text("How you feel")
                .font(Theme.label(24, weight: .bold))
                .foregroundStyle(Theme.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 22)
        .padding(.bottom, 8)
        .background(Theme.deep.opacity(0.92))
    }

    // MARK: - Assessment

    private func assessmentCard(_ result: TaperAssessment.Result) -> some View {
        let tone: Color = {
            switch result.verdict {
            case .tooSteep, .notSettling: return Theme.amber
            case .settled:                return Theme.tideGlow
            default:                      return Theme.inkSoft
            }
        }()

        return Card {
            HStack(spacing: 6) {
                Image(systemName: iconName(result.verdict))
                    .font(.system(size: 12, weight: .bold))
                Text(result.headline)
                    .font(Theme.label(13.5, weight: .bold))
            }
            .foregroundStyle(tone)

            Text(result.detail)
                .font(Theme.label(12.5, weight: .regular))
                .foregroundStyle(Theme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)

            if result.recommendsHold, let plan, !plan.isHolding {
                Button {
                    plan.isHolding = true
                    plan.holdStarted = Date()
                    try? context.save()
                } label: {
                    Label("Hold at \(plan.currentTargetMgPerDay.doseFormatted) mg", systemImage: "pause.fill")
                        .font(Theme.label(13, weight: .bold))
                        .foregroundStyle(Theme.amber)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Theme.amber.opacity(0.12))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Theme.amber.opacity(0.45), lineWidth: 1.2)
                        )
                }
                .buttonStyle(.plain)
                .sensoryFeedback(.impact(weight: .medium), trigger: plan.isHolding)
            }
        }
    }

    private func iconName(_ verdict: TaperAssessment.Verdict) -> String {
        switch verdict {
        case .notEnoughData: return "circle.dashed"
        case .settled:       return "checkmark.circle.fill"
        case .expected:      return "clock.fill"
        case .notSettling:   return "arrow.up.right"
        case .tooSteep:      return "exclamationmark.triangle.fill"
        }
    }

    // MARK: - Capsules

    private var capsulePicker: some View {
        Card {
            Picker("", selection: $category) {
                ForEach(Symptom.Category.allCases) { cat in
                    Text(cat.displayName).tag(cat)
                }
            }
            .pickerStyle(.segmented)

            FlowLayout(spacing: 7) {
                ForEach(category == .physical ? Symptom.physical : Symptom.mental) { symptom in
                    capsule(symptom)
                }
            }

            Text("Tap once for mild, again for moderate, again for bad.")
                .font(Theme.label(11, weight: .regular))
                .foregroundStyle(Theme.inkFaint)
        }
    }

    private func capsule(_ symptom: Symptom) -> some View {
        let level = selection[symptom] ?? .none
        let active = level != .none
        let tint: Color = {
            switch level {
            case .none:     return Theme.inkFaint
            case .mild:     return Theme.tide
            case .moderate: return Theme.tideGlow
            case .bad:      return Theme.amber
            }
        }()

        return Button {
            withAnimation(.snappy(duration: 0.22)) {
                selection[symptom] = level.next
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: symptom.symbolName)
                    .font(.system(size: 10.5, weight: .semibold))
                Text(symptom.displayName)
                    .font(Theme.label(12.5, weight: active ? .semibold : .regular))
                if active {
                    HStack(spacing: 1.5) {
                        ForEach(0..<level.rawValue, id: \.self) { _ in
                            Circle().frame(width: 3.5, height: 3.5)
                        }
                    }
                }
            }
            .foregroundStyle(active ? tint : Theme.inkSoft)
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .background(
                Capsule().fill(active ? tint.opacity(0.15) : Color.white.opacity(0.05))
            )
            .overlay(
                Capsule().stroke(active ? tint.opacity(0.6) : Color.white.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: level)
    }

    // MARK: - Submit

    private var submitBar: some View {
        Button {
            save()
        } label: {
            HStack(spacing: 7) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 15, weight: .semibold))
                Text(activeCount == 0 ? "Nothing to report" : "Check in · \(activeCount)")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
            }
            .frame(height: 52)
            .padding(.horizontal, 26)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.tint(Theme.tideDeep.opacity(0.7)).interactive(), in: .capsule)
        .padding(.bottom, 6)
        .sensoryFeedback(.success, trigger: checkIns.count)
    }

    // MARK: - History

    private var history: some View {
        VStack(spacing: 10) {
            ForEach(checkIns.prefix(15)) { entry in
                Card {
                    HStack {
                        Text(entry.timestamp.formatted(.dateTime.weekday().hour().minute()))
                            .font(Theme.label(11, weight: .semibold))
                            .foregroundStyle(Theme.inkFaint)
                        Spacer()
                        Text("Symptoms \(entry.symptomScore)")
                            .font(Theme.label(11.5, weight: .bold))
                            .foregroundStyle(entry.symptomScore > 12 ? Theme.amber : Theme.inkSoft)
                    }

                    if entry.symptoms.isEmpty {
                        Text("Nothing reported.")
                            .font(Theme.label(12.5, weight: .regular))
                            .foregroundStyle(Theme.inkFaint)
                    } else {
                        FlowLayout(spacing: 5) {
                            ForEach(entry.symptoms.sorted { $0.severity.rawValue > $1.severity.rawValue }, id: \.symptom) { item in
                                Text(item.symptom.displayName)
                                    .font(Theme.label(11, weight: .medium))
                                    .foregroundStyle(item.severity == .bad ? Theme.amber : Theme.inkSoft)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Capsule().fill(Color.white.opacity(0.06)))
                            }
                        }
                    }
                }
            }

            if checkIns.isEmpty {
                Text("No check-ins yet.")
                    .font(Theme.label(12.5, weight: .regular))
                    .foregroundStyle(Theme.inkFaint)
                    .padding(.top, 20)
            }
        }
    }

    private func save() {
        let entry = CheckIn(text: "", source: .measured)
        entry.apply(selection)
        context.insert(entry)
        try? context.save()

        // Mirror into Health so the record survives independently of this app and
        // charts against sleep and heart rate in Apple's own timeline. Valence
        // runs from mildly positive at zero symptomScore to clearly negative at the top.
        let valence = max(-0.85, 0.2 - (Double(entry.symptomScore) / 28.0))
        Task { await health.writeStateOfMind(valence: valence, at: entry.timestamp) }

        withAnimation(.snappy) { selection = [:] }
    }
}

/// Wrapping row layout for the capsules.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > width && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: width, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX && x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
