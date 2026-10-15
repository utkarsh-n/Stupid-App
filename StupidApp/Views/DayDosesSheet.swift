import SwiftUI
import SwiftData

/// Everything logged today, editable and deletable.
///
/// This exists because the app previously had no way to undo a mis-log, which
/// is a bad thing to discover after double-logging a dose you never took.
struct DayDosesSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let intakes: [Intake]
    let plan: TaperPlan?

    @State private var editing: Intake?

    private var total: Double {
        intakes.reduce(0) { $0 + $1.nominalMg }
    }

    private var target: Double { plan?.currentTargetMgPerDay ?? 0 }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    LabeledContent("Logged today", value: "\(total.doseFormatted) mg")
                    LabeledContent("Planned", value: "\(target.doseFormatted) mg")
                    if total > target {
                        LabeledContent("Over by") {
                            Text("\(( total - target).doseFormatted) mg")
                                .foregroundStyle(Theme.amber)
                        }
                    }
                } footer: {
                    if total > target {
                        Text("If one of these is a mistake, swipe to delete it. An over-plan day is data either way — but it shouldn't be data about a dose you never took.")
                    }
                }

                Section("Doses") {
                    ForEach(intakes) { intake in
                        Button {
                            editing = intake
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(intake.timestamp.formatted(date: .omitted, time: .shortened))
                                        .font(.body)
                                        .foregroundStyle(.primary)
                                    Text(label(for: intake))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text("\(intake.nominalMg.doseFormatted) mg")
                                    .font(.body.weight(.medium))
                                    .foregroundStyle(.secondary)
                                Image(systemName: "chevron.right")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                    .onDelete(perform: delete)

                    if intakes.isEmpty {
                        Text("Nothing logged today.")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Today's doses")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(item: $editing) { intake in
                IntakeEditSheet(intake: intake, plan: plan)
            }
        }
    }

    private func label(for intake: Intake) -> String {
        var parts: [String] = []
        if let slot = intake.slotIndex,
           let name = ["Morning", "Noon", "Evening"][safe: slot] {
            parts.append(name)
        }
        if let prep = intake.preparation { parts.append(prep.label) }
        parts.append(intake.reason.displayName.lowercased())
        return parts.joined(separator: " · ")
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            context.delete(intakes[index])
        }
        try? context.save()
    }
}

/// Edit one logged dose. Same fields as logging it, plus delete.
struct IntakeEditSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Preparation.strengthPerUnit) private var allPreparations: [Preparation]

    @Bindable var intake: Intake
    let plan: TaperPlan?

    @State private var amountText = ""
    @State private var confirmingDelete = false

    private var preparations: [Preparation] {
        allPreparations.filter { $0.substance == .sevenOH && $0.isActive }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Amount") {
                    HStack {
                        TextField("Amount", text: $amountText)
                            .keyboardType(.decimalPad)
                        Text(intake.preparation?.unitLabel ?? "")
                            .foregroundStyle(.secondary)
                    }
                    LabeledContent("Dose") {
                        Text("\(previewMg.doseFormatted) mg")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Theme.tide)
                    }
                }

                Section("Product") {
                    Picker("Product", selection: Binding(
                        get: { intake.preparation?.id.uuidString ?? "" },
                        set: { id in
                            intake.preparation = preparations.first { $0.id.uuidString == id }
                        }
                    )) {
                        ForEach(preparations) { item in
                            Text("\(item.label) · \(item.strengthPerUnit.doseFormatted) mg")
                                .tag(item.id.uuidString)
                        }
                    }
                }

                Section("Why") {
                    Picker("Why", selection: Binding(
                        get: { intake.reason },
                        set: { intake.reason = $0 }
                    )) {
                        Text("Scheduled").tag(DoseReason.scheduled)
                        Text("Withdrawal").tag(DoseReason.withdrawal)
                        Text("Craving").tag(DoseReason.craving)
                    }
                    .pickerStyle(.segmented)
                }

                Section("When") {
                    DatePicker("Time", selection: Binding(
                        get: { intake.timestamp },
                        set: { intake.timestamp = $0 }
                    ), displayedComponents: [.hourAndMinute])
                }

                Section("Slot") {
                    Picker("Slot", selection: Binding(
                        get: { intake.slotIndex ?? -1 },
                        set: { intake.slotIndex = $0 < 0 ? nil : $0 }
                    )) {
                        Text("Unscheduled").tag(-1)
                        Text("Morning").tag(0)
                        Text("Noon").tag(1)
                        Text("Evening").tag(2)
                    }
                }

                Section {
                    Button("Delete this dose", role: .destructive) {
                        confirmingDelete = true
                    }
                }
            }
            .navigationTitle("Edit dose")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                }
            }
            .onAppear { amountText = intake.amount.doseFormatted }
            .confirmationDialog(
                "Delete this dose?",
                isPresented: $confirmingDelete,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    context.delete(intake)
                    try? context.save()
                    dismiss()
                }
            } message: {
                Text("Use this when a dose was logged by mistake — not to tidy up a day you'd rather not have had.")
            }
        }
    }

    private var previewMg: Double {
        let amount = Double(amountText) ?? intake.amount
        return intake.preparation?.nominalMg(forUnits: amount) ?? amount
    }

    private func save() {
        if let amount = Double(amountText) {
            intake.amount = amount
        }
        intake.nominalMg = intake.preparation?.nominalMg(forUnits: intake.amount) ?? intake.amount
        try? context.save()
        dismiss()
    }
}
