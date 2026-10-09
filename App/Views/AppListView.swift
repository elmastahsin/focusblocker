import AppKit
import SwiftUI
import UniformTypeIdentifiers
import FocusCore

/// App editor for one mode. Used in the Modlar window.
struct AppListView: View {
    @Binding var mode: FocusMode
    let isLocked: Bool
    @State private var pickError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Uygulamalar", count: mode.apps.count)

            ForEach(mode.apps) { app in
                HStack(spacing: 10) {
                    AppIcon(bundleID: app.bundleID)
                    Text(app.name)
                    Text(app.bundleID).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    Spacer()
                    Button { remove(app) } label: {
                        Image(systemName: "minus.circle.fill").foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless)
                    .disabled(isLocked)
                }
            }

            Button("Uygulama ekle…", action: pickApps)
                .disabled(isLocked)

            if let pickError {
                Text(pickError).font(.caption).foregroundStyle(.red)
            }
        }
    }

    private func remove(_ app: BlockedApp) {
        var copy = mode
        copy.removeApp(bundleID: app.bundleID)
        mode = copy
    }

    private func pickApps() {
        let panel = NSOpenPanel()
        panel.directoryURL = URL(fileURLWithPath: "/Applications", isDirectory: true)
        panel.allowedContentTypes = [.applicationBundle]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.prompt = "Ekle"
        guard panel.runModal() == .OK else { return }

        var copy = mode
        var failed: [String] = []
        for url in panel.urls {
            if let app = BlockedApp.load(from: url) { copy.addApp(app) } else { failed.append(url.lastPathComponent) }
        }
        mode = copy
        pickError = failed.isEmpty ? nil : "Bundle ID okunamadı: \(failed.joined(separator: ", "))"
    }
}
