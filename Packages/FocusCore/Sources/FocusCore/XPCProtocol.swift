import Foundation

/// The complete daemon surface. There is deliberately no stop / cancel / shorten call.
/// `reply` error strings are nil on success.
@objc public protocol FocusBlockerDaemonProtocol {
    func start(sites: [String], appBundleIDs: [String], endDate: Date, reply: @escaping (String?) -> Void)
    /// Accepted only if `endDate` is later than the current effective end.
    func extend(endDate: Date, reply: @escaping (String?) -> Void)
    func status(reply: @escaping (Bool, Date?) -> Void)
}

extension BlockError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .alreadyActive: return "A block is already active."
        case .notActive: return "No block is active."
        case .invalidEndDate: return "End date must be in the future."
        case .nothingToBlock: return "Add at least one site or app."
        case .invalidSite(let s): return "Invalid site: \(s)"
        case .invalidBundleID(let id): return "Invalid bundle ID: \(id)"
        case .extendNotLater: return "New end date must be later than the current one."
        }
    }
}
