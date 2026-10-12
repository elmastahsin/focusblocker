import AppKit
import Sparkle
import SwiftUI

@main
struct FocusBlockerApp: App {
    @StateObject private var model = AppModel()
    @StateObject private var updater = Updater()

    var body: some Scene {
        MenuBarExtra {
            MenuContentView()
                .environmentObject(model)
                .environmentObject(updater)
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

/// Sparkle updates. The feed URL and public key live in App/Resources/Info.plist.
@MainActor
final class Updater: ObservableObject {
    private let controller = SPUStandardUpdaterController(startingUpdater: true,
                                                          updaterDelegate: nil,
                                                          userDriverDelegate: nil)

    func checkForUpdates() {
        // Menu bar app: bring Sparkle's window to the front.
        NSApp.activate(ignoringOtherApps: true)
        controller.checkForUpdates(nil)
    }
}
