import Foundation

public enum BlockError: Error, Equatable {
    case alreadyActive
    case notActive
    case invalidEndDate
    case nothingToBlock
    case invalidSite(String)
    case invalidBundleID(String)
    case extendNotLater
}

public struct BlockState: Codable, Equatable, Sendable {
    public static let currentVersion = 1

    public var version: Int
    public var sites: [String]
    public var appBundleIDs: [String]
    /// Wall-clock end. Can be defeated by moving the system clock.
    public var endDate: Date
    /// Seconds left according to the monotonic clock. Decremented by the enforcer every tick.
    public var remainingMonotonic: TimeInterval

    public init(version: Int = BlockState.currentVersion,
                sites: [String],
                appBundleIDs: [String],
                endDate: Date,
                remainingMonotonic: TimeInterval) {
        self.version = version
        self.sites = sites
        self.appBundleIDs = appBundleIDs
        self.endDate = endDate
        self.remainingMonotonic = remainingMonotonic
    }

    /// Validates raw XPC input and builds a fresh state. Rejects the whole request on any bad item.
    public static func make(sites: [String],
                            appBundleIDs: [String],
                            endDate: Date,
                            now: Date) throws -> BlockState {
        guard endDate > now else { throw BlockError.invalidEndDate }

        var cleanSites: [String] = []
        for raw in sites {
            guard let domain = DomainNormalizer.normalize(raw) else { throw BlockError.invalidSite(raw) }
            if !cleanSites.contains(domain) { cleanSites.append(domain) }
        }

        var cleanIDs: [String] = []
        for raw in appBundleIDs {
            guard BundleIDValidator.isValid(raw) else { throw BlockError.invalidBundleID(raw) }
            if !cleanIDs.contains(raw) { cleanIDs.append(raw) }
        }

        guard !cleanSites.isEmpty || !cleanIDs.isEmpty else { throw BlockError.nothingToBlock }

        return BlockState(sites: cleanSites,
                          appBundleIDs: cleanIDs,
                          endDate: endDate,
                          remainingMonotonic: endDate.timeIntervalSince(now))
    }
}
