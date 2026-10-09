import XCTest
@testable import FocusCore

final class BlockDurationTests: XCTestCase {
    func testPresetsIgnoreCustomMinutes() {
        XCTAssertEqual(BlockDuration.minutes25.seconds(customMinutes: 999), 25 * 60)
        XCTAssertEqual(BlockDuration.hour1.seconds(customMinutes: 1), 3600)
        XCTAssertEqual(BlockDuration.hours2.seconds(customMinutes: 1), 7200)
        XCTAssertEqual(BlockDuration.hours4.seconds(customMinutes: 1), 14400)
    }

    func testCustomIsClamped() {
        XCTAssertEqual(BlockDuration.custom.seconds(customMinutes: 90), 5400)
        XCTAssertEqual(BlockDuration.custom.seconds(customMinutes: 0), 60)
        XCTAssertEqual(BlockDuration.custom.seconds(customMinutes: 100_000), 1440 * 60)
    }
}
