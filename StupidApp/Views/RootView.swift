import SwiftUI
import SwiftData
import UserNotifications

struct RootView: View {
    @Environment(\.modelContext) private var context
    @Query private var plans: [TaperPlan]
    @Query private var preparations: [Preparation]

    /// Lets a build be launched straight onto a given tab for screenshotting,
    /// since the simulator automation available here can't drive taps.
    /// `SIMCTL_CHILD_START_TAB=2 xcrun simctl launch …`
    @State private var selection = Int(ProcessInfo.processInfo.environment["START_TAB"] ?? "") ?? 0

    var body: some View {
        TabView(selection: $selection) {
            Tab("Today", systemImage: "circle.hexagongrid.fill", value: 0) {
                TodayView(tabSelection: $selection)
            }
            Tab("Plan", systemImage: "stairs", value: 1) {
                PlanView()
            }
            Tab("Trends", systemImage: "chart.line.uptrend.xyaxis", value: 2) {
                TrendsView()
            }
            Tab("Check in", systemImage: "text.bubble.fill", value: 3) {
                CopilotView()
            }
        }
        .tint(Theme.tide)
        .tabBarMinimizeBehavior(.onScrollDown)
        .task {
            seedIfNeeded()
            await setUpNotifications()
        }
    }

    private func setUpNotifications() async {
        let service = NotificationService.shared
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
        service.registerCategories()
        if !service.isEnabled {
            _ = await service.requestAuthorization()
        }
        if let plan = plans.first {
            await service.reschedule(plan: plan)
        }
    }

    private func seedIfNeeded() {
        // One-time nudge for installs created before the slot times moved to
        // 7:30 / 12:30 / 5:00, so an existing plan doesn't have to be deleted.
        if let existing = plans.first {
            if existing.slotMinutes == [480, 720, 1020] {
                existing.slotMinutes = [450, 750, 1020]
            }
            // Plans created before the pace picker existed defaulted to the
            // five-month schedule. Move them onto the stated preference; it's one
            // tap to change from the Plan screen.
            if existing.paceRaw == TaperPace.evidence.rawValue {
                existing.pace = .lowAndHold
            }
            try? context.save()
        }

        guard plans.isEmpty else { return }

        let plan = TaperPlan(
            baselineMgPerDay: 45,
            currentTargetMgPerDay: 15,
            jumpOffMgPerDay: 5,
            slotMinutes: [450, 750, 1020]   // 7:30, 12:30, 5:00
        )
        plan.currentStepIndex = 6
        plan.pace = .lowAndHold
        plan.currentStepStarted = Calendar.current.date(byAdding: .day, value: -4, to: Date()) ?? Date()
        context.insert(plan)

        if preparations.isEmpty {
            for prep in Preparation.userProducts {
                context.insert(prep)
            }
        }
        try? context.save()

        if ProcessInfo.processInfo.environment["SEED_HISTORY"] == "1" {
            seedHistory(plan: plan)
        }
    }

    /// Sample history, for looking at the trend screens before a real month of
    /// logs exists. Only ever runs behind an explicit launch flag.
    private func seedHistory(plan: TaperPlan) {
        let omega = preparations.first { $0.label == "Omega Extracts" }
            ?? Preparation.userProducts[0]
        let cal = Calendar.current

        for dayOffset in stride(from: 29, through: 1, by: -1) {
            guard let day = cal.date(byAdding: .day, value: -dayOffset, to: Date()) else { continue }
            // Descending from ~22 mg a month ago to today's 15 mg target.
            let progress = Double(29 - dayOffset) / 29.0
            let dailyTarget = 22 - (7 * progress)
            let perDose = dailyTarget / 3

            for (slot, minutes) in plan.slotMinutes.enumerated() {
                guard let at = cal.date(bySettingHour: minutes / 60,
                                        minute: minutes % 60,
                                        second: 0, of: day) else { continue }
                let jitter = Double((dayOffset * 7 + slot * 13) % 5) * 0.1 - 0.2
                let units = ((perDose + jitter) / omega.strengthPerUnit)
                let intake = Intake(
                    timestamp: at,
                    substance: .sevenOH,
                    reason: dayOffset % 6 == 0 && slot == 2 ? .withdrawal : .scheduled,
                    amount: units,
                    preparation: omega,
                    slotIndex: slot
                )
                context.insert(intake)
            }
        }
        try? context.save()
    }
}
