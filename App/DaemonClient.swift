import Foundation
import FocusCore

protocol DaemonControlling {
    func start(sites: [String], appBundleIDs: [String], endDate: Date) async throws
    func extend(to endDate: Date) async throws
    func status() async throws -> (isActive: Bool, endDate: Date?)
}

enum DaemonClientError: LocalizedError {
    case unsignedApp
    case unavailable
    case rejected(String)

    var errorDescription: String? {
        switch self {
        case .unsignedApp: return "Uygulama bir Team ID ile imzalı değil, daemon'a bağlanılamaz."
        case .unavailable: return "Daemon'a ulaşılamadı."
        case .rejected(let message): return message
        }
    }
}

/// XPC client. Verifies the daemon's code signature before talking to it.
final class DaemonClient: DaemonControlling {
    private let lock = NSLock()
    private var connection: NSXPCConnection?

    func start(sites: [String], appBundleIDs: [String], endDate: Date) async throws {
        let error: String? = try await call { proxy, shot in
            proxy.start(sites: sites, appBundleIDs: appBundleIDs, endDate: endDate) { shot.resume(.success($0)) }
        }
        if let error { throw DaemonClientError.rejected(error) }
    }

    func extend(to endDate: Date) async throws {
        let error: String? = try await call { proxy, shot in
            proxy.extend(endDate: endDate) { shot.resume(.success($0)) }
        }
        if let error { throw DaemonClientError.rejected(error) }
    }

    func status() async throws -> (isActive: Bool, endDate: Date?) {
        let result: (Bool, Date?) = try await call { proxy, shot in
            proxy.status { isActive, endDate in shot.resume(.success((isActive, endDate))) }
        }
        return (result.0, result.1)
    }

    // MARK: - Connection

    private func activeConnection() throws -> NSXPCConnection {
        lock.lock()
        defer { lock.unlock() }
        if let connection { return connection }

        guard let teamID = CodeSigningRequirement.ownTeamID(),
              let requirement = CodeSigningRequirement.daemon(teamID: teamID) else {
            throw DaemonClientError.unsignedApp
        }
        let new = NSXPCConnection(machServiceName: Identifiers.daemonLabel, options: .privileged)
        new.remoteObjectInterface = NSXPCInterface(with: FocusBlockerDaemonProtocol.self)
        new.setCodeSigningRequirement(requirement)
        new.invalidationHandler = { [weak self] in self?.dropConnection() }
        new.resume()
        connection = new
        return new
    }

    private func dropConnection() {
        lock.lock()
        connection = nil
        lock.unlock()
    }

    private func call<T>(_ invoke: @escaping (FocusBlockerDaemonProtocol, OneShot<T>) -> Void) async throws -> T {
        let connection = try activeConnection()
        return try await withCheckedThrowingContinuation { continuation in
            let shot = OneShot(continuation)
            let proxy = connection.remoteObjectProxyWithErrorHandler { shot.resume(.failure($0)) }
            guard let daemon = proxy as? FocusBlockerDaemonProtocol else {
                shot.resume(.failure(DaemonClientError.unavailable))
                return
            }
            invoke(daemon, shot)
        }
    }
}

/// Resumes a continuation at most once: XPC may fire both the reply and the error handler.
final class OneShot<T> {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<T, Error>?

    init(_ continuation: CheckedContinuation<T, Error>) {
        self.continuation = continuation
    }

    func resume(_ result: Result<T, Error>) {
        lock.lock()
        let pending = continuation
        continuation = nil
        lock.unlock()
        pending?.resume(with: result)
    }
}
