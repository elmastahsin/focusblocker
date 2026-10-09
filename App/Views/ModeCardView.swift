import SwiftUI
import FocusCore

struct AddModeCardView: View {
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "plus").font(.system(size: 18, weight: .semibold))
            Text("Yeni").font(.caption.weight(.medium))
        }
        .foregroundStyle(.secondary)
        .frame(width: 88, height: 84)
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                .foregroundStyle(.secondary.opacity(0.6))
        )
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

struct ModeCardView: View {
    let mode: FocusMode
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 6) {
            ModeIcon(symbol: mode.symbol, color: mode.color, size: 36)
            Text(mode.name)
                .font(.caption.weight(.medium))
                .lineLimit(1)
        }
        .frame(width: 88, height: 84)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(mode.color.color.opacity(isSelected ? 0.2 : 0.07))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(mode.color.color, lineWidth: isSelected ? 2 : 0)
        )
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
