import Foundation
import FocusCore
import os

struct DNSFlusher {
    private let log = Logger(subsystem: Identifiers.logSubsystem, category: "dns")

    func flush() {
        run("/usr/bin/dscacheutil", ["-flushcache"])
        run("/usr/bin/killall", ["-HUP", "mDNSResponder"])
    }

    private func run(_ path: String, _ arguments: [String]) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
            if process.terminationStatus != 0 {
                log.error("\(path, privacy: .public) exited with status \(process.terminationStatus)")
            }
        } catch {
            log.error("\(path, privacy: .public) failed to launch: \(error.localizedDescription, privacy: .public)")
        }
    }
}
