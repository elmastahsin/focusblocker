import XCTest
@testable import FocusCore

final class BlockClockTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_000_000)

    private func makeState(duration: TimeInterval = 3600) throws -> BlockState {
        try BlockState.make(sites: ["x.com"], appBundleIDs: [], endDate: t0.addingTimeInterval(duration), now: t0)
    }

    func testNotExpiredBeforeEnd() throws {
        let state = try makeState()
        XCTAssertFalse(BlockClock.isExpired(state, now: t0.addingTimeInterval(10)))
    }

    func testExpiredWhenWallAndMonotonicBothElapsed() throws {
        var state = try makeState()
        state = BlockClock.ticked(state, monotonicDelta: 3600)
        XCTAssertTrue(BlockClock.isExpired(state, now: t0.addingTimeInterval(3600)))
    }

    func testClockMovedForwardDoesNotEndBlock() throws {
        var state = try makeState()
        state = BlockClock.ticked(state, monotonicDelta: 60)
        let skewed = t0.addingTimeInterval(60 + 7200) // user jumps clock 2h ahead
        XCTAssertFalse(BlockClock.isExpired(state, now: skewed))
        XCTAssertEqual(BlockClock.effectiveEnd(of: state, now: skewed), skewed.addingTimeInterval(3540))
    }

    func testClockMovedBackwardKeepsWallEnd() throws {
        let state = try makeState()
        let rolledBack = t0.addingTimeInterval(-3600)
        XCTAssertEqual(BlockClock.effectiveEnd(of: state, now: rolledBack), state.endDate)
    }

    func testRebootKeepsRemainingMonotonic() throws {
        var state = try makeState()
        state = BlockClock.ticked(state, monotonicDelta: 600)          // 3000 s left, persisted
        let afterReboot = t0.addingTimeInterval(600 + 1800)             // machine was off 30 min
        XCTAssertFalse(BlockClock.isExpired(state, now: afterReboot))
        XCTAssertEqual(BlockClock.effectiveEnd(of: state, now: afterReboot), afterReboot.addingTimeInterval(3000))
    }

    func testTickClampsAtZeroAndIgnoresNegativeDelta() throws {
        var state = try makeState(duration: 10)
        state = BlockClock.ticked(state, monotonicDelta: -5)
        XCTAssertEqual(state.remainingMonotonic, 10)
        state = BlockClock.ticked(state, monotonicDelta: 100)
        XCTAssertEqual(state.remainingMonotonic, 0)
    }

    func testExtendAcceptsOnlyLaterDate() throws {
        let state = try makeState()
        let later = t0.addingTimeInterval(7200)
        let extended = try BlockClock.extended(state, to: later, now: t0)
        XCTAssertEqual(extended.endDate, later)
        XCTAssertEqual(extended.remainingMonotonic, 7200)

        XCTAssertThrowsError(try BlockClock.extended(state, to: state.endDate, now: t0)) {
            XCTAssertEqual($0 as? BlockError, .extendNotLater)
        }
        XCTAssertThrowsError(try BlockClock.extended(state, to: t0.addingTimeInterval(60), now: t0))
    }

    func testExtendComparesAgainstEffectiveEnd() throws {
        let state = try makeState()
        let skewedNow = t0.addingTimeInterval(7200) // effective end = skewedNow + 3600
        let belowEffective = skewedNow.addingTimeInterval(1800)
        XCTAssertThrowsError(try BlockClock.extended(state, to: belowEffective, now: skewedNow))
    }
}
