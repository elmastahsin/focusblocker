import Foundation
import FocusCore
import os

let log = Logger(subsystem: Identifiers.logSubsystem, category: "daemon")

// Enforcement must run even if XPC cannot be set up.
let enforcer = Enforcer()
enforcer.start()

let listener = NSXPCListener(machServiceName: Identifiers.daemonLabel)
let delegate = ListenerDelegate(service: DaemonService(enforcer: enforcer))
listener.delegate = delegate

if let teamID = CodeSigningRequirement.ownTeamID(),
   let requirement = CodeSigningRequirement.app(teamID: teamID) {
    // Connections that do not satisfy the requirement are rejected by the system before our delegate runs.
    listener.setConnectionCodeSigningRequirement(requirement)
    listener.resume()
    log.notice("daemon up, XPC listening for team \(teamID, privacy: .public)")
} else {
    // Fail closed: no signed identity means no client can be verified, so serve nobody.
    log.fault("daemon is not signed with a Team ID, XPC disabled; enforcement of existing state continues")
}

dispatchMain()
