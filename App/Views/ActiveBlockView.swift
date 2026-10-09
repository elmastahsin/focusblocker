import SwiftUI
import FocusCore

/// Shown while a block runs. Intentionally has no stop, cancel or shorten control.
struct ActiveBlockView: View {
    @EnvironmentObject private var model: AppModel

    private static let quotes = [
        "Derin iş, sığ dikkatle yapılmaz.",
        "Bir seferde tek şey.",
        "Bildirimler bekleyebilir, sen beklemiyorsun.",
        "Küçük adımlar, büyük ilerleme.",
        "Şu an yaptığın iş, yapabileceğin en iyi iş.",
        "Dikkat, en değerli sermayen.",
        "Odaklan. Gerisi gürültü.",
        "Zor kısım başlamaktı; onu zaten yaptın.",
        "Akış hali sabır ister.",
        "Bitirdiğin her blok bir zafer.",
    ]

    /// Changes every 3 minutes of the block.
    private var quote: String {
        Self.quotes[Int(model.elapsed / 180) % Self.quotes.count]
    }

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

            Text(quote)
                .font(.callout.italic())
                .multilineTextAlignment(.center)
                .id(quote)
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.6), value: quote)

            Label("Süre dolana kadar durdurulamaz", systemImage: "lock.fill")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
