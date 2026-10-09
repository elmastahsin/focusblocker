import Foundation

/// Persists `BlockState` as JSON. Root-owned, mode 0600, written atomically.
public struct StateStore {
    public let directory: URL

    public var fileURL: URL { directory.appendingPathComponent("state.json") }

    public init(directory: URL = URL(fileURLWithPath: Identifiers.supportDirectory, isDirectory: true)) {
        self.directory = directory
    }

    /// Returns nil when no state file exists. Throws when the file exists but cannot be decoded.
    public func load() throws -> BlockState? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        let data = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return try decoder.decode(BlockState.self, from: data)
    }

    public func save(_ state: BlockState) throws {
        try FileManager.default.createDirectory(at: directory,
                                                withIntermediateDirectories: true,
                                                attributes: [.posixPermissions: 0o700])
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        encoder.outputFormatting = [.sortedKeys]
        try AtomicFile.write(try encoder.encode(state), to: fileURL, mode: 0o600)
    }

    public func clear() throws {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        try FileManager.default.removeItem(at: fileURL)
    }
}
