import XCTest
@testable import FocusCore

/// §4.1 / §4.2 시간 표기 규칙.
final class TimeDisplayTests: XCTestCase {

    /// 60초 이상이면 분 단위 정수, 올림.
    /// 25분 세션은 시작 후 60초 동안 `25` 로 보이다가 `24` 로 넘어간다.
    func testCountdownShowsCeilingMinutesAboveOneMinute() {
        XCTAssertEqual(TimeDisplay.countdown(1500), "25")
        XCTAssertEqual(TimeDisplay.countdown(1499), "25")
        XCTAssertEqual(TimeDisplay.countdown(1441), "25")
        XCTAssertEqual(TimeDisplay.countdown(1440), "24")
        XCTAssertEqual(TimeDisplay.countdown(61), "2")
        XCTAssertEqual(TimeDisplay.countdown(60), "1")
    }

    /// 60초 미만이면 MM:SS.
    func testCountdownSwitchesToMinuteSecondsUnderOneMinute() {
        XCTAssertEqual(TimeDisplay.countdown(59), "00:59")
        XCTAssertEqual(TimeDisplay.countdown(9), "00:09")
        XCTAssertEqual(TimeDisplay.countdown(0), "00:00")
    }

    /// 음수가 흘러들어와도 0 으로 막는다.
    func testCountdownClampsNegative() {
        XCTAssertEqual(TimeDisplay.countdown(-10), "00:00")
    }

    /// §4.2 통계 표기: 35분 → `00:35`, 3시간 5분 → `03:05`
    func testHHMMFormatting() {
        XCTAssertEqual(TimeDisplay.hhmm(35 * 60), "00:35")
        XCTAssertEqual(TimeDisplay.hhmm(3 * 3600 + 5 * 60), "03:05")
        XCTAssertEqual(TimeDisplay.hhmm(0), "00:00")
        XCTAssertEqual(TimeDisplay.hhmm(59), "00:00", "1분 미만은 00:00 으로 떨어진다")
        XCTAssertEqual(TimeDisplay.hhmm(10 * 3600), "10:00")
    }

    func testHHMMClampsNegative() {
        XCTAssertEqual(TimeDisplay.hhmm(-1), "00:00")
    }

    // MARK: - §4.2 회고 / 시간 요약

    /// 회고의 집중 분은 반올림한 정수다.
    func testMinutesRoundsToNearest() {
        XCTAssertEqual(TimeDisplay.minutes(2100), 35)
        XCTAssertEqual(TimeDisplay.minutes(2129), 35)
        XCTAssertEqual(TimeDisplay.minutes(2130), 36)
        XCTAssertEqual(TimeDisplay.minutes(0), 0)
        XCTAssertEqual(TimeDisplay.minutes(-60), 0)
    }

    /// 합계는 `N시간 N분`. 한 시간이 안 되면 분만 적는다.
    func testHourMinuteText() {
        XCTAssertEqual(TimeDisplay.hourMinuteText(3 * 3600 + 5 * 60), "3시간 5분")
        XCTAssertEqual(TimeDisplay.hourMinuteText(3600), "1시간 0분")
        XCTAssertEqual(TimeDisplay.hourMinuteText(35 * 60), "35분")
        XCTAssertEqual(TimeDisplay.hourMinuteText(0), "0분")
        XCTAssertEqual(TimeDisplay.hourMinuteText(-5), "0분")
    }

    // MARK: - 날짜 표기

    /// 시간대를 고정해야 결과가 기기마다 달라지지 않는다.
    private var seoul: Calendar = {
        var calendar = Calendar.focus
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return calendar
    }()

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
        var parts = DateComponents()
        parts.year = year
        parts.month = month
        parts.day = day
        parts.hour = hour
        parts.minute = minute
        guard let result = seoul.date(from: parts) else {
            fatalError("테스트 날짜를 만들 수 없습니다")
        }
        return result
    }

    func testMonthDay() {
        XCTAssertEqual(TimeDisplay.monthDay(date(2026, 8, 20, 14, 5), calendar: seoul), "8월 20일")
        XCTAssertEqual(TimeDisplay.monthDay(date(2026, 12, 1, 0, 0), calendar: seoul), "12월 1일")
    }

    func testClockTimeIsZeroPadded() {
        XCTAssertEqual(TimeDisplay.clockTime(date(2026, 8, 20, 14, 5), calendar: seoul), "14:05")
        XCTAssertEqual(TimeDisplay.clockTime(date(2026, 8, 20, 9, 0), calendar: seoul), "09:00")
        XCTAssertEqual(TimeDisplay.clockTime(date(2026, 8, 20, 0, 15), calendar: seoul), "00:15")
    }

    func testYearMonth() {
        XCTAssertEqual(TimeDisplay.yearMonth(date(2026, 8, 20, 14, 0), calendar: seoul), "2026년 8월")
        XCTAssertEqual(TimeDisplay.yearMonth(date(2026, 1, 1, 0, 0), calendar: seoul), "2026년 1월")
    }

    // MARK: - 목록 날짜 라벨

    func testRelativeDayNamesTodayAndYesterday() {
        let now = date(2026, 8, 22, 14, 0)

        XCTAssertEqual(TimeDisplay.relativeDay(date(2026, 8, 22, 9, 0), now: now, calendar: seoul), "오늘")
        XCTAssertEqual(TimeDisplay.relativeDay(date(2026, 8, 21, 23, 0), now: now, calendar: seoul), "어제")
        XCTAssertEqual(TimeDisplay.relativeDay(date(2026, 8, 20, 10, 0), now: now, calendar: seoul), "8월 20일")
    }

    /// 같은 날이면 시각이 달라도 "오늘" 이다. 자정 직후도 마찬가지다.
    func testRelativeDayIgnoresTimeOfDay() {
        let now = date(2026, 8, 22, 0, 0)
        XCTAssertEqual(TimeDisplay.relativeDay(date(2026, 8, 22, 23, 0), now: now, calendar: seoul), "오늘")
    }

    /// 달을 넘어가도 어제는 어제다.
    func testRelativeDayHandlesMonthBoundary() {
        let now = date(2026, 9, 1, 10, 0)
        XCTAssertEqual(TimeDisplay.relativeDay(date(2026, 8, 31, 22, 0), now: now, calendar: seoul), "어제")
    }
}
