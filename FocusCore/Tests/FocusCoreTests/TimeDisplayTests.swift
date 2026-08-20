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
}
