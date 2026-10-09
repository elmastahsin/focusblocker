import XCTest
@testable import FocusCore

final class BlockStateTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_000_000)
    private var end: Date { now.addingTimeInterval(1500) }

    func testMakeNormalizesAndDeduplicates() throws {
        let state = try BlockState.make(sites: ["https://www.X.com/a", "x.com", "instagram.com"],
                                        appBundleIDs: ["com.apple.Safari", "com.apple.Safari"],
                                        endDate: end, now: now)
        XCTAssertEqual(state.sites, ["x.com", "instagram.com"])
        XCTAssertEqual(state.appBundleIDs, ["com.apple.Safari"])
        XCTAssertEqual(state.remainingMonotonic, 1500)
    }

    func testMakeRejectsInvalidSiteAndHostsInjection() {
        XCTAssertThrowsError(try BlockState.make(sites: ["x.com\n127.0.0.1 evil.com"], appBundleIDs: [], endDate: end, now: now)) {
            XCTAssertEqual($0 as? BlockError, .invalidSite("x.com\n127.0.0.1 evil.com"))
        }
    }

    func testMakeRejectsInvalidBundleID() {
        XCTAssertThrowsError(try BlockState.make(sites: [], appBundleIDs: ["bad id"], endDate: end, now: now)) {
            XCTAssertEqual($0 as? BlockError, .invalidBundleID("bad id"))
        }
    }

    func testMakeRejectsPastEndDateAndEmptyRequest() {
        XCTAssertThrowsError(try BlockState.make(sites: ["x.com"], appBundleIDs: [], endDate: now, now: now)) {
            XCTAssertEqual($0 as? BlockError, .invalidEndDate)
        }
        XCTAssertThrowsError(try BlockState.make(sites: [], appBundleIDs: [], endDate: end, now: now)) {
            XCTAssertEqual($0 as? BlockError, .nothingToBlock)
        }
    }

    func testAppsOnlyRequestIsValid() throws {
        let state = try BlockState.make(sites: [], appBundleIDs: ["com.apple.Safari"], endDate: end, now: now)
        XCTAssertTrue(state.sites.isEmpty)
    }
}
