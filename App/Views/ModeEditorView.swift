import AppKit
import SwiftUI
import FocusCore

/// Editor for one mode. Appearance, sites and apps save immediately; the name saves on Return or when leaving.
struct ModeEditorView: View {
    @EnvironmentObject private var model: AppModel
    let modeID: UUID

    @State private var name = ""

    private var mode: Binding<FocusMode> {
        Binding(
            get: { model.modes.library.mode(id: modeID) ?? FocusMode(name: "", symbol: "star.fill", color: .gray) },
            set: { model.updateMode($0) }
        )
    }

    var body: some View {
        let current = mode.wrappedValue
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 14) {
                        ModeIcon(symbol: current.symbol, color: current.color, size: 52)
                        TextField("Mod adı", text: $name)
                            .textFieldStyle(.roundedBorder)
                            .font(.title3)
                            .onSubmit(commitName)
                    }
                    if let message = model.errorMessage {
                        Text(message).font(.caption).foregroundStyle(.red)
                    }
                }

                appearance(current)
                SiteListView(mode: mode, isLocked: model.isActive)
                AppListView(mode: mode, isLocked: model.isActive)
                actions
            }
            .disabled(model.isActive)
            .padding(.vertical, 4)
            .padding(.trailing, 4)
        }
        .onAppear { name = current.name }
        .onDisappear(perform: commitName)
    }

    private func appearance(_ current: FocusMode) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Görünüm").font(.headline)

            HStack(spacing: 10) {
                ForEach(ModeColor.allCases, id: \.self) { color in
                    Button { setColor(color) } label: {
                        Circle()
                            .fill(color.color)
                            .frame(width: 24, height: 24)
                            .overlay(Circle().stroke(.primary.opacity(0.8), lineWidth: current.color == color ? 2.5 : 0).padding(-3))
                    }
                    .buttonStyle(.plain)
                }
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 38), spacing: 8)], alignment: .leading, spacing: 8) {
                ForEach(ModeSymbols.all, id: \.self) { symbol in
                    Button { setSymbol(symbol) } label: {
                        Image(systemName: symbol)
                            .font(.system(size: 16))
                            .frame(width: 38, height: 38)
                            .background(
                                RoundedRectangle(cornerRadius: 9, style: .continuous)
                                    .fill(current.symbol == symbol ? current.color.color.opacity(0.25) : Color.primary.opacity(0.07))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var actions: some View {
        HStack {
            Button("Kopyala") { _ = model.duplicateMode(id: modeID) }
            Button("Sil", role: .destructive, action: confirmDelete)
                .disabled(model.modes.library.modes.count <= 1)
        }
    }

    private func confirmDelete() {
        guard let stored = model.modes.library.mode(id: modeID) else { return }
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "\"\(stored.name)\" modu silinsin mi?"
        alert.informativeText = "Bu işlem geri alınamaz."
        alert.addButton(withTitle: "Sil")
        alert.addButton(withTitle: "Vazgeç")
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            model.deleteMode(id: modeID)
        }
    }

    private func setColor(_ color: ModeColor) {
        var copy = mode.wrappedValue
        copy.color = color
        model.updateMode(copy)
    }

    private func setSymbol(_ symbol: String) {
        var copy = mode.wrappedValue
        copy.symbol = symbol
        model.updateMode(copy)
    }

    private func commitName() {
        // The mode may be gone already (deleted): nothing to save then.
        guard let stored = model.modes.library.mode(id: modeID), name != stored.name else { return }
        var copy = stored
        copy.name = name
        if !model.updateMode(copy) { name = stored.name }
    }
}
