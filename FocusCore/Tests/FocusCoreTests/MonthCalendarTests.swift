import XCTest
@testable import FocusCore

/// §4.2-3 통계 화면의 달력.
///
/// 기준 달은 **2026년 11월**. 11/1 은 일요일이라 월요일 시작 격자에서는
/// 10/26(월) 줄의 마지막 칸이 된다 — 앞뒤 달 칸이 섞이는 경우를 제대로 덮는다.
/// 시간대를 고정하지 않으면 다른 기기에서 하루씩 어긋나므로 서울로 못박는다 (규칙 3).
final class MonthCalendarTests: XCTestCase {

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
            id: UUID(),
            startAt: start,
            endAt: start.addingTimeInterval(Double(seconds)),
            plannedSeconds: seconds,
            actualSeconds: seconds,
            isCompleted: true
        )
    }

    private func grid(_ month: Date, _ sessions: [SessionRecord] = []) -> MonthGrid {
        MonthCalendar.grid(for: month, sessions: sessions, calendar: calendar)
    }

    // MARK: - 격자 모양

    /// §1-1 — 모든 줄은 월요일에 시작한다.
    func testEveryWeekStartsOnMonday() {
        for week in grid(date(2026, 11, 15)).weeks {
            XCTAssertEqual(week.count, 7)
            XCTAssertEqual(calendar.component(.weekday, from: week[0].date), 2)
        }
    }

    /// 11/1 은 일요일이다. 첫 줄은 10/26(월)로 시작하고 11/1 이 그 줄의 끝이다.
    func testGridIsPaddedWithAdjacentMonthDays() {
        let weeks = grid(date(2026, 11, 15)).weeks
        let first = weeks[0]

        XCTAssertEqual(first[0].date, calendar.startOfDay(for: date(2026, 10, 26)))
        XCTAssertFalse(first[0].isInMonth)
        XCTAssertEqual(first[6].date, calendar.startOfDay(for: date(2026, 11, 1)))
        XCTAssertTrue(first[6].isInMonth)
    }

    /// 그 달 날짜는 하나도 빠지지 않는다.
    func testGridCoversEveryDayOfTheMonth() {
        let days = grid(date(2026, 11, 15)).weeks.flatMap { $0 }.filter(\.isInMonth)
        XCTAssertEqual(days.count, 30)
        XCTAssertEqual(days.first?.date, calendar.startOfDay(for: date(2026, 11, 1)))
        XCTAssertEqual(days.last?.date, calendar.startOfDay(for: date(2026, 11, 30)))
    }

    /// 줄 수를 6 으로 고정하지 않는다. 달마다 실제 필요한 만큼만 그린다.
    ///
    /// 2026-11 은 10/26(월) ~ 12/6(일) 42일이라 **6줄**,
    /// 2026-02 는 1/26(월) ~ 3/1(일) 35일이라 **5줄**이다.
    /// 달력이 통계 화면의 마지막 섹션이라, 줄 수가 달라져도 아래가 밀리지 않는다.
    func testWeekCountFollowsTheMonth() {
        XCTAssertEqual(grid(date(2026, 11, 15)).weeks.count, 6)
        XCTAssertEqual(grid(date(2026, 2, 10)).weeks.count, 5)
    }

    /// 달 안 아무 날이나 줘도 같은 격자가 나온다.
    func testAnyDayInTheMonthGivesTheSameGrid() {
        XCTAssertEqual(grid(date(2026, 11, 1)), grid(date(2026, 11, 30)))
    }

    // MARK: - 집계

    /// §4.2 — 날짜 판정은 `startAt` 기준이다.
    /// 23:50 에 시작해 자정을 넘긴 세션도 전부 시작일에 귀속된다.
    func testSessionCrossingMidnightBelongsToItsStartDay() {
        let g = grid(date(2026, 11, 10), [session(date(2026, 11, 10, 23, 50), seconds: 1500)])
        let day = { (d: Int) in
            g.weeks.flatMap { $0 }.first { $0.date == self.calendar.startOfDay(for: self.date(2026, 11, d)) }
        }
        XCTAssertEqual(day(10)?.seconds, 1500)
        XCTAssertEqual(day(11)?.seconds, 0)
    }

    func testSecondsOnTheSameDayAreSummed() {
        let g = grid(date(2026, 11, 10), [
            session(date(2026, 11, 10, 9), seconds: 600),
            session(date(2026, 11, 10, 15), seconds: 900)
        ])
        let day = g.weeks.flatMap { $0 }.first { $0.date == calendar.startOfDay(for: date(2026, 11, 10)) }
        XCTAssertEqual(day?.seconds, 1500)
    }

    /// 앞뒤 달에서 들어온 칸은 그 달 합계에 넣지 않는다.
    /// 칸에는 값이 보이지만 머리줄의 "N일 · HH:mm" 은 그 달 것만 세야 한다.
    func testAdjacentMonthDaysAreExcludedFromTotals() {
        let g = grid(date(2026, 11, 15), [
            session(date(2026, 10, 26, 10), seconds: 3600),   // 격자 첫 칸, 10월
            session(date(2026, 11, 3, 10), seconds: 1800)
        ])
        XCTAssertEqual(g.totalSeconds, 1800)
        XCTAssertEqual(g.activeDayCount, 1)

        let padded = g.weeks[0][0]
        XCTAssertFalse(padded.isInMonth)
        XCTAssertEqual(padded.seconds, 3600, "칸에는 값이 그려져야 한다")
    }

    /// 하루에 여러 번 했어도 "나온 날" 은 하루다.
    func testActiveDayCountCountsDaysNotSessions() {
        let g = grid(date(2026, 11, 10), [
            session(date(2026, 11, 3, 9), seconds: 600),
            session(date(2026, 11, 3, 15), seconds: 600),
            session(date(2026, 11, 4, 9), seconds: 600)
        ])
        XCTAssertEqual(g.activeDayCount, 2)
    }

    /// §12 — 세션 0건이어도 격자가 그려져야 한다.
    func testEmptyMonthStillDrawsAGrid() {
        let g = grid(date(2026, 11, 15))
        XCTAssertEqual(g.totalSeconds, 0)
        XCTAssertEqual(g.activeDayCount, 0)
        XCTAssertFalse(g.weeks.isEmpty)
    }

    // MARK: - 달 넘기기

    func testShiftCrossesTheYearBoundary() {
        let january = MonthCalendar.shift(date(2026, 12, 15), by: 1, calendar: calendar)
        XCTAssertEqual(january, calendar.startOfDay(for: date(2027, 1, 1)))

        let december = MonthCalendar.shift(date(2027, 1, 15), by: -1, calendar: calendar)
        XCTAssertEqual(december, calendar.startOfDay(for: date(2026, 12, 1)))
    }

    /// 1월 31일에서 한 달 뒤는 2월 28일이 아니라 **2월 1일**이다.
    /// 달의 시작으로 먼저 맞춘 뒤 더하기 때문이다.
    func testShiftIsAnchoredToTheStartOfMonth() {
        let february = MonthCalendar.shift(date(2026, 1, 31), by: 1, calendar: calendar)
        XCTAssertEqual(february, calendar.startOfDay(for: date(2026, 2, 1)))
    }

    func testEarliestMonthBoundsHowFarBackYouCanGo() {
        let sessions = [
            session(date(2026, 11, 3, 10), seconds: 600),
            session(date(2026, 8, 20, 10), seconds: 600)
        ]
        XCTAssertEqual(
            MonthCalendar.earliestMonth(in: sessions, calendar: calendar),
            calendar.startOfDay(for: date(2026, 8, 1))
        )
    }

    func testEarliestMonthIsNilWithoutSessions() {
        XCTAssertNil(MonthCalendar.earliestMonth(in: [], calendar: calendar))
    }
}
