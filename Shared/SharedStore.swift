import Foundation
import SwiftData

/// The SwiftData store, shared between the app and its widget extension.
///
/// App Groups are the only way a widget can read the app's data — extensions run
/// in their own process with their own container. Everything the widget needs
/// (doses, plan, preparations) therefore has to live behind the group identifier
/// rather than the app's private directory.
enum SharedStore {
    static let appGroupID = "group.com.utkarsh.stupidapp"

    static let schema = Schema([
        Intake.self,
        Preparation.self,
        TaperPlan.self,
        CheckIn.self
    ])

    /// Falls back to a local store rather than crashing if the group container
    /// is unavailable — a provisioning problem shouldn't cost someone their
    /// ability to log a dose.
    static let container: ModelContainer = {
        let shared = ModelConfiguration(schema: schema, groupContainer: .identifier(appGroupID))
        if let container = try? ModelContainer(for: schema, configurations: shared) {
            return container
        }
        let local = ModelConfiguration(schema: schema)
        // If even this fails the process cannot function, and a crash here is
        // more diagnosable than a silently empty database.
        return try! ModelContainer(for: schema, configurations: local)
    }()

    /// Small values the widget needs without opening the database.
    static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }
}
