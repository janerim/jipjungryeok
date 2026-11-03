import XCTest
@testable import FocusCore

/// §4.2-2 주간 막대를 지난주로 옮길 때 쓰는 집계.
///
/// 기준 날짜는 **2026년 11월 4일 (수)**. 월요일 시작이므로 이 주는 11/2(월) ~ 11/8(일) 이다.
/// 시간대를 고정하지 않으면 다른 기기에서 하루씩 어긋난다 (규칙 3).
final class WeekSeriesTests: XCTestCase {

    private let calendar: Calendar = {
        var calendar = Calendar.focus
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return calendar
    }()

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12, _ min: Int = 0) -> Date {
        var parts = DateComponents()
        parts.year = y; parts.month = m; parts.day = d; parts.hour = h; parts.minute = min
        guard let result = calendar.date(from: parts) else {
            fatalError("테스트 날짜를 만들 수 없습니다: \(y)-\(m)-\(d)")
        }
        return result
    }

    private func session(_ start: Date, seconds: Int) -> SessionRecord {
        SessionRecord(
            id: UUID(), startAt: start, endAt: start.addingTimeInterval(Double(seconds)),
            plannedSeconds: seconds, actualSeconds: seconds, isCompleted: true
        )
    }

    private func summary(_ anchor: Date, _ sessions: [SessionRecord] = []) -> WeekSummary {
        WeekSeries.summary(forWeekContaining: anchor, sessions: sessions, calendar: calendar)
    }

    // MARK: - 주 경계

    /// §1-1 — 주는 월요일에 시작한다.
    func testWeekStartsOnMonday() {
        let s = summary(date(2026, 11, 4))
        XCTAssertEqual(s.weekStart, calendar.startOfDay(for: date(2026, 11, 2)))
        XCTAssertEqual(calendar.component(.weekday, from: s.weekStart), 2)
    }

    /// 주 안의 어느 날을 줘도 같은 주가 나온다. 일요일도 그 주에 속한다.
    func testAnyDayInTheWeekGivesTheSameWeek() {
        let monday = summary(date(2026, 11, 2)).weekStart
        XCTAssertEqual(summary(date(2026, 11, 8)).weekStart, monday, "일요일은 같은 주다")
        XCTAssertEqual(summary(date(2026, 11, 4)).weekStart, monday)
    }

    /// 아직 오지 않은 요일도 0 으로 자리를 채운다.
    func testAlwaysSevenColumns() {
        XCTAssertEqual(summary(date(2026, 11, 4)).totals.count, 7)
    }

    func testColumnsRunMondayToSunday() {
        let totals = summary(date(2026, 11, 4)).totals
        XCTAssertEqual(totals.first?.date, calendar.startOfDay(for: date(2026, 11, 2)))
        XCTAssertEqual(totals.last?.date, calendar.startOfDay(for: date(2026, 11, 8)))
    }

    // MARK: - 집계

    func testSecondsLandOnTheRightWeekday() {
        let s = summary(date(2026, 11, 4), [session(date(2026, 11, 4, 9), seconds: 1500)])
        XCTAssertEqual(s.totals[2].seconds, 1500, "수요일은 세 번째 칸이다")
        XCTAssertEqual(s.totalSeconds, 1500)
        XCTAssertEqual(s.sessionCount, 1)
    }

    /// §4.2 — 날짜 판정은 `startAt` 기준이다. 일요일 23:50 에 시작한 세션은
    /// 자정을 넘겨 끝나도 그 주 일요일에 남는다.
    func testSessionCrossingIntoNextWeekStaysInItsStartWeek() {
        let start = date(2026, 11, 8, 23, 50)
        let s = summary(date(2026, 11, 4), [session(start, seconds: 1500)])
        XCTAssertEqual(s.totals[6].seconds, 1500)

        let next = summary(date(2026, 11, 9), [session(start, seconds: 1500)])
        XCTAssertEqual(next.totalSeconds, 0, "다음 주로 넘어가지 않는다")
    }

    /// 다른 주의 세션이 섞여 들어와도 그 주 것만 센다.
    func testSessionsFromOtherWeeksAreIgnored() {
        let s = summary(date(2026, 11, 4), [
            session(date(2026, 11, 4, 9), seconds: 600),
            session(date(2026, 10, 28, 9), seconds: 9999)
        ])
        XCTAssertEqual(s.totalSeconds, 600)
        XCTAssertEqual(s.sessionCount, 1)
    }

    func testSessionCountCountsSessionsNotDays() {
        let s = summary(date(2026, 11, 4), [
            session(date(2026, 11, 4, 9), seconds: 600),
            session(date(2026, 11, 4, 15), seconds: 600),
            session(date(2026, 11, 5, 9), seconds: 600)
        ])
        XCTAssertEqual(s.sessionCount, 3)
        XCTAssertEqual(s.totalSeconds, 1800)
    }

    /// §12 — 세션 0건이어도 7칸이 그려져야 한다.
    func testEmptyWeekStillHasSevenColumns() {
        let s = summary(date(2026, 11, 4))
        XCTAssertEqual(s.totals.count, 7)
        XCTAssertEqual(s.totalSeconds, 0)
        XCTAssertEqual(s.sessionCount, 0)
    }

    // MARK: - 넘기기

    func testShiftCrossesTheMonthBoundary() {
        let previous = WeekSeries.shift(date(2026, 11, 4), by: -1, calendar: calendar)
        XCTAssertEqual(previous, calendar.startOfDay(for: date(2026, 10, 26)))
    }

    func testShiftIsAnchoredToTheWeekStart() {
        // 주 중간(수)에서 한 주 뒤는 다음 주 **월요일**이다.
        let next = WeekSeries.shift(date(2026, 11, 4), by: 1, calendar: calendar)
        XCTAssertEqual(next, calendar.startOfDay(for: date(2026, 11, 9)))
    }

    func testEarliestWeekBoundsHowFarBackYouCanGo() {
        let sessions = [
            session(date(2026, 11, 4, 9), seconds: 600),
            session(date(2026, 8, 20, 9), seconds: 600)
        ]
        XCTAssertEqual(
            WeekSeries.earliestWeek(in: sessions, calendar: calendar),
            calendar.startOfDay(for: date(2026, 8, 17)),
            "8/20 은 목요일이므로 그 주 월요일은 8/17 이다"
        )
    }

    func testEarliestWeekIsNilWithoutSessions() {
        XCTAssertNil(WeekSeries.earliestWeek(in: [], calendar: calendar))
    }

    // MARK: - 표기

    func testWeekLabelNamesThisAndLastWeek() {
        let now = date(2026, 11, 4)
        let thisWeek = WeekSeries.week(containing: now, calendar: calendar)
        XCTAssertEqual(TimeDisplay.relativeWeek(thisWeek, now: now, calendar: calendar), "이번 주")

        let lastWeek = WeekSeries.shift(thisWeek, by: -1, calendar: calendar)
        XCTAssertEqual(TimeDisplay.relativeWeek(lastWeek, now: now, calendar: calendar), "지난주")

        let older = WeekSeries.shift(thisWeek, by: -2, calendar: calendar)
        XCTAssertEqual(TimeDisplay.relativeWeek(older, now: now, calendar: calendar), "10월 19일 주")
    }
}
