import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Data, notifications, and the honest note about where any of this lives.
struct SettingsSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var exportURL: URL?
    @State private var importing = false
    @State private var message: String?
    @State private var notificationsOn = NotificationService.shared.isEnabled

    private var rotations: [URL] { BackupService.rotations() }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Toggle("Dose windows and check-in", isOn: $notificationsOn)
                        .onChange(of: notificationsOn) { _, on in
                            Task {
                                if on {
                                    _ = await NotificationService.shared.requestAuthorization()
                                } else {
                                    NotificationService.shared.isEnabled = false
                                }
                                if let plan = try? context.fetch(FetchDescriptor<TaperPlan>()).first {
                                    await NotificationService.shared.reschedule(plan: plan)
                                }
                            }
                        }
                } header: {
                    Text("Notifications")
                } footer: {
                    Text("Three a day at most: your dose windows, and one evening check-in. Nothing on the lock screen names what this app is about.")
                }

                Section {
                    Button {
                        exportURL = BackupService.exportFile(from: context)
                    } label: {
                        Label("Export a backup file", systemImage: "square.and.arrow.up")
                    }

                    Button {
                        importing = true
                    } label: {
                        Label("Restore from a file", systemImage: "square.and.arrow.down")
                    }
                } header: {
                    Text("Your data")
                } footer: {
                    Text("The file goes wherever you send it and nowhere else. Restoring merges — it adds what's missing and never overwrites anything newer.")
                }

                Section {
                    if rotations.isEmpty {
                        Text("None yet.").foregroundStyle(.secondary)
                    } else {
                        ForEach(rotations.prefix(10), id: \.self) { url in
                            HStack {
                                Text(modified(url).formatted(.dateTime.month().day().hour().minute()))
                                    .font(.subheadline)
                                Spacer()
                                Button("Restore") { restore(url) }
                                    .font(.caption.weight(.semibold))
                                    .buttonStyle(.borderless)
                            }
                        }
                    }
                } header: {
                    Text("Automatic snapshots")
                } footer: {
                    Text("Written on every launch, ten kept. These live in this app's own storage on this phone.")
                }

                Section {
                    Label("No account, no server, no sync", systemImage: "lock.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.tide)
                    Text("This app talks to nothing. There is no backend and no third party holds your data.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Where your data lives")
                }

                Section {
                    Label("Turn on Advanced Data Protection", systemImage: "exclamationmark.shield.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.amber)
                    Text("Local storage is not the same as private. If iCloud Backup is on — it is by default — this app's data is swept into that backup, and Apple's own law-enforcement guidelines list third-party app data in backups as producible under a search warrant.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text("Advanced Data Protection closes that: it makes iCloud Backup end-to-end encrypted, so Apple holds no key and has nothing to hand over. Settings → your name → iCloud → Advanced Data Protection. It needs a recovery contact or recovery key first, and if you lose both, the data is gone for good — Apple genuinely cannot get it back.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text("Health data is already end-to-end encrypted either way, so the heart-rate and sleep side is covered regardless.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("The gap worth closing")
                }

                if let message {
                    Section { Text(message).font(.footnote).foregroundStyle(Theme.tide) }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(item: Binding(
                get: { exportURL.map { ExportPayload(url: $0) } },
                set: { exportURL = $0?.url }
            )) { payload in
                ShareSheet(url: payload.url)
            }
            .fileImporter(
                isPresented: $importing,
                allowedContentTypes: [.json]
            ) { result in
                if case .success(let url) = result { restore(url) }
            }
        }
    }

    private func modified(_ url: URL) -> Date {
        (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
    }

    private func restore(_ url: URL) {
        guard let snap = BackupService.decode(url) else {
            message = "Couldn't read that file."
            return
        }
        let added = BackupService.restore(snap, into: context)
        message = added > 0 ? "Restored \(added) records." : "Nothing new in that backup."
    }
}

private struct ExportPayload: Identifiable {
    let url: URL
    var id: String { url.path }
}

private struct ShareSheet: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
