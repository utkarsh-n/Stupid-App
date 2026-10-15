import Foundation
import SwiftData

/// Durability without a server.
///
/// The failure this exists to prevent already happened once: moving the store
/// into an App Group orphaned a day of logs, because SwiftData does not migrate
/// across container boundaries. Schema changes, container moves, and a reinstall
/// all have the same shape, and none of them are worth a cloud database of
/// controlled-substance use sitting on somebody else's infrastructure.
///
/// So: a plain JSON snapshot, written automatically to the shared container on
/// every launch, ten kept in rotation, plus a file you can export anywhere and
/// import back. No account, no network, no third party.
struct BackupSnapshot: Codable {
    var version = 1
    var exportedAt = Date()
    var intakes: [IntakeDTO] = []
    var preparations: [PreparationDTO] = []
    var plans: [PlanDTO] = []
    var checkIns: [CheckInDTO] = []

    var isEmpty: Bool {
        intakes.isEmpty && plans.isEmpty && checkIns.isEmpty
    }

    var summary: String {
        "\(intakes.count) doses · \(checkIns.count) check-ins"
    }
}

struct IntakeDTO: Codable {
    var id: UUID
    var timestamp: Date
    var substanceRaw: String
    var reasonRaw: String
    var amount: Double
    var nominalMg: Double
    var slotIndex: Int?
    var note: String?
    var preparationID: UUID?
}

struct PreparationDTO: Codable {
    var id: UUID
    var label: String
    var substanceRaw: String
    var kindRaw: String
    var strengthPerUnit: Double
    var lot: String?
    var isActive: Bool
    var hasVerifiedContent: Bool
}

struct PlanDTO: Codable {
    var id: UUID
    var startDate: Date
    var baselineMgPerDay: Double
    var currentTargetMgPerDay: Double
    var jumpOffMgPerDay: Double
    var slotMinutes: [Int]
    var currentStepIndex: Int
    var currentStepStarted: Date
    var isHolding: Bool
    var holdStarted: Date?
    var paceRaw: String
}

struct CheckInDTO: Codable {
    var id: UUID
    var timestamp: Date
    var text: String
    var sourceRaw: String
    var scores: [Int]
    var symptomCodes: [String]
    var symptomLevels: [Int]
    var evidence: String?
}

@MainActor
enum BackupService {

