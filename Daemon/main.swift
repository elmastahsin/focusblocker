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

// An app update replaces the bundle, but launchd keeps running the old binary. Exit once the file
// on disk changes: KeepAlive relaunches the new one and the Enforcer resumes the block from disk.
let executablePath = Bundle.main.executablePath ?? CommandLine.arguments[0]
func executableFileNumber() -> Int? {
    try? FileManager.default.attributesOfItem(atPath: executablePath)[.systemFileNumber] as? Int
}
let launchedFileNumber = executableFileNumber()
let updateWatcher = DispatchSource.makeTimerSource(queue: .global(qos: .utility))
updateWatcher.schedule(deadline: .now() + 30, repeating: 30)
updateWatcher.setEventHandler {
    // Missing file: Sparkle is mid-swap, check again next time.
    guard let launchedFileNumber, let current = executableFileNumber(), current != launchedFileNumber else { return }
    log.notice("daemon binary replaced on disk, exiting for relaunch")
    enforcer.exitBetweenTicks()
}
updateWatcher.resume()

dispatchMain()
