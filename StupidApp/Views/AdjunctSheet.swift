import SwiftUI
import SwiftData

/// Logging everything that isn't the taper itself.
///
/// Two reasons this matters beyond record-keeping. First, n-of-1: with enough
/// logged nights the app can answer "how were the restless legs on magnesium
/// nights versus without" for *you*, which given how thin the supplement
/// evidence is, is better evidence than anything it could cite. Second,
/// substitution: cannabis and loperamide get the same escalation detection 7-OH
/// gets, because an ally that only watches the substance you asked it to watch
/// isn't much of an ally.
struct AdjunctSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Intake.timestamp, order: .reverse) private var intakes: [Intake]

    @State private var substance: Substance = .electrolytes
    @State private var amount: Double = 1
    @State private var route: IntakeRoute = .oral
    @State private var customAmount = ""

    private var todaysTotal: Double {
        let start = Calendar.current.startOfDay(for: Date())
        return intakes
            .filter { $0.timestamp >= start && $0.substance == substance }
            .reduce(0) { $0 + $1.amount }
    }

    private var ceiling: Double? { substance.dailyCeilingMg }

    private var wouldExceed: Bool {
        guard let ceiling else { return false }
        return todaysTotal + amount > ceiling
    }

    private var remaining: Double? {
        ceiling.map { max(0, $0 - todaysTotal) }
    }

    var body: some View {
        NavigationStack {
            List {
                pickerSection
                doseSection
                if substance == .cannabis { routeSection }
                if let ceiling { ceilingSection(ceiling) }
                if let note = substance.note { noteSection(note) }
                recentSection
            }
            .navigationTitle("Also took")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Log") { save() }
                        .disabled(amount <= 0 || wouldExceed)
                }
            }
            .onChange(of: substance) { _, new in
                amount = new.commonDoses.first ?? 1
                customAmount = ""
                route = new == .cannabis ? .inhaled : .oral
            }
        }
    }

    private var pickerSection: some View {
        Section {
            Picker("What", selection: $substance) {
                ForEach(Substance.adjuncts) { item in
                    Label(item.displayName, systemImage: item.symbolName).tag(item)
                }
            }
            .pickerStyle(.navigationLink)
        }
    }

    private var doseSection: some View {
        Section {
            HStack(spacing: 8) {
                ForEach(substance.commonDoses, id: \.self) { dose in
                    Button {
                        amount = dose
                        customAmount = ""
                    } label: {
                        Text("\(dose.doseFormatted)")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background(
                                Capsule().fill(amount == dose
                                               ? Theme.tide.opacity(0.22)
                                               : Color.secondary.opacity(0.13))
                            )
                            .overlay(Capsule().stroke(amount == dose ? Theme.tide : .clear, lineWidth: 1))
                            .foregroundStyle(amount == dose ? Theme.tide : Color.primary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))

            HStack {
                TextField("Other amount", text: $customAmount)
                    .keyboardType(.decimalPad)
                    .onChange(of: customAmount) { _, new in
                        if let value = Double(new) { amount = value }
                    }
                Text(substance.unitLabel).foregroundStyle(.secondary)
            }
        } header: {
            Text("How much")
        }
    }

    private var routeSection: some View {
        Section {
            Picker("Route", selection: $route) {
                Text("Inhaled").tag(IntakeRoute.inhaled)
                Text("Edible").tag(IntakeRoute.edible)
            }
            .pickerStyle(.segmented)
        } header: {
            Text("Route")
        } footer: {
            Text("Inhaled peaks in 6–10 minutes and wears off, so you can titrate. Edibles take up to two hours, last 6–10, and convert almost entirely to a metabolite several times more potent — the delay is what drives stacking.")
        }
    }

    private func ceilingSection(_ ceiling: Double) -> some View {
        Section {
            LabeledContent("Today so far", value: "\(todaysTotal.doseFormatted) \(substance.unitLabel)")
            LabeledContent("Daily ceiling") {
                Text("\(ceiling.doseFormatted) \(substance.unitLabel)")
                    .foregroundStyle(wouldExceed ? Theme.amber : .secondary)
            }
            if let remaining {
                LabeledContent("Room left", value: "\(remaining.doseFormatted) \(substance.unitLabel)")
            }
            if wouldExceed {
                Label("This would go over the ceiling", systemImage: "exclamationmark.triangle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.amber)
            }
        } header: {
            Text("Ceiling")
        } footer: {
            if let rationale = substance.ceilingRationale {
                Text(rationale)
            }
        }
    }

    private func noteSection(_ note: String) -> some View {
        Section {
            Text(note).font(.footnote).foregroundStyle(.secondary)
        }
    }

    private var recentSection: some View {
        Section("Last few") {
            let recent = intakes.filter { $0.substance == substance }.prefix(5)
            if recent.isEmpty {
                Text("Nothing logged yet.").foregroundStyle(.secondary)
            } else {
                ForEach(Array(recent)) { entry in
                    HStack {
                        Text(entry.timestamp.formatted(.dateTime.month().day().hour().minute()))
                            .font(.subheadline)
                        Spacer()
                        Text("\(entry.amount.doseFormatted) \(substance.unitLabel)")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func save() {
        let intake = Intake(
            timestamp: Date(),
            substance: substance,
            reason: .symptom,
            amount: amount,
            preparation: nil,
            slotIndex: nil
        )
        intake.nominalMg = amount
        intake.route = route
        context.insert(intake)
        try? context.save()
        dismiss()
    }
}
