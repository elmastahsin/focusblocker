import Foundation

public enum Identifiers {
    public static let logSubsystem = "app.focusblocker"
    public static let appBundleID = "app.focusblocker.app"
    /// Launchd label, mach service name and code-signing identifier of the daemon.
    public static let daemonLabel = "app.focusblocker.daemon"
    public static let daemonPlistName = "app.focusblocker.daemon.plist"
    public static let supportDirectory = "/Library/Application Support/FocusBlocker"
}
