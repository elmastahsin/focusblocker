import Foundation

/// String-in/string-out editing of the FOCUSBLOCKER section of a hosts file.
/// Lines outside the section are never modified.
public enum HostsBlockRenderer {
    public static let startMarker = "# FOCUSBLOCKER-START"
    public static let endMarker = "# FOCUSBLOCKER-END"

    public static func render(sites: [String]) -> String {
        var lines = [startMarker]
        for site in sites {
            for host in [site, "www.\(site)"] {
                lines.append("0.0.0.0 \(host)")
                lines.append(":: \(host)")
            }
        }
        lines.append(endMarker)
        return lines.joined(separator: "\n") + "\n"
    }

    /// Returns `hosts` with exactly one up-to-date block (or none when `sites` is empty).
    public static func apply(to hosts: String, sites: [String]) -> String {
        var base = remove(from: hosts)
        guard !sites.isEmpty else { return base }
        if !base.isEmpty && !base.hasSuffix("\n") { base += "\n" }
        return base + render(sites: sites)
    }

    /// Removes every FOCUSBLOCKER block, including unterminated or duplicated ones.
    public static func remove(from hosts: String) -> String {
        var lines = hosts.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)

        while let start = lines.firstIndex(where: { isMarker($0, startMarker) }) {
            var last = start
            if let end = lines[(start + 1)...].firstIndex(where: { isMarker($0, endMarker) }) {
                last = end
            } else {
                // Unterminated block: drop only the entries that directly follow the marker.
                while last + 1 < lines.count, isBlockEntry(lines[last + 1]) { last += 1 }
            }
            lines.removeSubrange(start...last)
        }
        lines.removeAll { isMarker($0, endMarker) }
        return lines.joined(separator: "\n")
    }

    private static func isMarker(_ line: String, _ marker: String) -> Bool {
        line.trimmingCharacters(in: .whitespaces) == marker
    }

    private static func isBlockEntry(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        return trimmed.hasPrefix("0.0.0.0 ") || trimmed.hasPrefix(":: ")
    }
}
