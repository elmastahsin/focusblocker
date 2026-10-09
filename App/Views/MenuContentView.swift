import ServiceManagement
import SwiftUI
import FocusCore

struct MenuContentView: View {
    enum Tab { case start, modes }

    @EnvironmentObject private var model: AppModel
    @State private var tab: Tab = .start

    var body: some View {
        // Modes are locked while a block runs, so the block screen always wins.
        let current = model.isActive ? Tab.start : tab

        VStack(alignment: .leading, spacing: 14) {
            header

            if !model.isActive {
                Picker("", selection: Binding(get: { current }, set: { tab = $0 })) {
                    Label("Başlat", systemImage: "play.fill").tag(Tab.start)
                    Label("Modlar", systemImage: "square.grid.2x2.fill").tag(Tab.modes)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            if model.registration != .enabled {
                RegistrationBanner()
            }

            Group {
                switch current {
                case .start: StartTab()
                case .modes: ModesTab()
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)

            Divider()
            HStack {
                Spacer()
                Button("Çık") { NSApplication.shared.terminate(nil) }
                    .buttonStyle(.borderless)
                    .font(.callout)
                    .help(model.isActive ? "Blok daemon tarafından sürdürülür." : "")
            }
        }
        .padding(16)
        .frame(width: 400, height: model.isActive ? 420 : 560)
        .onChange(of: tab) { _ in model.errorMessage = nil }
    }

    private var header: some View {
        HStack {
            Image(systemName: model.isActive ? "lock.fill" : "scope")
                .foregroundStyle(model.displayedMode.color.color)
            Text("FocusBlocker").font(.headline)
            Spacer()
        }
    }
}

private struct StartTab: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if model.isActive {
                ActiveBlockView()
            } else if let session = model.completedSession {
                CompletionCard(session: session) { model.completedSession = nil }
            } else {
                ModeStrip(onAdd: nil)
                ModeSummary(mode: model.displayedMode)
                DurationPicker()
                FocusStatsLine(today: model.todayFocus, streak: model.streak)
            }

            if let message = model.errorMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct FocusStatsLine: View {
    let today: TimeInterval
    let streak: Int

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "chart.bar.fill").foregroundStyle(.secondary)
            Text("Bugün \(today.durationText)")
            if streak > 0 {
                Text("·")
                Text("🔥 \(streak) gün seri")
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}

/// Shown once after a block finishes, until dismissed.
private struct CompletionCard: View {
    let session: FocusSession
    let onDismiss: () -> Void
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)
                .scaleEffect(appeared ? 1 : 0.3)
                .rotationEffect(.degrees(appeared ? 0 : -30))
                .opacity(appeared ? 1 : 0)
            Text("Tamamlandı!").font(.title2.bold())
            Text("\(session.duration.durationText) odak. Kısa bir mola ver.")
                .font(.callout)
                .foregroundStyle(.secondary)
            Button("Tamam", action: onDismiss)
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.55)) { appeared = true }
        }
    }
}

private struct ModesTab: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ModeStrip(onAdd: add)
            ModeEditorView(modeID: model.modes.selectedModeID)
                .id(model.modes.selectedModeID)
        }
    }

    private func add() {
        if let id = model.createMode() { model.selectMode(id) }
    }
}

/// Horizontal mode cards. Tapping one selects it (for starting, or for editing in the Modlar tab).
private struct ModeStrip: View {
    @EnvironmentObject private var model: AppModel
    let onAdd: (() -> Void)?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(model.modes.library.modes) { mode in
                    Button { model.selectMode(mode.id) } label: {
                        ModeCardView(mode: mode, isSelected: mode.id == model.modes.selectedModeID)
                    }
                    .buttonStyle(.plain)
                }
                if let onAdd {
                    Button(action: onAdd) { AddModeCardView() }
                        .buttonStyle(.plain)
                }
            }
            .padding(2)
        }
        .frame(height: 92)
    }
}

private struct ModeSummary: View {
    let mode: FocusMode

    var body: some View {
        if mode.isEmpty {
            Text("Bu modda engellenecek bir şey yok. \"Modlar\" sekmesinden site veya uygulama ekle.")
                .font(.caption)
                .foregroundStyle(.orange)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            HStack(spacing: 10) {
                HStack(spacing: -6) {
                    ForEach(mode.sites.prefix(6), id: \.self) { site in
                        SiteIcon(domain: site, size: 24)
                            .overlay(Circle().stroke(Color(nsColor: .windowBackgroundColor), lineWidth: 2))
                    }
                }
                Text("\(mode.sites.count) site · \(mode.apps.count) uygulama")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
    }
}

private struct RegistrationBanner: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(message)
                .font(.caption)
                .fixedSize(horizontal: false, vertical: true)
            switch model.registration {
            case .notRegistered, .notFound:
                Button("Daemon'u kaydet") { model.registerDaemon() }
            case .requiresApproval:
                Button("System Settings'i aç") { model.openSystemSettings() }
            default:
                EmptyView()
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.yellow.opacity(0.2), in: RoundedRectangle(cornerRadius: 8))
    }

    private var message: String {
        switch model.registration {
        case .notRegistered: return "Daemon kayıtlı değil. Blok başlatmak için kaydet."
        case .requiresApproval: return "Onay bekliyor: System Settings → Login Items bölümünde FocusBlocker'ı aç."
        case .notFound: return "Daemon henüz kayıtlı değil (veya plist bulunamadı). Kaydetmeyi dene."
        default: return "Daemon durumu bilinmiyor."
        }
    }
}
