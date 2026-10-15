import SwiftUI
import SwiftData

/// Identifies which slot a log sheet is filling. Wrapping it in an Identifiable
/// and presenting via `.sheet(item:)` rather than `.sheet(isPresented:)` matters:
/// the isPresented form can capture the slot binding in the same render pass that
/// sets it, so the first presentation reads a stale value and the dose lands with
/// no slot attached.
struct LogTarget: Identifiable, Hashable {
    let id = UUID()
    var slotIndex: Int?
}

/// Logging is two taps from anywhere and one from a widget. The two fields beyond
/// amount earn their place: *why* (the ratio of scheduled to withdrawal-driven
/// doses is the earliest sign a step is too steep) and *which product* (a silent
/// potency change is the most common way a taper signal gets corrupted).
///
/// Nothing here scolds. An over-plan dose logs exactly like any other.
struct LogSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Preparation.strengthPerUnit) private var allPreparations: [Preparation]

    /// The last product used, remembered across launches — people stay on one
    /// brand until the bottle runs out, so making them re-pick it every dose is
    /// friction for nothing.
    @AppStorage("lastPreparationID") private var lastPreparationID: String = ""

    let target: LogTarget
    let plan: TaperPlan?

    @State private var units: Double = 0.5
    @State private var customAmount: String = ""
    @State private var useCustom = false
    @State private var prepID: String = ""
    @State private var reason: DoseReason = .scheduled
    @State private var when = Date()

    private var preparations: [Preparation] {
        allPreparations.filter { $0.substance == .sevenOH && $0.isActive }
    }

    private var prep: Preparation? {
        preparations.first { $0.id.uuidString == prepID } ?? preparations.first
    }

    private var amount: Double {
        if useCustom { return Double(customAmount) ?? 0 }
        return units
    }

    private var nominalMg: Double {
        prep?.nominalMg(forUnits: amount) ?? 0
    }

    var body: some View {
        NavigationStack {
            Form {
                amountSection
                productSection
                reasonSection
                whenSection
            }
            .navigationTitle("Log dose")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Log") { save() }
                        .disabled(nominalMg <= 0)
                }
            }
        }
        .onAppear(perform: restoreDefaults)
    }

    // MARK: - Amount

    private var amountSection: some View {
        Section {
            Picker("Amount", selection: $units) {
                Text("¼").tag(0.25)
                Text("½").tag(0.5)
                Text("1").tag(1.0)
            }
            .pickerStyle(.segmented)
            .disabled(useCustom)

            Toggle("Enter exact amount", isOn: $useCustom.animation())

            if useCustom {
                HStack {
                    TextField("Amount", text: $customAmount)
                        .keyboardType(.decimalPad)
                    Text(prep?.unitLabel ?? "")
                        .foregroundStyle(.secondary)
                }
            }

            LabeledContent("Dose") {
                Text("\(nominalMg.doseFormatted) mg")
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .foregroundStyle(Theme.tide)
            }
        } header: {
            Text(prep.map { "\($0.kind.displayName)s of \($0.strengthPerUnit.doseFormatted) mg" } ?? "Amount")
        } footer: {
            if let prep, !prep.hasVerifiedContent {
                Text("Split by hand, so this is nominal. Real content in these products runs 32–81% of label.")
            }
        }
    }

    // MARK: - Product

    private var productSection: some View {
        Section("Product") {
            Picker("Product", selection: $prepID) {
                ForEach(preparations) { item in
                    Text("\(item.label) · \(item.strengthPerUnit.doseFormatted) mg")
                        .tag(item.id.uuidString)
                }
            }
            .pickerStyle(.menu)
        }
    }

    // MARK: - Reason

    private var reasonSection: some View {
        Section {
            Picker("Why", selection: $reason) {
                Text("Scheduled").tag(DoseReason.scheduled)
                Text("Withdrawal").tag(DoseReason.withdrawal)
                Text("Craving").tag(DoseReason.craving)
            }
            .pickerStyle(.segmented)
        } header: {
            Text("Why")
        } footer: {
            Text("How often a dose is withdrawal-driven rather than scheduled is the earliest sign a step is too steep.")
        }
    }

    // MARK: - When

    private var whenSection: some View {
        Section("When") {
            // Quick times for backfilling a dose you took earlier without
            // spinning the wheel back to it.
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    quickTime("Now", date: Date())
                    ForEach(plan?.slotMinutes ?? [450, 750, 1020], id: \.self) { minutes in
                        quickTime(minutes.asClockTime, date: todayAt(minutes: minutes))
                    }
                }
                .padding(.vertical, 2)
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))

            DatePicker("Time", selection: $when, displayedComponents: [.hourAndMinute])
        }
    }

    private func quickTime(_ label: String, date: Date) -> some View {
        let selected = abs(when.timeIntervalSince(date)) < 60
        return Button {
            withAnimation(.snappy) { when = date }
        } label: {
            Text(label)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    Capsule().fill(selected ? Theme.tide.opacity(0.22) : Color.secondary.opacity(0.14))
                )
                .overlay(
                    Capsule().stroke(selected ? Theme.tide : .clear, lineWidth: 1)
                )
                .foregroundStyle(selected ? Theme.tide : Color.primary)
        }
        .buttonStyle(.plain)
    }

    private func todayAt(minutes: Int) -> Date {
        let cal = Calendar.current
        return cal.date(
            bySettingHour: minutes / 60,
            minute: minutes % 60,
            second: 0,
            of: Date()
        ) ?? Date()
    }

    // MARK: - Persistence

    private func restoreDefaults() {
        if prepID.isEmpty {
            if preparations.contains(where: { $0.id.uuidString == lastPreparationID }) {
                prepID = lastPreparationID
            } else {
                prepID = preparations.first?.id.uuidString ?? ""
            }
        }
        if let slot = target.slotIndex, let minutes = plan?.slotMinutes[safe: slot] {
            // Default to the slot's scheduled time when it has already passed,
            // otherwise now — backfilling is the common case for an earlier slot.
            let scheduled = todayAt(minutes: minutes)
            when = scheduled < Date() ? scheduled : Date()
        }
    }

    private func save() {
        let intake = Intake(
            timestamp: when,
            substance: .sevenOH,
            reason: reason,
            amount: amount,
            preparation: prep,
            slotIndex: target.slotIndex
        )
        context.insert(intake)
        lastPreparationID = prepID
        try? context.save()
        dismiss()
    }
}
