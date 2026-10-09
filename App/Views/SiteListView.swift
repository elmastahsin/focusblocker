import SwiftUI
import FocusCore

/// Site editor for one mode. Used in the Modlar window.
struct SiteListView: View {
    @Binding var mode: FocusMode
    let isLocked: Bool
    @State private var input = ""
    @State private var inputError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Siteler", count: mode.sites.count)

            ForEach(mode.sites, id: \.self) { site in
                HStack(spacing: 10) {
                    SiteIcon(domain: site)
                    Text(site)
                    Spacer()
                    Button { remove(site) } label: {
                        Image(systemName: "minus.circle.fill").foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless)
                    .disabled(isLocked)
                }
            }

            HStack {
                TextField("ornek.com", text: $input)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(add)
                Button("Ekle", action: add)
                    .disabled(isLocked || input.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            if let inputError {
                Text(inputError).font(.caption).foregroundStyle(.red)
            }
        }
    }

    private func add() {
        guard !isLocked else { return }
        var copy = mode
        if copy.addSite(input) {
            mode = copy
            input = ""
            inputError = nil
        } else {
            inputError = "Geçersiz site: \(input)"
        }
    }

    private func remove(_ site: String) {
        var copy = mode
        copy.removeSite(site)
        mode = copy
    }
}
