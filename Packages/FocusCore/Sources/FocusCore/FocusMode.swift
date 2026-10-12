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
    /// Sites kept in the mode but switched off: not blocked when the mode starts.
    public var disabledSites: Set<String>
    /// Bundle IDs kept in the mode but switched off.
    public var disabledAppIDs: Set<String>

    public init(id: UUID = UUID(),
                name: String,
                symbol: String,
                color: ModeColor,
                sites: [String] = [],
                apps: [BlockedApp] = [],
                disabledSites: Set<String> = [],
                disabledAppIDs: Set<String> = []) {
        self.id = id
        self.name = name
        self.symbol = symbol
        self.color = color
        self.sites = sites
        self.apps = apps
        self.disabledSites = disabledSites
        self.disabledAppIDs = disabledAppIDs
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, symbol, color, sites, apps, disabledSites, disabledAppIDs
    }

    /// Modes saved before the on/off switches have no disabled sets: everything is on.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        symbol = try container.decode(String.self, forKey: .symbol)
        color = try container.decode(ModeColor.self, forKey: .color)
        sites = try container.decode([String].self, forKey: .sites)
        apps = try container.decode([BlockedApp].self, forKey: .apps)
        disabledSites = try container.decodeIfPresent(Set<String>.self, forKey: .disabledSites) ?? []
        disabledAppIDs = try container.decodeIfPresent(Set<String>.self, forKey: .disabledAppIDs) ?? []
    }

    /// Sites that are switched on, in list order.
    public var enabledSites: [String] { sites.filter { !disabledSites.contains($0) } }

    /// Bundle IDs of apps that are switched on, in list order.
    public var enabledAppIDs: [String] { apps.map(\.bundleID).filter { !disabledAppIDs.contains($0) } }

    /// A mode with nothing switched on to block cannot be started.
    public var isEmpty: Bool { enabledSites.isEmpty && enabledAppIDs.isEmpty }

    public func isSiteEnabled(_ site: String) -> Bool { !disabledSites.contains(site) }

    public func isAppEnabled(bundleID: String) -> Bool { !disabledAppIDs.contains(bundleID) }

    /// Ignored for sites that are not in the mode.
    public mutating func setSite(_ site: String, enabled: Bool) {
        guard sites.contains(site) else { return }
        if enabled { disabledSites.remove(site) } else { disabledSites.insert(site) }
    }

    /// Ignored for apps that are not in the mode.
    public mutating func setApp(bundleID: String, enabled: Bool) {
        guard apps.contains(where: { $0.bundleID == bundleID }) else { return }
        if enabled { disabledAppIDs.remove(bundleID) } else { disabledAppIDs.insert(bundleID) }
    }

    /// Returns false when `raw` is not a valid domain. Duplicates are ignored but count as success.
    @discardableResult
    public mutating func addSite(_ raw: String) -> Bool {
        guard let domain = DomainNormalizer.normalize(raw) else { return false }
        if !sites.contains(domain) { sites.append(domain) }
        return true
    }

    public mutating func removeSite(_ site: String) {
        sites.removeAll { $0 == site }
        disabledSites.remove(site)
    }

    public mutating func addApp(_ app: BlockedApp) {
        guard BundleIDValidator.isValid(app.bundleID),
              !apps.contains(where: { $0.bundleID == app.bundleID }) else { return }
        apps.append(app)
    }

    public mutating func removeApp(bundleID: String) {
        apps.removeAll { $0.bundleID == bundleID }
        disabledAppIDs.remove(bundleID)
    }
}
