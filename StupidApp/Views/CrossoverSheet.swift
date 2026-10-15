import SwiftUI
import SwiftData

/// Walks the switch from tablets to solution, and makes the resulting batch a
/// real logged product so every dose after it is measured rather than nominal.
struct CrossoverSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let plan: TaperPlan?

    @State private var powderMg = "100"
    @State private var purityPercent = "95"
    @State private var volumeML = "100"
    @State private var scaleResolution = "1"
    @State private var batchLabel = "Astral Glitter batch"
    @State private var created = false

    private var recipe: Crossover.Recipe {
        Crossover.Recipe(
            powderMg: Double(powderMg) ?? 0,
            purity: (Double(purityPercent) ?? 95) / 100,
            volumeML: Double(volumeML) ?? 0
        )
    }

    private var perSlot: Double { plan?.perSlotTargetMg ?? 5 }
    private var steps: [Crossover.Step] {
        Crossover.plan(slotCount: plan?.slotMinutes.count ?? 3, perSlotTargetMg: perSlot)
    }

    var body: some View {
        NavigationStack {
            List {
                whySection
                recipeSection
                dosingSection
                scheduleSection
                safetySection
                saveSection
            }
            .navigationTitle("Switch to solution")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Why

    private var whySection: some View {
        Section {
            Text("A 1 mg target isn't something tablets can do. Splitting a 10 mg tablet by hand has a wider error than the whole dose you'd be aiming at, and your five products run 10 to 18 mg nominal — with commercial 7-OH typically measuring 32–81% of what the label claims.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Text("Weighing 100 mg and diluting it carries the scale's accuracy down into every dose. Weighing 5 mg directly would not.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        } header: {
            Text("Why this is required, not optional")
        }
    }

    // MARK: - Recipe

    private var recipeSection: some View {
        Section {
            LabeledContent("Powder weighed") {
                TextField("mg", text: $powderMg)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
            }
            LabeledContent("Purity") {
                TextField("%", text: $purityPercent)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
            }
            LabeledContent("Dissolved into") {
                TextField("mL", text: $volumeML)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
            }
            LabeledContent("Scale resolution") {
                TextField("mg", text: $scaleResolution)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
            }

            LabeledContent("Concentration") {
                Text("\(recipe.concentrationMgPerML.doseFormatted) mg/mL")
                    .fontWeight(.semibold)
                    .foregroundStyle(Theme.tide)
            }
            LabeledContent("Weighing error") {
                Text("±\(recipe.errorPercent(scaleResolutionMg: Double(scaleResolution) ?? 1).doseFormatted)%")
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("The batch")
        } footer: {
            Text("7-OH freebase dissolves poorly in plain water — acidify it (a pinch of citric acid or a squeeze of lemon) so it goes into solution properly. A suspension that settles between doses is worse than tablets, because the error becomes invisible and inconsistent rather than merely wide.")
        }
    }

    // MARK: - Dosing

    private var dosingSection: some View {
        Section {
            // Deduplicated: the per-slot target frequently *is* one of the
            // reference doses, and duplicate ids in a ForEach are undefined.
            ForEach(Array(Set([0.5, 1.0, 2.0, perSlot])).sorted(), id: \.self) { mg in
                LabeledContent("\(mg.doseFormatted) mg") {
                    Text("\(recipe.millilitresFor(mg: mg).doseFormatted) mL")
                        .monospacedDigit()
                        .fontWeight(.medium)
                }
            }
        } header: {
            Text("Doses by syringe")
        } footer: {
            Text("An oral syringe measures these directly. This is what makes 0.25 mg steps possible at the bottom of the taper, where tablets stopped being able to help.")
        }
    }

    // MARK: - Schedule

    private var scheduleSection: some View {
        Section {
            ForEach(steps) { step in
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text("\(step.order + 1). \(Crossover.slotName(step.slotIndex))")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Text("start at \(step.startMg.doseFormatted) mg")
                            .font(.subheadline)
                            .foregroundStyle(Theme.tide)
                    }
                    Text("\(recipe.millilitresFor(mg: step.startMg).doseFormatted) mL · hold \(Crossover.settleDaysPerSlot) days before the next slot")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 2)
            }
        } header: {
            Text("Convert one slot at a time")
        } footer: {
            Text("Midday first — it's the most forgiving slot to be wrong in, with the evening dose close behind if you've underestimated. Morning goes last, because morning withdrawal is the strongest relapse driver in this drug and 7am is the worst time to discover the solution is weak.")
        }
    }

    // MARK: - Safety

    private var safetySection: some View {
        Section {
            Label("Start at 60% of nominal", systemImage: "exclamationmark.triangle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.amber)
            Text("This is the one number worth getting right. Your nominal 5 mg of split tablet is really somewhere around 1.6–4 mg of actual 7-OH. Solution from 95% powder is genuinely 5 mg when it says 5 mg — so crossing over at face value isn't a like-for-like swap, it can be a real increase of anywhere from a quarter to triple.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Text("Your tolerance is set by what you've actually been taking, not by what the bottle claims. Start low and titrate up over a couple of days if withdrawal shows. Naloxone in the house before the first solution dose.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Text("Nothing sedating stacked on top while you're finding the strength — no alcohol, no antihistamines, and remember 7-OH depresses breathing at over three times the potency of morphine.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        } header: {
            Text("The direction of the error that matters")
        }
    }

    // MARK: - Save

    private var saveSection: some View {
        Section {
            TextField("Batch label", text: $batchLabel)
            Button {
                createBatch()
            } label: {
                Label(created ? "Batch saved" : "Save this batch as a product",
                      systemImage: created ? "checkmark.circle.fill" : "plus.circle.fill")
            }
            .disabled(created || recipe.concentrationMgPerML <= 0)
        } footer: {
            Text("Saving it makes the solution a product you can pick when logging, with doses entered in mL. Unlike the tablets, this one is marked as verified content — the taper stops being an estimate from here.")
        }
    }

    private func createBatch() {
        let prep = Preparation(
            label: batchLabel,
            kind: .solution,
            substance: .sevenOH,
            strengthPerUnit: recipe.concentrationMgPerML,
            purity: recipe.purity,
            lot: Date().formatted(.iso8601.year().month().day()),
            notes: "\(recipe.powderMg.doseFormatted) mg powder at \(Int(recipe.purity * 100))% into \(recipe.volumeML.doseFormatted) mL"
        )
        context.insert(prep)
        try? context.save()
        created = true
    }
}
