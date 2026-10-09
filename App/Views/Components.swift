import AppKit
import SwiftUI
import FocusCore

extension ModeColor {
    var color: Color {
        switch self {
        case .blue: return .blue
        case .purple: return .purple
        case .pink: return .pink
        case .red: return .red
        case .orange: return .orange
        case .yellow: return .yellow
        case .green: return .green
        case .teal: return .teal
        case .gray: return .gray
        }
    }
}

enum ModeSymbols {
    static let all = [
        "bubble.left.and.bubble.right.fill", "briefcase.fill", "moon.stars.fill", "book.fill",
        "graduationcap.fill", "laptopcomputer", "gamecontroller.fill", "film.fill",
        "music.note", "figure.run", "heart.fill", "leaf.fill",
        "flame.fill", "bolt.fill", "star.fill", "bed.double.fill",
    ]
}

struct ModeIcon: View {
    let symbol: String
    let color: ModeColor
    var size: CGFloat = 32

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
            .fill(LinearGradient(colors: [color.color.opacity(0.75), color.color],
                                 startPoint: .top, endPoint: .bottom))
            .frame(width: size, height: size)
            .overlay(
                Image(systemName: symbol)
                    .font(.system(size: size * 0.48, weight: .semibold))
                    .foregroundStyle(.white)
            )
    }
}

/// Local badge (no network): SF Symbol for known sites, colored initial for the rest.
struct SiteIcon: View {
    let domain: String
    var size: CGFloat = 22

    var body: some View {
        ZStack {
            Circle().fill(LinearGradient(colors: brand.colors, startPoint: .topLeading, endPoint: .bottomTrailing))
            if let symbol = brand.symbol {
                Image(systemName: symbol).font(.system(size: size * 0.45, weight: .bold))
            } else {
                Text(String(domain.prefix(1)).uppercased()).font(.system(size: size * 0.5, weight: .bold))
            }
        }
        .foregroundStyle(.white)
        .frame(width: size, height: size)
    }

    private var brand: (colors: [Color], symbol: String?) {
        switch domain {
        case "x.com": return ([.black, Color(white: 0.25)], "xmark")
        case "instagram.com": return ([.orange, .pink, .purple], "camera.fill")
        case "youtube.com": return ([.red, Color(red: 0.7, green: 0, blue: 0)], "play.fill")
        default:
            let hash = domain.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) % 360 }
            let color = Color(hue: Double(hash) / 360, saturation: 0.55, brightness: 0.75)
            return ([color, color.opacity(0.8)], nil)
        }
    }
}

struct AppIcon: View {
    let bundleID: String
    var size: CGFloat = 22

    var body: some View {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                .resizable()
                .frame(width: size, height: size)
        } else {
            Image(systemName: "app.dashed")
                .frame(width: size, height: size)
        }
    }
}

struct SectionHeader: View {
    let title: String
    let count: Int

    var body: some View {
        HStack(spacing: 6) {
            Text(title).font(.headline)
            Text("\(count)")
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 7)
                .padding(.vertical, 1)
                .background(.quaternary, in: Capsule())
        }
    }
}
