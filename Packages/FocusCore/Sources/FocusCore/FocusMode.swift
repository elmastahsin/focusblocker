import Foundation

public struct BlockedApp: Codable, Hashable, Identifiable, Sendable {
    public var bundleID: String
    public var name: String
    public var id: String { bundleID }

    public init(bundleID: String, name: String) {
        self.bundleID = bundleID
        self.name = name
    }
}

public enum ModeColor: String, Codable, CaseIterable, Sendable {
    case blue, purple, pink, red, orange, yellow, green, teal, gray
}

/// A named set of sites and apps, like an Apple Focus mode.
public struct FocusMode: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    /// SF Symbol name.
    public var symbol: String
    public var color: ModeColor
    public var sites: [String]
    public var apps: [BlockedApp]

    public init(id: UUID = UUID(),
                name: String,
                symbol: String,
                color: ModeColor,
                sites: [String] = [],
                apps: [BlockedApp] = []) {
        self.id = id
        self.name = name
        self.symbol = symbol
        self.color = color
        self.sites = sites
        self.apps = apps
    }

    /// A mode with nothing to block cannot be started.
    public var isEmpty: Bool { sites.isEmpty && apps.isEmpty }

    /// Returns false when `raw` is not a valid domain. Duplicates are ignored but count as success.
    @discardableResult
    public mutating func addSite(_ raw: String) -> Bool {
        guard let domain = DomainNormalizer.normalize(raw) else { return false }
        if !sites.contains(domain) { sites.append(domain) }
        return true
    }

    public mutating func removeSite(_ site: String) {
        sites.removeAll { $0 == site }
    }

    public mutating func addApp(_ app: BlockedApp) {
        guard BundleIDValidator.isValid(app.bundleID),
              !apps.contains(where: { $0.bundleID == app.bundleID }) else { return }
        apps.append(app)
    }

    public mutating func removeApp(bundleID: String) {
        apps.removeAll { $0.bundleID == bundleID }
    }
}
