import ServiceManagement
import SwiftUI
import FocusCore

struct MenuContentView: View {
    enum Tab { case start, modes }

    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var updater: Updater
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
                Button("Güncellemeleri kontrol et") { updater.checkForUpdates() }
                    .buttonStyle(.borderless)
                    .font(.callout)
                Spacer()
                Button("Çık") { NSApplication.shared.terminate(nil) }
                    .buttonStyle(.borderless)
                    .font(.callout)
                    .help(model.isActive ? "Blok daemon tarafından sürdürülür." : "")
            }
        }
        .padding(16)
        // Start tab fits its content (custom duration / banner grow it); Modes needs room for its lists.
        .frame(width: 400, height: model.isActive ? 420 : (current == .modes ? 560 : nil))
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
                FocusHeatmap(grid: model.history.weeklyGrid(weeks: FocusHeatmap.weeks, endingAt: model.now))
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

/// GitHub-style grid: one column per week, one row per weekday, greener = more focus.
private struct FocusHeatmap: View {
    /// Fixed, not flexible: the menu bar window sizes to its minimum, which collapses flexible cells.
    /// 23 weeks × (13 + 3) - 3 = 365pt, fills the 368pt content width.
    static let weeks = 23
    private static let cell: CGFloat = 13

    let grid: [[(date: Date, focus: TimeInterval)?]]

    var body: some View {
        HStack(spacing: 3) {
            ForEach(grid.indices, id: \.self) { week in
                VStack(spacing: 3) {
                    ForEach(grid[week].indices, id: \.self) { weekday in
                        cell(grid[week][weekday])
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func cell(_ day: (date: Date, focus: TimeInterval)?) -> some View {
        let shape = RoundedRectangle(cornerRadius: 2)
        if let day {
            Group {
                if day.focus > 0 {
                    shape.fill(Color.green.opacity(opacity(day.focus)))
                } else {
                    shape.fill(.quaternary)
                }
            }
            .frame(width: Self.cell, height: Self.cell)
            .help("\(day.date.formatted(.dateTime.day().month(.abbreviated))) · \(day.focus.durationText)")
        } else {
            Color.clear.frame(width: Self.cell, height: Self.cell)
        }
    }

    /// Fixed thresholds so days stay comparable over time.
    private func opacity(_ focus: TimeInterval) -> Double {
        switch focus {
        case ..<1800: return 0.3
        case ..<3600: return 0.55
        case ..<7200: return 0.8
        default: return 1
        }
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
            Text("Bu modda açık site veya uygulama yok. \"Modlar\" sekmesinden ekle ya da aç.")
                .font(.caption)
                .foregroundStyle(.orange)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            HStack(spacing: 10) {
                HStack(spacing: -6) {
                    ForEach(mode.enabledSites.prefix(6), id: \.self) { site in
                        SiteIcon(domain: site, size: 24)
                            .overlay(Circle().stroke(Color(nsColor: .windowBackgroundColor), lineWidth: 2))
                    }
                }
                Text("\(mode.enabledSites.count) site · \(mode.enabledAppIDs.count) uygulama")
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
