import Foundation
import Security

public enum CodeSigningRequirement {
    /// Requirement the daemon enforces on XPC clients: our app, same team.
    public static func app(teamID: String) -> String? {
        requirement(identifier: Identifiers.appBundleID, teamID: teamID)
    }

    /// Requirement the app enforces on the daemon it connects to.
    public static func daemon(teamID: String) -> String? {
        requirement(identifier: Identifiers.daemonLabel, teamID: teamID)
    }

    static func requirement(identifier: String, teamID: String) -> String? {
        guard isValidTeamID(teamID) else { return nil }
        return "anchor apple generic and identifier \"\(identifier)\" and certificate leaf[subject.OU] = \"\(teamID)\""
    }

    static func isValidTeamID(_ teamID: String) -> Bool {
        teamID.utf8.count == 10 && teamID.utf8.allSatisfy { ($0 >= 0x41 && $0 <= 0x5A) || ($0 >= 0x30 && $0 <= 0x39) }
    }

    /// Team ID read from the running process's own signature. Nil when unsigned / ad-hoc signed.
    /// Used so the team ID is configured in one place only (the signing settings).
    public static func ownTeamID() -> String? {
        var code: SecCode?
        guard SecCodeCopySelf([], &code) == errSecSuccess, let code else { return nil }
        var staticCode: SecStaticCode?
        guard SecCodeCopyStaticCode(code, [], &staticCode) == errSecSuccess, let staticCode else { return nil }
        var info: CFDictionary?
        let flags = SecCSFlags(rawValue: UInt32(kSecCSSigningInformation))
        guard SecCodeCopySigningInformation(staticCode, flags, &info) == errSecSuccess,
              let dict = info as? [String: Any] else { return nil }
        return dict[kSecCodeInfoTeamIdentifier as String] as? String
    }
}