    private static var folder: URL? {
        guard let base = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: SharedStore.appGroupID
        ) else { return nil }
        let dir = base.appending(path: "Backups", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    // MARK: - Capture

    static func snapshot(from context: ModelContext) -> BackupSnapshot {
        var snap = BackupSnapshot()

        if let intakes = try? context.fetch(FetchDescriptor<Intake>()) {
            snap.intakes = intakes.map {
                IntakeDTO(
                    id: $0.id, timestamp: $0.timestamp, substanceRaw: $0.substanceRaw,
                    reasonRaw: $0.reasonRaw, amount: $0.amount, nominalMg: $0.nominalMg,
                    slotIndex: $0.slotIndex, note: $0.note,
                    preparationID: $0.preparation?.id
                )
            }
        }
        if let preps = try? context.fetch(FetchDescriptor<Preparation>()) {
            snap.preparations = preps.map {
                PreparationDTO(
                    id: $0.id, label: $0.label, substanceRaw: $0.substanceRaw,
                    kindRaw: $0.kindRaw, strengthPerUnit: $0.strengthPerUnit,
                    lot: $0.lot, isActive: $0.isActive,
                    hasVerifiedContent: $0.hasVerifiedContent
                )
            }
        }
        if let plans = try? context.fetch(FetchDescriptor<TaperPlan>()) {
            snap.plans = plans.map {
                PlanDTO(
                    id: $0.id, startDate: $0.startDate,
                    baselineMgPerDay: $0.baselineMgPerDay,
                    currentTargetMgPerDay: $0.currentTargetMgPerDay,
                    jumpOffMgPerDay: $0.jumpOffMgPerDay,
                    slotMinutes: $0.slotMinutes,
                    currentStepIndex: $0.currentStepIndex,
                    currentStepStarted: $0.currentStepStarted,
                    isHolding: $0.isHolding, holdStarted: $0.holdStarted,
                    paceRaw: $0.paceRaw
                )
            }
        }
        if let checkIns = try? context.fetch(FetchDescriptor<CheckIn>()) {
            snap.checkIns = checkIns.map {
                CheckInDTO(
                    id: $0.id, timestamp: $0.timestamp, text: $0.text,
                    sourceRaw: $0.sourceRaw, scores: $0.scores,
                    symptomCodes: $0.symptomCodes, symptomLevels: $0.symptomLevels,
                    evidence: $0.evidence
                )
            }
        }
        return snap
    }

    // MARK: - Automatic rotation

    /// Called on launch. Skips writing when nothing has changed since the last
    /// snapshot, so ten rotations means ten *distinct* states rather than ten
    /// copies of this morning.
    static func autoSnapshot(context: ModelContext) {
        guard let folder else { return }
        let snap = snapshot(from: context)
        guard !snap.isEmpty else { return }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(snap) else { return }

        let existing = rotations()
        if let newest = existing.first,
           let previous = try? Data(contentsOf: newest),
           previous.count == data.count {
            return
        }

        let stamp = ISO8601DateFormatter().string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
        try? data.write(to: folder.appending(path: "snapshot-\(stamp).json"))

        for stale in rotations().dropFirst(10) {
            try? FileManager.default.removeItem(at: stale)
        }
    }

    static func rotations() -> [URL] {
        guard let folder,
              let files = try? FileManager.default.contentsOfDirectory(
                at: folder, includingPropertiesForKeys: [.contentModificationDateKey]
              ) else { return [] }
        return files
            .filter { $0.pathExtension == "json" }
            .sorted { a, b in
                let da = (try? a.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                let db = (try? b.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                return da > db
            }
    }

    // MARK: - Export

    /// Writes a shareable file. Goes wherever you send it — Files, AirDrop, a
    /// disk — and nowhere you didn't send it.
    static func exportFile(from context: ModelContext) -> URL? {
        let snap = snapshot(from: context)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(snap) else { return nil }

        // Neutral on purpose. Filenames are among the few things that stay
        // readable to Apple even under Advanced Data Protection, and are
        // obtainable at a lower legal standard than file contents — so the name
        // should say nothing the contents don't already protect.
        let name = "export-\(Date().formatted(.iso8601.year().month().day())).json"
        let url = FileManager.default.temporaryDirectory.appending(path: name)
        try? data.write(to: url)
        return url
    }

    // MARK: - Restore

    static func decode(_ url: URL) -> BackupSnapshot? {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }

        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(BackupSnapshot.self, from: data)
    }

    /// Merges a snapshot in. Existing rows with the same id are left alone, so
    /// restoring twice is harmless and restoring an old file can't delete
    /// anything newer.
    @discardableResult
    static func restore(_ snap: BackupSnapshot, into context: ModelContext) -> Int {
        var added = 0

        let existingPreps = (try? context.fetch(FetchDescriptor<Preparation>())) ?? []
        var prepsByID = Dictionary(uniqueKeysWithValues: existingPreps.map { ($0.id, $0) })

        for dto in snap.preparations where prepsByID[dto.id] == nil {
            let prep = Preparation(
                label: dto.label,
                kind: PreparationKind(rawValue: dto.kindRaw) ?? .tablet,
                substance: Substance(rawValue: dto.substanceRaw) ?? .sevenOH,
                strengthPerUnit: dto.strengthPerUnit,
                lot: dto.lot,
                isActive: dto.isActive
            )
            prep.id = dto.id
            context.insert(prep)
            prepsByID[dto.id] = prep
            added += 1
        }

        let existingIntakeIDs = Set(((try? context.fetch(FetchDescriptor<Intake>())) ?? []).map(\.id))
        for dto in snap.intakes where !existingIntakeIDs.contains(dto.id) {
            let intake = Intake(
                timestamp: dto.timestamp,
                substance: Substance(rawValue: dto.substanceRaw) ?? .sevenOH,
                reason: DoseReason(rawValue: dto.reasonRaw) ?? .scheduled,
                amount: dto.amount,
                preparation: dto.preparationID.flatMap { prepsByID[$0] },
                slotIndex: dto.slotIndex
            )
            intake.id = dto.id
            intake.nominalMg = dto.nominalMg
            intake.note = dto.note
            context.insert(intake)
            added += 1
        }

        let existingCheckInIDs = Set(((try? context.fetch(FetchDescriptor<CheckIn>())) ?? []).map(\.id))
        for dto in snap.checkIns where !existingCheckInIDs.contains(dto.id) {
            let entry = CheckIn(text: dto.text, source: CheckInSource(rawValue: dto.sourceRaw) ?? .measured)
            entry.id = dto.id
            entry.timestamp = dto.timestamp
            entry.scores = dto.scores
            entry.symptomCodes = dto.symptomCodes
            entry.symptomLevels = dto.symptomLevels
            entry.evidence = dto.evidence
            context.insert(entry)
            added += 1
        }

        // The plan is configuration rather than history — only restored when
        // there isn't one, so importing a backup can't silently rewrite the
        // schedule someone is currently following.
        let hasPlan = ((try? context.fetch(FetchDescriptor<TaperPlan>())) ?? []).isEmpty == false
        if !hasPlan, let dto = snap.plans.first {
            let plan = TaperPlan(
                baselineMgPerDay: dto.baselineMgPerDay,
                currentTargetMgPerDay: dto.currentTargetMgPerDay,
                jumpOffMgPerDay: dto.jumpOffMgPerDay,
                slotMinutes: dto.slotMinutes
            )
            plan.id = dto.id
            plan.startDate = dto.startDate
            plan.currentStepIndex = dto.currentStepIndex
            plan.currentStepStarted = dto.currentStepStarted
            plan.isHolding = dto.isHolding
            plan.holdStarted = dto.holdStarted
            plan.paceRaw = dto.paceRaw
            context.insert(plan)
            added += 1
        }

        try? context.save()
        return added
    }
}
