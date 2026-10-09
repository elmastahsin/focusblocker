import Combine
import Foundation
import ServiceManagement
import FocusCore
import os

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var isActive = false
    @Published private(set) var endDate: Date?
    @Published private(set) var now = Date()
    @Published private(set) var registration: SMAppService.Status
    @Published private(set) var activeModeID: UUID?
    @Published private(set) var activeStartDate: Date?
    @Published var errorMessage: String?
    @Published var duration: BlockDuration = .hour1
    @Published var customMinutes = 90

    let modes: ModeStore

    private let daemon: DaemonControlling
    private let registrar: DaemonRegistrar
    private let defaults: UserDefaults
    private let log = Logger(subsystem: Identifiers.logSubsystem, category: "app")
    private var modesObserver: AnyCancellable?
    private var tickCount = 0

    private enum Key {
        static let activeMode = "activeModeID"
        static let activeStart = "activeStartDate"
    }

    init(modes: ModeStore? = nil,
         daemon: DaemonControlling = DaemonClient(),
         registrar: DaemonRegistrar = DaemonRegistrar(),
         defaults: UserDefaults = .standard) {
        let modes = modes ?? ModeStore()
        self.modes = modes
        self.daemon = daemon
        self.registrar = registrar
        self.defaults = defaults
        self.registration = registrar.status
        self.activeModeID = defaults.string(forKey: Key.activeMode).flatMap(UUID.init(uuidString:))
        self.activeStartDate = defaults.object(forKey: Key.activeStart) as? Date
        modesObserver = modes.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }
        bootstrap()
    }

    var remaining: TimeInterval { max(0, (endDate ?? now).timeIntervalSince(now)) }

    /// 1 → 0 over the block. Nil when the start time is unknown (e.g. state lost after reinstall).
    var progress: Double? {
        guard isActive, let end = endDate, let start = activeStartDate, end > start else { return nil }
        return min(1, max(0, remaining / end.timeIntervalSince(start)))
    }

    /// The mode whose block is running. Nil when idle, or after a relaunch that lost track of it.
    var activeMode: FocusMode? {
        guard isActive, let id = activeModeID else { return nil }
        return modes.library.mode(id: id)
    }

    /// Shown in the UI: the running mode while active, otherwise the selected one.
    var displayedMode: FocusMode { activeMode ?? modes.selectedMode }

    var canStart: Bool {
        registration == .enabled && !isActive && !modes.selectedMode.isEmpty
    }

    // MARK: - Modes (all editing is locked while a block is active)

    func selectMode(_ id: UUID) {
        guard !isActive else { return }
        modes.select(id)
        errorMessage = nil
    }

    @discardableResult
    func updateMode(_ mode: FocusMode) -> Bool {
        perform { try modes.update(mode) }
    }

    func createMode() -> UUID? {
        var name = "Yeni Mod"
        var number = 2
        while modes.library.modes.contains(where: { $0.name == name }) {
            name = "Yeni Mod \(number)"
            number += 1
        }
        let mode = FocusMode(name: name, symbol: "star.fill", color: .teal)
        return perform({ try modes.add(mode) }) ? mode.id : nil
    }

    func duplicateMode(id: UUID) -> UUID? {
        var copyID: UUID?
        let ok = perform { copyID = try modes.duplicate(id: id).id }
        return ok ? copyID : nil
    }

    @discardableResult
    func deleteMode(id: UUID) -> Bool {
        perform { try modes.delete(id: id) }
    }

    private func perform(_ work: () throws -> Void) -> Bool {
        guard !isActive else { return false }
        do {
            try work()
            errorMessage = nil
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    // MARK: - Block

    func startBlock() async {
        guard canStart else { return }
        let mode = modes.selectedMode
        let start = Date()
        let end = start.addingTimeInterval(duration.seconds(customMinutes: customMinutes))
        do {
            try await daemon.start(sites: mode.sites, appBundleIDs: mode.apps.map(\.bundleID), endDate: end)
            setActive(modeID: mode.id, startedAt: start)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
        await refreshStatus()
    }

    func registerDaemon() {
        do {
            try registrar.register()
            errorMessage = nil
        } catch {
            errorMessage = "Daemon kaydı başarısız: \(error.localizedDescription)"
        }
        registration = registrar.status
        if registration == .requiresApproval { registrar.openSystemSettings() }
    }

    func openSystemSettings() {
        registrar.openSystemSettings()
    }

    // MARK: - Polling

    private func bootstrap() {
        // A daemon that was never registered can report .notFound instead of .notRegistered.
        if registration == .notRegistered || registration == .notFound { registerDaemon() }
        else if registration == .requiresApproval { registrar.openSystemSettings() }

        Task { [weak self] in
            await self?.refreshStatus()
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                await self?.tick()
            }
        }
    }

    private func tick() async {
        now = Date()
        registration = registrar.status
        tickCount += 1
        let overdue = endDate.map { now >= $0 } ?? false
        if tickCount % 5 == 0 || overdue { await refreshStatus() }
    }

    private func refreshStatus() async {
        guard registration == .enabled else { return }
        do {
            let status = try await daemon.status()
            isActive = status.isActive
            endDate = status.endDate
            now = Date()
            if !status.isActive {
                setActive(modeID: nil, startedAt: nil)
            } else if activeStartDate == nil {
                // Block began before we tracked it: count the ring from the first moment we saw it.
                setActive(modeID: activeModeID, startedAt: now)
            }
        } catch {
            log.error("status poll failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func setActive(modeID: UUID?, startedAt: Date?) {
        activeModeID = modeID
        activeStartDate = startedAt
        defaults.set(modeID?.uuidString, forKey: Key.activeMode)
        defaults.set(startedAt, forKey: Key.activeStart)
    }
}
