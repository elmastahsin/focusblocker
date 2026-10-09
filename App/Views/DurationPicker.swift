import AppKit
import FocusCore
import SwiftUI

struct DurationPicker: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        let tint = model.displayedMode.color.color

        VStack(alignment: .leading, spacing: 10) {
            Text("Süre").font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)

            HStack(spacing: 6) {
                ForEach(BlockDuration.allCases, id: \.self) { option in
                    let selected = model.duration == option
                    Button { model.duration = option } label: {
                        Text(option.title)
                            .font(.callout.weight(.medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 7)
                            .background(selected ? tint : Color.primary.opacity(0.08), in: Capsule())
                            .foregroundStyle(selected ? Color.white : Color.primary)
                    }
                    .buttonStyle(.plain)
                }
            }

            if model.duration == .custom {
                Stepper("\(model.customMinutes) dakika",
                        value: $model.customMinutes,
                        in: BlockDuration.customMinutesRange,
                        step: 5)
            }

            Button(action: confirmAndStart) {
                Label("Başlat", systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(tint)
            .disabled(!model.canStart)
        }
    }

    private func confirmAndStart() {
        let mode = model.displayedMode
        let seconds = model.duration.seconds(customMinutes: model.customMinutes)
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "\"\(mode.name)\" bloğu başlatılsın mı?"
        alert.informativeText = """
        Başlattıktan sonra durduramazsın.
        Süre: \(seconds.clockString). \
        \(mode.sites.count) site, \(mode.apps.count) uygulama engellenecek.
        """
        alert.addButton(withTitle: "Başlat")
        alert.addButton(withTitle: "Vazgeç")
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            Task { await model.startBlock() }
        }
    }
}

extension TimeInterval {
    /// "01:23:45"
    var clockString: String {
        let total = Int(self.rounded(.up))
        return String(format: "%02d:%02d:%02d", total / 3600, (total / 60) % 60, total % 60)
    }
}
