import SwiftUI

/// "Step 6" means nothing on its own. This is the context behind it — including
/// the part most taper apps hide, which is that the remaining third takes longer
/// than the first two-thirds did, and that this is normal rather than failure.
struct StepInfoSheet: View {
    @Environment(\.dismiss) private var dismiss
    let plan: TaperPlan?

    var body: some View {
        NavigationStack {
            List {
                if let plan {
                    Section {
                        LabeledContent("Current step", value: "\(plan.currentStepIndex)")
                        LabeledContent("Daily target", value: "\(plan.currentTargetMgPerDay.doseFormatted) mg")
                        LabeledContent("Per dose", value: "\(plan.perSlotTargetMg.doseFormatted) mg × \(plan.slotMinutes.count)")
                        LabeledContent("Day of this step", value: "\(plan.daysOnCurrentStep) of \(plan.recommendedStepDays)")
                    } header: {
                        Text("Where you are")
                    } footer: {
                        Text("A step is one dose level you hold for a stretch before the next reduction. The number just counts how many reductions you have made since starting at \(plan.baselineMgPerDay.doseFormatted) mg.")
                    }

                    Section {
                        LabeledContent("Next target", value: "\(plan.nextTargetMgPerDay.doseFormatted) mg")
                        LabeledContent("Steps remaining", value: "about \(plan.stepsRemaining)")
                        if let finish = plan.projectedFinish {
                            LabeledContent("Rough finish") {
                                Text(finish.formatted(.dateTime.month(.wide).year()))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } header: {
                        Text("What's ahead")
                    } footer: {
                        Text("The finish date is an estimate, not a deadline. Holding a step moves it, and nothing about that counts as falling behind.")
                    }

                    Section {
                        Text("Each reduction is a percentage of your **current** dose, never of where you started. Dose-to-receptor-occupancy is hyperbolic, so the same milligram cut removes a much bigger share of occupancy at 10 mg than it did at 45 — which is why the steps get smaller as you descend, and why the last third is genuinely harder rather than you doing worse.")
                        Text("Tapers running 12–52 weeks are roughly 3.6× more likely to finish than short ones, and reductions slower than 5% per week do better than faster ones. Slow is the version that works.")
                    } header: {
                        Text("Why the steps shrink")
                    }

                    Section {
                        Text("7-OH accumulates to a half-life over 20 hours in daily use, so a cut can feel completely fine for two days and land on the third. The app will not offer you a step down before day \(TaperPlan.delayedFeedbackDays), no matter how good the numbers look.")
                    } header: {
                        Text("Why you can't step down early")
                    }
                }
            }
            .navigationTitle("Your taper")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
