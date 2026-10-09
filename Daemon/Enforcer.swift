import Foundation
import FocusCore
import os

/// Single owner of the block state. All access is serialized on one queue.
/// Exposes start / extend / status only. There is intentionally no stop or cancel.
final class Enforcer {
    static let interval: DispatchTimeInterval = .seconds(5)

    private let queue = DispatchQueue(label: "app.focusblocker.enforcer")
    private let log = Logger(subsystem: Identifiers.logSubsystem, category: "enforcer")
    private let store: StateStore
    private let hosts: HostsFileWriter
    private let dns: DNSFlusher
    private let apps: AppTerminator
    private let wallClock: () -> Date
    private let monotonicClock: () -> TimeInterval

    private var state: BlockState?
    private var lastMonotonic: TimeInterval
    private var timer: DispatchSourceTimer?

    init(store: StateStore = StateStore(),
         hosts: HostsFileWriter = HostsFileWriter(),
         dns: DNSFlusher = DNSFlusher(),
         apps: AppTerminator = AppTerminator(),
         wallClock: @escaping () -> Date = { Date() },
         monotonicClock: @escaping () -> TimeInterval = MonotonicClock.now) {
        self.store = store
        self.hosts = hosts
        self.dns = dns
        self.apps = apps
        self.wallClock = wallClock
        self.monotonicClock = monotonicClock
        self.lastMonotonic = monotonicClock()
    }

    /// Loads persisted state, resumes the block if it is still running, and starts the 5 s loop.
    func start() {
        queue.sync { loadState() }

        let source = DispatchSource.makeTimerSource(queue: queue)
        source.schedule(deadline: .now(), repeating: Self.interval, leeway: .milliseconds(500))
        source.setEventHandler { [weak self] in self?.tick() }
        source.resume()
        timer = source
    }

    func startBlock(sites: [String], appBundleIDs: [String], endDate: Date) throws {
        try queue.sync {
            guard state == nil else { throw BlockError.alreadyActive }
            let new = try BlockState.make(sites: sites, appBundleIDs: appBundleIDs,
                                          endDate: endDate, now: wallClock())
            try store.save(new)
            state = new
            lastMonotonic = monotonicClock()
            enforceHosts(new)
            enforceApps(new)
            log.notice("block started: \(new.sites.count) sites, \(new.appBundleIDs.count) apps, until \(new.endDate.timeIntervalSince1970)")
        }
    }

    func extend(to newEnd: Date) throws {
        try queue.sync {
            guard let current = state else { throw BlockError.notActive }
            let extended = try BlockClock.extended(current, to: newEnd, now: wallClock())
            try store.save(extended)
            state = extended
            log.notice("block extended until \(extended.endDate.timeIntervalSince1970)")
        }
    }

    func status() -> (isActive: Bool, endDate: Date?) {
        queue.sync {
            guard let current = state else { return (false, nil) }
            return (true, BlockClock.effectiveEnd(of: current, now: wallClock()))
        }
    }

    // MARK: - Queue-confined

    private func loadState() {
        do {
            if let loaded = try store.load() {
                state = loaded
                log.notice("resumed block from disk, \(loaded.sites.count) sites")
            } else {
                clearStaleBlock()
            }
        } catch {
            // Unreadable state: do not touch hosts, a block may still be in place.
            log.error("state unreadable, hosts left untouched: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func clearStaleBlock() {
        do {
            if try hosts.clear() {
                log.notice("removed stale hosts block (no active state)")
                dns.flush()
            }
        } catch {
            log.error("stale hosts cleanup failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func tick() {
        guard var current = state else { return }

        let monotonic = monotonicClock()
        current = BlockClock.ticked(current, monotonicDelta: monotonic - lastMonotonic)
        lastMonotonic = monotonic
        state = current

        if BlockClock.isExpired(current, now: wallClock()) {
            finish()
            return
        }

        do {
            try store.save(current)
        } catch {
            log.error("state save failed: \(error.localizedDescription, privacy: .public)")
        }
        enforceHosts(current)
        enforceApps(current)
    }

    private func enforceHosts(_ current: BlockState) {
        do {
            if try hosts.sync(sites: current.sites) {
                log.notice("hosts block rewritten")
                dns.flush()
            }
        } catch {
            log.error("hosts sync failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func enforceApps(_ current: BlockState) {
        guard !current.appBundleIDs.isEmpty else { return }
        apps.enforce(bundleIDs: current.appBundleIDs)
    }

    private func finish() {
        do {
            if try hosts.clear() { dns.flush() }
            try store.clear()
            state = nil
            log.notice("block finished, hosts cleaned, state reset")
        } catch {
            // state stays in memory and on disk: next tick retries.
            log.error("cleanup failed, will retry: \(error.localizedDescription, privacy: .public)")
        }
    }
}
