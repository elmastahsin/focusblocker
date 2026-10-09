import SwiftUI

@main
struct FocusBlockerApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        MenuBarExtra {
            MenuContentView()
                .environmentObject(model)
        } label: {
            Image(systemName: model.isActive ? "lock.fill" : "lock.open")
        }
        .menuBarExtraStyle(.window)
    }
}
