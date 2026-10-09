import SwiftUI
import FocusCore

/// Shown while a block runs. Intentionally has no stop, cancel or shorten control.
struct ActiveBlockView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        let mode = model.activeMode
        let tint = mode?.color.color ?? Color.accentColor

        VStack(spacing: 16) {
            HStack(spacing: 10) {
                if let mode {
                    ModeIcon(symbol: mode.symbol, color: mode.color, size: 32)
                } else {
                    Image(systemName: "lock.fill").font(.title3).frame(width: 32, height: 32)
                }
                VStack(alignment: .leading, spacing: 0) {
                    Text(mode?.name ?? "Aktif blok").font(.headline)
                    Text("Blok aktif").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }

            ZStack {
                Circle().stroke(tint.opacity(0.15), lineWidth: 12)
                Circle()
                    .trim(from: 0, to: model.progress ?? 1)
                    .stroke(tint, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: model.progress)
                VStack(spacing: 2) {
                    Text(model.remaining.clockString)
                        .font(.system(size: 30, weight: .semibold, design: .monospaced))
                    Text("kaldı").font(.caption).foregroundStyle(.secondary)
                }
            }
            .frame(width: 170, height: 170)

            Label("Süre dolana kadar durdurulamaz", systemImage: "lock.fill")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
