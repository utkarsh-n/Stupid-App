import Foundation
import AppIntents
import SwiftData

/// Makes your products addressable by name, so "omega extracts" resolves to the
/// right `Preparation` rather than needing an identifier nobody knows.
struct PreparationEntity: AppEntity, Identifiable {
    var id: UUID
    var name: String
    var strengthMg: Double

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Product")
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(name)",
            subtitle: "\(strengthMg.doseFormatted) mg"
        )
    }

    static var defaultQuery = PreparationQuery()
}

/// `EntityStringQuery` is the part that lets speech match — without it Siri can
/// only offer a list, not understand a name you said.
struct PreparationQuery: EntityStringQuery {
    @MainActor
    private func all() -> [PreparationEntity] {
        let context = ModelContext(SharedStore.container)
        let preps = (try? context.fetch(FetchDescriptor<Preparation>())) ?? []
        return preps
            .filter { $0.isActive }
            .map { PreparationEntity(id: $0.id, name: $0.label, strengthMg: $0.strengthPerUnit) }
    }

    @MainActor
    func entities(for identifiers: [UUID]) async throws -> [PreparationEntity] {
        all().filter { identifiers.contains($0.id) }
    }

    @MainActor
    func entities(matching string: String) async throws -> [PreparationEntity] {
        let needle = string.lowercased()
        return all().filter { $0.name.lowercased().contains(needle) }
    }

    @MainActor
    func suggestedEntities() async throws -> [PreparationEntity] {
        all()
    }
}

/// Which slot a dose belongs to. A closed set, which is what makes it reliably
/// matchable from speech — "my noon dose" resolves, where an arbitrary number
/// often won't.
enum DoseSlotChoice: String, AppEnum {
    case morning
    case noon
    case evening

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Dose slot")
    }

    static var caseDisplayRepresentations: [DoseSlotChoice: DisplayRepresentation] {
        [
            .morning: DisplayRepresentation(
                title: "morning",
                synonyms: ["first", "early", "am", "wake up", "breakfast"]
            ),
            .noon: DisplayRepresentation(
                title: "noon",
                synonyms: ["midday", "lunch", "lunchtime", "afternoon", "second"]
            ),
            .evening: DisplayRepresentation(
                title: "evening",
                synonyms: ["night", "last", "dinner", "pm", "bedtime"]
            )
        ]
    }

    var slotIndex: Int {
        switch self {
        case .morning: return 0
        case .noon:    return 1
        case .evening: return 2
        }
    }
}
