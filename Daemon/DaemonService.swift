import Foundation
import FocusCore
import os

/// XPC entry point. Thin: validation and rules live in FocusCore / Enforcer.
final class DaemonService: NSObject, FocusBlockerDaemonProtocol {
    private let enforcer: Enforcer
    private let log = Logger(subsystem: Identifiers.logSubsystem, category: "xpc")

    init(enforcer: Enforcer) {
        self.enforcer = enforcer
    }

    func start(sites: [String], appBundleIDs: [String], endDate: Date, reply: @escaping (String?) -> Void) {
        reply(run("start") { try enforcer.startBlock(sites: sites, appBundleIDs: appBundleIDs, endDate: endDate) })
    }

    func extend(endDate: Date, reply: @escaping (String?) -> Void) {
        reply(run("extend") { try enforcer.extend(to: endDate) })
    }

    func status(reply: @escaping (Bool, Date?) -> Void) {
        let status = enforcer.status()
        reply(status.isActive, status.endDate)
    }

    private func run(_ command: String, _ work: () throws -> Void) -> String? {
        do {
            try work()
            log.notice("\(command, privacy: .public) accepted")
            return nil
        } catch {
            log.error("\(command, privacy: .public) rejected: \(error.localizedDescription, privacy: .public)")
            return error.localizedDescription
        }
    }
}

final class ListenerDelegate: NSObject, NSXPCListenerDelegate {
    private let service: DaemonService

    init(service: DaemonService) {
        self.service = service
    }

    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        connection.exportedInterface = NSXPCInterface(with: FocusBlockerDaemonProtocol.self)
        connection.exportedObject = service
        connection.resume()
        return true
    }
}
