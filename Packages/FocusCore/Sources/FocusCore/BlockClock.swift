import Foundation

/// Monotonic seconds. Keeps counting during sleep, resets on reboot, ignores wall-clock changes.
public enum MonotonicClock {
    public static func now() -> TimeInterval {
        TimeInterval(clock_gettime_nsec_np(CLOCK_MONOTONIC)) / 1_000_000_000
    }
}

/// Pure time rules. The block ends only when BOTH the wall clock and the monotonic counter say so.
public enum BlockClock {
    public static func effectiveEnd(of state: BlockState, now: Date) -> Date {
        max(state.endDate, now.addingTimeInterval(state.remainingMonotonic))
    }

    public static func isExpired(_ state: BlockState, now: Date) -> Bool {
        now >= effectiveEnd(of: state, now: now)
    }

    public static func ticked(_ state: BlockState, monotonicDelta: TimeInterval) -> BlockState {
        var next = state
        next.remainingMonotonic = max(0, state.remainingMonotonic - max(0, monotonicDelta))
        return next
    }

    public static func extended(_ state: BlockState, to newEnd: Date, now: Date) throws -> BlockState {
        guard newEnd > effectiveEnd(of: state, now: now) else { throw BlockError.extendNotLater }
        var next = state
        next.endDate = newEnd
        next.remainingMonotonic = newEnd.timeIntervalSince(now)
        return next
    }
}
