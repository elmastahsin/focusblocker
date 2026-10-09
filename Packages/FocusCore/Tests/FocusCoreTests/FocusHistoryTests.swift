import XCTest
@testable import FocusCore

final class FocusHistoryTests: XCTestCase {
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    /// 2026-01-10 00:00 UTC
    private let day0 = Date(timeIntervalSince1970: 1_768_003_200)

    private func at(day: Int, hour: Double) -> Date {
        day0.addingTimeInterval(Double(day) * 86_400 + hour * 3600)
    }

    func testEmptyHistory() {
        let history = FocusHistory()
        XCTAssertEqual(history.totalFocus(on: day0, calendar: calendar), 0)
        XCTAssertEqual(history.streak(endingAt: day0, calendar: calendar), 0)
    }

    func testTotalSumsSessionsOfThatDay() {
        let history = FocusHistory(sessions: [
            FocusSession(start: at(day: 0, hour: 9), end: at(day: 0, hour: 10)),
            FocusSession(start: at(day: 0, hour: 14), end: at(day: 0, hour: 14.5)),
            FocusSession(start: at(day: 1, hour: 9), end: at(day: 1, hour: 10)),
        ])
        XCTAssertEqual(history.totalFocus(on: at(day: 0, hour: 20), calendar: calendar), 5400)
    }

    func testSessionCrossingMidnightIsSplit() {
        let history = FocusHistory(sessions: [
            FocusSession(start: at(day: 0, hour: 23), end: at(day: 1, hour: 1)),
        ])
        XCTAssertEqual(history.totalFocus(on: at(day: 0, hour: 12), calendar: calendar), 3600)
        XCTAssertEqual(history.totalFocus(on: at(day: 1, hour: 12), calendar: calendar), 3600)
    }

    func testStreakCountsConsecutiveDays() {
        let history = FocusHistory(sessions: [
            FocusSession(start: at(day: 0, hour: 9), end: at(day: 0, hour: 10)),
            FocusSession(start: at(day: 2, hour: 9), end: at(day: 2, hour: 10)),
            FocusSession(start: at(day: 3, hour: 9), end: at(day: 3, hour: 10)),
        ])
        XCTAssertEqual(history.streak(endingAt: at(day: 3, hour: 12), calendar: calendar), 2)
    }

    func testStreakStartsFromYesterdayWhenTodayEmpty() {
        let history = FocusHistory(sessions: [
            FocusSession(start: at(day: 0, hour: 9), end: at(day: 0, hour: 10)),
            FocusSession(start: at(day: 1, hour: 9), end: at(day: 1, hour: 10)),
        ])
        XCTAssertEqual(history.streak(endingAt: at(day: 2, hour: 8), calendar: calendar), 2)
        XCTAssertEqual(history.streak(endingAt: at(day: 3, hour: 8), calendar: calendar), 0)
    }

    func testAppendingDropsOldSessions() {
        let old = FocusSession(start: at(day: 0, hour: 9), end: at(day: 0, hour: 10))
        let recent = FocusSession(start: at(day: 400, hour: 9), end: at(day: 400, hour: 10))
        let history = FocusHistory(sessions: [old]).appending(recent)
        XCTAssertEqual(history.sessions, [recent])
    }
}
