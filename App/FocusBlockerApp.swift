import SwiftUI

@main
struct FocusBlockerApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        MenuBarExtra {
            MenuContentView()
                .environmentObject(model)
        } label: {
            if model.isActive {
                Image(systemName: "lock.fill")
                Text(model.remaining.shortClockString).monospacedDigit()
            } else {
                Image(systemName: "lock.open")
            }
        }
        .menuBarExtraStyle(.window)
    }
}
