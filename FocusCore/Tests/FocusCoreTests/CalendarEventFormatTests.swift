import XCTest
@testable import FocusCore

/// §7 캘린더 이벤트 제목.
final class CalendarEventFormatTests: XCTestCase {

    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)

    private func record(
        planned: Int,
        actual: Int,
        completed: Bool,
        memo: String? = nil
    ) -> SessionRecord {
        SessionRecord(
            id: UUID(),
            startAt: t0,
            endAt: t0.addingTimeInterval(Double(actual)),
            plannedSeconds: planned,
            actualSeconds: actual,
            isCompleted: completed,
            memo: memo
        )
    }

    func testCompletedSessionTitle() {
        let title = CalendarEventFormat.eventTitle(
            for: record(planned: 1500, actual: 1500, completed: true)
        )
        XCTAssertEqual(title, "🎯 집중")
    }

    func testStoppedSessionTitleIsMarked() {
        let title = CalendarEventFormat.eventTitle(
            for: record(planned: 1500, actual: 1500, completed: false)
        )
        XCTAssertEqual(title, "🎯 집중 (중단)")
    }

    /// 제목은 세션 길이에 좌우되지 않는다. 길이는 시작·종료 시각이 전달하므로
    /// 7분짜리든 90분짜리든 제목이 같아야 한다.
    func testTitleDoesNotVaryWithDuration() {
        let short = CalendarEventFormat.eventTitle(
            for: record(planned: 90 * 60, actual: 7 * 60, completed: true)
        )
        let long = CalendarEventFormat.eventTitle(
            for: record(planned: 90 * 60, actual: 90 * 60, completed: true)
        )
        XCTAssertEqual(short, long)
        XCTAssertEqual(short, "🎯 집중")
    }

    /// 제목에 숫자가 섞여 들어가면 캘린더에서 길이 정보가 두 번 나온다.
    func testTitleContainsNoDigits() {
        let title = CalendarEventFormat.eventTitle(
            for: record(planned: 1500, actual: 1500, completed: true)
        )
        XCTAssertNil(title.rangeOfCharacter(from: .decimalDigits))
    }

    /// 제목 라벨이 바뀌면 과거 이벤트와 새 이벤트가 달라 보인다.
    func testSessionLabelIsStable() {
        XCTAssertEqual(CalendarEventFormat.sessionLabel, "집중")
    }

    // MARK: - 메모 → 이벤트 notes

    func testMemoBecomesEventNotes() {
        let notes = CalendarEventFormat.eventNotes(
            for: record(planned: 1500, actual: 1500, completed: true, memo: "기획서 정리")
        )
        XCTAssertEqual(notes, "기획서 정리")
    }

    func testNoMemoMeansNoNotes() {
        XCTAssertNil(
            CalendarEventFormat.eventNotes(
                for: record(planned: 1500, actual: 1500, completed: true, memo: nil)
            )
        )
    }

    /// 공백만 남은 메모는 "없음" 과 같게 취급한다.
    /// 빈 문자열을 저장하면 회고 카드에 빈 줄만 남는다.
    func testBlankMemoIsTreatedAsAbsent() {
        XCTAssertNil(CalendarEventFormat.normalizedMemo(""))
        XCTAssertNil(CalendarEventFormat.normalizedMemo("   "))
        XCTAssertNil(CalendarEventFormat.normalizedMemo("\n \t "))
        XCTAssertNil(CalendarEventFormat.normalizedMemo(nil))
    }

    func testMemoIsTrimmed() {
        XCTAssertEqual(CalendarEventFormat.normalizedMemo("  기획서 정리 \n"), "기획서 정리")
    }

    /// 메모는 제목에 끼어들지 않는다. 제목은 §7 스펙 그대로여야 한다.
    func testMemoDoesNotLeakIntoTitle() {
        let title = CalendarEventFormat.eventTitle(
            for: record(planned: 1500, actual: 1500, completed: true, memo: "기획서 정리")
        )
        XCTAssertEqual(title, "🎯 집중")
    }
}
