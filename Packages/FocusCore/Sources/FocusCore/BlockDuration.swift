import Foundation

public enum BlockDuration: Hashable, CaseIterable, Sendable {
    case minutes25, hour1, hours2, hours4, custom

    /// UI limit for the custom option. A block cannot be cancelled, so keep it bounded.
    public static let customMinutesRange = 1...1440

    public var title: String {
        switch self {
        case .minutes25: return "25 dk"
        case .hour1: return "1 sa"
        case .hours2: return "2 sa"
        case .hours4: return "4 sa"
        case .custom: return "Özel"
        }
    }

    public func seconds(customMinutes: Int) -> TimeInterval {
        let minutes: Int
        switch self {
        case .minutes25: minutes = 25
        case .hour1: minutes = 60
        case .hours2: minutes = 120
        case .hours4: minutes = 240
        case .custom:
            minutes = min(max(customMinutes, Self.customMinutesRange.lowerBound), Self.customMinutesRange.upperBound)
        }
        return TimeInterval(minutes * 60)
    }
}
