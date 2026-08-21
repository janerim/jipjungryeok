import XCTest
@testable import FocusCore

/// §7 캘린더 이벤트 제목.
final class CalendarEventFormatTests: XCTestCase {

    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)

    private func record(
        planned: Int,
        actual: Int,
        completed: Bool
    ) -> SessionRecord {
        SessionRecord(
            id: UUID(),
            startAt: t0,
            endAt: t0.addingTimeInterval(Double(actual)),
            plannedSeconds: planned,
            actualSeconds: actual,
            isCompleted: completed
        )
    }

    func testCompletedSessionTitle() {
        let title = CalendarEventFormat.eventTitle(
            for: record(planned: 1500, actual: 1500, completed: true)
        )
        XCTAssertEqual(title, "🎯 집중 25분")
    }

    func testStoppedSessionTitleIsMarked() {
        let title = CalendarEventFormat.eventTitle(
            for: record(planned: 1500, actual: 1500, completed: false)
        )
        XCTAssertEqual(title, "🎯 집중 25분 (중단)")
    }

    /// 25분을 맞춰놓고 7분 만에 멈춘 세션이 "25분" 으로 남으면 안 된다.
    func testStoppedSessionUsesActualNotPlannedMinutes() {
        let title = CalendarEventFormat.eventTitle(
            for: record(planned: 1500, actual: 7 * 60, completed: false)
        )
        XCTAssertEqual(title, "🎯 집중 7분 (중단)")
    }

    /// 90분까지 늘어난 다이얼 최대값도 그대로 나온다.
    func testLongSessionTitle() {
        let title = CalendarEventFormat.eventTitle(
            for: record(planned: 90 * 60, actual: 90 * 60, completed: true)
        )
        XCTAssertEqual(title, "🎯 집중 90분")
    }

    func testCalendarNameIsStable() {
        XCTAssertEqual(CalendarEventFormat.calendarName, "집중")
    }
}
