import SwiftUI
import SwiftData

/// Pick the pace, with the cost of each stated plainly.
///
/// The app has an opinion — slower finishes more often — but the person doing the
/// tapering has information the literature doesn't, and the evidence for slow
/// comes largely from tapers people didn't choose. So this shows the real
/// schedule for each option rather than arguing.
struct PaceSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Bindable var plan: TaperPlan
    @State private var choice: TaperPace = .evidence

    private var schedule: [TaperPace.Day] {
        choice.schedule(from: plan.currentTargetMgPerDay)
    }

    private var finish: Date? {
        choice.finishDate(from: plan.currentTargetMgPerDay)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Pace", selection: $choice) {
                        ForEach(TaperPace.allCases) { pace in
                            Text(pace.title).tag(pace)
                        }
                    }
                    .pickerStyle(.segmented)

                    LabeledContent("Reduction", value: "\(Int(choice.stepFraction * 100))% every \(choice.stepDays == 1 ? "day" : "\(choice.stepDays) days")")
                    LabeledContent("Down to", value: "\(choice.floorMg.doseFormatted) mg")
                    LabeledContent("Then hold", value: "\(choice.holdAtFloorDays) days")
                    if let finish {
                        LabeledContent("Off it around") {
                            Text(finish.formatted(.dateTime.month().day().year()))
                                .fontWeight(.semibold)
                        }
                    }
                } header: {
                    Text(choice.summary)
                } footer: {
                    Text(choice.tradeoff)
                }

                if choice.requiresSolution(from: plan.currentTargetMgPerDay) {
                    Section {
                        Label("This needs the solution", systemImage: "flask.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.amber)
                        Text("Getting to \(choice.floorMg.doseFormatted) mg is not something tablets can do. A 10 mg tablet split by hand has a wider error than the entire dose you're aiming for. Weigh the powder, dissolve to 1 mg/mL, dose by syringe — otherwise the last week of this plan is guesswork.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("The schedule") {
                    ForEach(schedule.prefix(45)) { day in
                        HStack {
                            Text(day.date.formatted(.dateTime.month().day()))
                                .font(.subheadline)
                                .foregroundStyle(day.isFloorHold ? .secondary : .primary)
                            Spacer()
                            if day.isFloorHold {
                                Text("hold")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            Text("\(day.mg.doseFormatted) mg")
                                .font(.subheadline.weight(.medium))
                                .monospacedDigit()
                                .foregroundStyle(day.isFloorHold ? Color.secondary : Theme.tide)
                        }
                    }
                    if schedule.count > 45 {
                        Text("…and \(schedule.count - 45) more days")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }

                Section {
                    Text("Whichever you pick, the check-in gate still applies: if symptoms are still climbing four days after a cut, the app will tell you to hold. That's what makes a fast schedule survivable rather than a countdown to overshooting.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Pace")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Use this") {
                        plan.pace = choice
                        plan.currentStepStarted = Date()
                        try? context.save()
                        dismiss()
                    }
                }
            }
            .onAppear { choice = plan.pace }
        }
    }
}
