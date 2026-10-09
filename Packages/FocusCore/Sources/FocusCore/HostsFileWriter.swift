import Foundation

/// Applies / removes the FOCUSBLOCKER block in a hosts file.
/// Every write: backup of the user's content (without our block) first, then atomic replace.
public struct HostsFileWriter {
    public let hostsURL: URL
    public let backupURL: URL

    public init(hostsURL: URL = URL(fileURLWithPath: "/etc/hosts"),
                backupURL: URL = URL(fileURLWithPath: Identifiers.supportDirectory, isDirectory: true)
                    .appendingPathComponent("hosts.bak")) {
        self.hostsURL = hostsURL
        self.backupURL = backupURL
    }

    /// Ensures the file contains exactly the block for `sites`. Returns true if the file changed.
    @discardableResult
    public func sync(sites: [String]) throws -> Bool {
        try rewrite { HostsBlockRenderer.apply(to: $0, sites: sites) }
    }

    /// Removes the block. Returns true if the file changed.
    @discardableResult
    public func clear() throws -> Bool {
        try rewrite { HostsBlockRenderer.remove(from: $0) }
    }

    private func rewrite(_ transform: (String) -> String) throws -> Bool {
        let current = try read()
        let updated = transform(current)
        guard updated != current else { return false }

        try writeBackup(HostsBlockRenderer.remove(from: current))
        let (mode, owner) = existingAttributes()
        try AtomicFile.write(Data(updated.utf8), to: hostsURL, mode: mode, owner: owner)
        return true
    }

    private func read() throws -> String {
        guard FileManager.default.fileExists(atPath: hostsURL.path) else { return "" }
        return try String(contentsOf: hostsURL, encoding: .utf8)
    }

    private func writeBackup(_ content: String) throws {
        try FileManager.default.createDirectory(at: backupURL.deletingLastPathComponent(),
                                                withIntermediateDirectories: true,
                                                attributes: [.posixPermissions: 0o700])
        try AtomicFile.write(Data(content.utf8), to: backupURL, mode: 0o600)
    }

    private func existingAttributes() -> (mode: mode_t, owner: (uid: uid_t, gid: gid_t)?) {
        let path = hostsURL.resolvingSymlinksInPath().path
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: path) else { return (0o644, nil) }
        let mode = (attrs[.posixPermissions] as? NSNumber)?.uint16Value ?? 0o644
        guard let uid = (attrs[.ownerAccountID] as? NSNumber)?.uint32Value,
              let gid = (attrs[.groupOwnerAccountID] as? NSNumber)?.uint32Value else { return (mode, nil) }
        return (mode, (uid, gid))
    }
}
