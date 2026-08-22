import XCTest
@testable import FocusCore

/// §4.2 기록(이력) 묶기.
///
/// 시간대를 고정하지 않으면 다른 기기에서 하루씩 어긋나므로 서울로 못박는다.
/// 날짜 판정 규칙은 추세·차트와 같아야 한다 — `startAt` 기준이다.
final class SessionHistoryTests: XCTestCase {

    private let calendar: Calendar = {
        var calendar = Calendar.focus
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return calendar
    }()

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12, _ minute: Int = 0) -> Date {
        var parts = DateComponents()
        parts.year = year
        parts.month = month
        parts.day = day
        parts.hour = hour
        parts.minute = minute
        guard let result = calendar.date(from: parts) else {
            fatalError("테스트 날짜를 만들 수 없습니다: \(year)-\(month)-\(day)")
        }
        return result
    }

    private func record(
        startAt: Date,
        seconds: Int,
        completed: Bool = true,
        memo: String? = nil
    ) -> SessionRecord {
        SessionRecord(
            id: UUID(),
            startAt: startAt,
            endAt: startAt.addingTimeInterval(Double(seconds)),
            plannedSeconds: seconds,
            actualSeconds: seconds,
            isCompleted: completed,
            memo: memo
        )
    }

    // MARK: - 묶기

    func testEmptyInputProducesNoDays() {
        XCTAssertTrue(SessionHistory.byDay([], calendar: calendar).isEmpty)
    }

    func testSessionsOnSameDayAreGroupedTogether() {
        let days = SessionHistory.byDay(
            [
                record(startAt: date(2026, 8, 21, 9, 0), seconds: 600),
                record(startAt: date(2026, 8, 21, 16, 0), seconds: 1500),
            ],
            calendar: calendar
        )

        XCTAssertEqual(days.count, 1)
        XCTAssertEqual(days[0].sessionCount, 2)
        XCTAssertEqual(days[0].totalSeconds, 2100)
    }

    /// 최신 날짜가 먼저. 화면에서 위에서부터 최근 순으로 읽힌다.
    func testDaysAreOrderedNewestFirst() {
        let days = SessionHistory.byDay(
            [
                record(startAt: date(2026, 8, 19, 10, 0), seconds: 600),
                record(startAt: date(2026, 8, 21, 10, 0), seconds: 600),
                record(startAt: date(2026, 8, 20, 10, 0), seconds: 600),
            ],
            calendar: calendar
        )

        XCTAssertEqual(days.map(\.date), [
            calendar.startOfDay(for: date(2026, 8, 21)),
            calendar.startOfDay(for: date(2026, 8, 20)),
            calendar.startOfDay(for: date(2026, 8, 19)),
        ])
    }

    /// 하루 안에서도 늦게 시작한 세션이 위로 온다.
    func testSessionsWithinDayAreOrderedNewestFirst() {
        let days = SessionHistory.byDay(
            [
                record(startAt: date(2026, 8, 21, 9, 0), seconds: 600, memo: "아침"),
                record(startAt: date(2026, 8, 21, 20, 0), seconds: 600, memo: "저녁"),
                record(startAt: date(2026, 8, 21, 14, 0), seconds: 600, memo: "낮"),
            ],
            calendar: calendar
        )

        XCTAssertEqual(days[0].sessions.map(\.memo), ["저녁", "낮", "아침"])
    }

    // MARK: - §4.2 날짜 귀속

    /// 23:50 에 시작해 00:15 에 끝난 세션은 **전부 시작일**에 들어간다.
    /// 여기서 endAt 을 쓰면 추세·차트와 같은 세션이 다른 날에 잡혀 화면끼리 어긋난다.
    func testMidnightCrossingSessionBelongsToStartDay() {
        let days = SessionHistory.byDay(
            [record(startAt: date(2026, 8, 21, 23, 50), seconds: 25 * 60)],
            calendar: calendar
        )

        XCTAssertEqual(days.count, 1)
        XCTAssertEqual(days[0].date, calendar.startOfDay(for: date(2026, 8, 21)))
        XCTAssertEqual(days[0].totalSeconds, 25 * 60)
    }

    /// 자정 직후에 시작한 세션은 그 날에 들어간다. 위 경우와 짝을 이룬다.
    func testSessionStartedJustAfterMidnightBelongsToThatDay() {
        let days = SessionHistory.byDay(
            [record(startAt: date(2026, 8, 22, 0, 5), seconds: 600)],
            calendar: calendar
        )

        XCTAssertEqual(days[0].date, calendar.startOfDay(for: date(2026, 8, 22)))
    }

    // MARK: - 중도 중지

    /// 회고 카드는 완료된 것만 보여주지만(§4.2-2), 이력은 그 날 무엇을 했나의 기록이라
    /// 중간에 접은 세션도 남는다.
    func testStoppedSessionsAreIncluded() {
        let days = SessionHistory.byDay(
            [
                record(startAt: date(2026, 8, 21, 10, 0), seconds: 1500),
                record(startAt: date(2026, 8, 21, 12, 0), seconds: 420, completed: false),
            ],
            calendar: calendar
        )

        XCTAssertEqual(days[0].sessionCount, 2)
        XCTAssertEqual(days[0].sessions.filter { !$0.isCompleted }.count, 1)
    }

    /// 합계는 계획한 시간이 아니라 **실제 집중한 시간**이다.
    func testTotalUsesActualNotPlannedSeconds() {
        let stopped = SessionRecord(
            id: UUID(),
            startAt: date(2026, 8, 21, 10, 0),
            endAt: date(2026, 8, 21, 10, 7),
            plannedSeconds: 1500,
            actualSeconds: 420,
            isCompleted: false,
            memo: nil
        )

        let days = SessionHistory.byDay([stopped], calendar: calendar)

        XCTAssertEqual(days[0].totalSeconds, 420)
    }
}
