import Darwin
import Foundation
import FocusCore
import os

/// Kills processes that belong to blocked app bundles. SIGTERM first, SIGKILL if still alive on the next pass.
final class AppTerminator {
    private let log = Logger(subsystem: Identifiers.logSubsystem, category: "apps")
    /// Bundle path to bundle ID; nil when the bundle has no readable identifier.
    private var bundleIDCache: [String: String?] = [:]
    private var signaled: Set<pid_t> = []

    func enforce(bundleIDs: [String]) {
        let blocked = Set(bundleIDs).subtracting(AppBundleMatcher.protectedBundleIDs)
        guard !blocked.isEmpty else {
            signaled.removeAll()
            return
        }

        var stillSignaled: Set<pid_t> = []
        for pid in runningPIDs() where pid > 1 && pid != getpid() {
            guard let path = executablePath(of: pid) else { continue }
            let ids = AppBundleMatcher.enclosingBundlePaths(forExecutable: path).compactMap(bundleID(atPath:))
            guard let match = ids.first(where: blocked.contains) else { continue }

            if signaled.contains(pid) {
                kill(pid, SIGKILL)
                log.notice("SIGKILL \(match, privacy: .public) pid \(pid)")
            } else {
                kill(pid, SIGTERM)
                log.notice("SIGTERM \(match, privacy: .public) pid \(pid)")
            }
            stillSignaled.insert(pid)
        }
        signaled = stillSignaled
    }

    private func runningPIDs() -> [pid_t] {
        let count = proc_listallpids(nil, 0)
        guard count > 0 else { return [] }
        var pids = [pid_t](repeating: 0, count: Int(count) + 64)
        let filled = proc_listallpids(&pids, Int32(pids.count * MemoryLayout<pid_t>.size))
        guard filled > 0 else { return [] }
        return Array(pids.prefix(Int(filled)))
    }

    private func executablePath(of pid: pid_t) -> String? {
        var buffer = [CChar](repeating: 0, count: 4 * Int(MAXPATHLEN))
        guard proc_pidpath(pid, &buffer, UInt32(buffer.count)) > 0 else { return nil }
        return String(cString: buffer)
    }

    private func bundleID(atPath path: String) -> String? {
        if let cached = bundleIDCache[path] { return cached }
        let id = Bundle(path: path)?.bundleIdentifier
        bundleIDCache[path] = id
        return id
    }
}
