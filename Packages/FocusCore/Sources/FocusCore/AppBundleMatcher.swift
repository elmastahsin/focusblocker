import Foundation

/// Maps running executables to the app bundles that contain them.
public enum AppBundleMatcher {
    /// Bundles that are never terminated, even if a block lists them.
    public static let protectedBundleIDs: Set<String> = [
        Identifiers.appBundleID,
        "com.apple.finder",
        "com.apple.dock",
        "com.apple.loginwindow",
        "com.apple.systemuiserver",
    ]

    /// Every `…/X.app` prefix of `path`, outermost first. Empty if the executable is not inside an app bundle.
    public static func enclosingBundlePaths(forExecutable path: String) -> [String] {
        var result: [String] = []
        var prefix = ""
        for component in path.split(separator: "/", omittingEmptySubsequences: true) {
            prefix += "/" + component
            if component.hasSuffix(".app") { result.append(prefix) }
        }
        return result
    }
}
