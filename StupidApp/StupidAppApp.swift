import SwiftUI
import SwiftData

@main
struct StupidAppApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.dark)
        }
        // The shared container rather than a private one, so the widget can read
        // the same doses the app writes.
        .modelContainer(SharedStore.container)
    }
}
