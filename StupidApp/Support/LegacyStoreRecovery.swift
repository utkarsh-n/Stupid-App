import Foundation
import SwiftData

/// Pulls back the doses stranded when the store moved into the App Group.
///
/// SwiftData does not migrate across container boundaries, so adding the widget
/// left the previous database sitting in the app's private Application Support
/// directory, intact but unread. It is still there — this opens it read-only,
/// copies anything the shared store doesn't already have, and marks itself done
/// so it never runs twice.
@MainActor
enum LegacyStoreRecovery {

    private static let completedKey = "legacyStoreRecovered"

    static var hasRun: Bool {
        SharedStore.defaults.bool(forKey: completedKey)
    }

    /// The default SwiftData location before the group container was adopted.
    private static var legacyURL: URL? {
        guard let support = try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        ) else { return nil }
        let url = support.appending(path: "default.store")
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    struct Outcome {
        var recovered: Int
        var found: Bool
    }

    @discardableResult
    static func run(into context: ModelContext) -> Outcome {
        guard !hasRun else { return Outcome(recovered: 0, found: false) }
        defer { SharedStore.defaults.set(true, forKey: completedKey) }

        guard let legacyURL else { return Outcome(recovered: 0, found: false) }

        // Read-only so a failed recovery can't damage the original.
        let config = ModelConfiguration(url: legacyURL, allowsSave: false)
        guard let legacy = try? ModelContainer(for: SharedStore.schema, configurations: config) else {
            return Outcome(recovered: 0, found: true)
        }

        let legacyContext = ModelContext(legacy)
        let snapshot = BackupService.snapshot(from: legacyContext)
        guard !snapshot.isEmpty else { return Outcome(recovered: 0, found: true) }

        let added = BackupService.restore(snapshot, into: context)
        return Outcome(recovered: added, found: true)
    }
}
