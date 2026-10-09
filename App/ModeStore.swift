import Foundation
import FocusCore

/// Persists the user's modes (UserDefaults JSON) and which one is selected.
/// First launch with the old single-list keys migrates them into the starter modes.
@MainActor
final class ModeStore: ObservableObject {
    @Published private(set) var library: ModeLibrary
    @Published private(set) var selectedModeID: UUID

    private let defaults: UserDefaults
    private enum Key {
        static let library = "modeLibrary.v1"
        static let selected = "selectedModeID"
        static let legacySites = "blockedSites"
        static let legacyApps = "blockedApps"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let loaded = Self.loadLibrary(from: defaults)
        library = loaded
        let savedID = defaults.string(forKey: Key.selected).flatMap(UUID.init(uuidString:))
        selectedModeID = savedID.flatMap { loaded.mode(id: $0) }?.id ?? loaded.modes[0].id
        save()
    }

    var selectedMode: FocusMode {
        library.mode(id: selectedModeID) ?? library.modes[0]
    }

    func select(_ id: UUID) {
        guard library.mode(id: id) != nil else { return }
        selectedModeID = id
        save()
    }

    func add(_ mode: FocusMode) throws {
        try library.add(mode)
        save()
    }

    func update(_ mode: FocusMode) throws {
        try library.update(mode)
        save()
    }

    func delete(id: UUID) throws {
        try library.delete(id: id)
        if selectedModeID == id { selectedModeID = library.modes[0].id }
        save()
    }

    @discardableResult
    func duplicate(id: UUID) throws -> FocusMode {
        let copy = try library.duplicate(id: id)
        save()
        return copy
    }

    // MARK: - Persistence

    private static func loadLibrary(from defaults: UserDefaults) -> ModeLibrary {
        if let data = defaults.data(forKey: Key.library),
           let saved = try? JSONDecoder().decode(ModeLibrary.self, from: data),
           !saved.modes.isEmpty {
            return saved
        }
        let sites = defaults.stringArray(forKey: Key.legacySites) ?? []
        let apps = defaults.data(forKey: Key.legacyApps)
            .flatMap { try? JSONDecoder().decode([BlockedApp].self, from: $0) } ?? []
        return ModeLibrary.migrating(legacySites: sites, legacyApps: apps)
    }

    private func save() {
        defaults.set(try? JSONEncoder().encode(library), forKey: Key.library)
        defaults.set(selectedModeID.uuidString, forKey: Key.selected)
    }
}

extension BlockedApp {
    /// Reads name and bundle ID from an .app bundle. Nil when it has no valid bundle ID.
    static func load(from url: URL) -> BlockedApp? {
        guard let bundle = Bundle(url: url),
              let id = bundle.bundleIdentifier,
              BundleIDValidator.isValid(id) else { return nil }
        let name = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
            ?? url.deletingPathExtension().lastPathComponent
        return BlockedApp(bundleID: id, name: name)
    }
}
