import Foundation

/// Turns user input ("https://www.X.com/path") into a bare hostname ("x.com").
/// Strict on purpose: the result is written into /etc/hosts by a root process.
public enum DomainNormalizer {
    public static func normalize(_ input: String) -> String? {
        var s = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let scheme = s.range(of: "://") { s = String(s[scheme.upperBound...]) }
        if let end = s.firstIndex(where: { "/?#".contains($0) }) { s = String(s[..<end]) }
        if let at = s.lastIndex(of: "@") { s = String(s[s.index(after: at)...]) }
        if let colon = s.firstIndex(of: ":") { s = String(s[..<colon]) }
        while s.hasSuffix(".") { s.removeLast() }
        if s.hasPrefix("www.") { s.removeFirst(4) }
        return isValidHostname(s) ? s : nil
    }

    static func isValidHostname(_ host: String) -> Bool {
        guard host.utf8.count <= 253 else { return false }
        let labels = host.split(separator: ".", omittingEmptySubsequences: false)
        guard labels.count >= 2 else { return false }
        for label in labels {
            guard (1...63).contains(label.utf8.count),
                  !label.hasPrefix("-"), !label.hasSuffix("-"),
                  label.utf8.allSatisfy({ ($0 >= 0x61 && $0 <= 0x7A) || ($0 >= 0x30 && $0 <= 0x39) || $0 == 0x2D })
            else { return false }
        }
        return !labels[labels.count - 1].allSatisfy(\.isNumber)
    }
}

public enum BundleIDValidator {
    public static func isValid(_ id: String) -> Bool {
        guard (1...255).contains(id.utf8.count) else { return false }
        return id.utf8.allSatisfy {
            ($0 >= 0x61 && $0 <= 0x7A) || ($0 >= 0x41 && $0 <= 0x5A) || ($0 >= 0x30 && $0 <= 0x39)
                || $0 == 0x2E || $0 == 0x2D || $0 == 0x5F
        }
    }
}
