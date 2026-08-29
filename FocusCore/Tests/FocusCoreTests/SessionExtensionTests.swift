import XCTest
@testable import FocusCore

/// §6-7 회고를 저장한 시각까지 세션을 늘리는 규칙.
///
/// 이 계산이 틀리면 통계와 캘린더에 실제보다 긴 세션이 남는다. 눈으로는 한참 뒤에야
/// 발견되는 종류의 오류라 경계를 전부 못박는다.
final class SessionExtensionTests: XCTestCase {

    private let end = Date(timeIntervalSince1970: 1_000_000)

    private func record(actualSeconds: Int, endAt: Date) -> SessionRecord {
        SessionRecord(
            id: UUID(),
            startAt: endAt.addingTimeInterval(-Double(actualSeconds)),
            endAt: endAt,
            plannedSeconds: actualSeconds,
            actualSeconds: actualSeconds,
            isCompleted: true,
            memo: nil
        )
    }

    // MARK: - 늘리지 않아야 하는 경우

    /// 바로 저장하면 늘릴 것이 없다.
    func testSavingAtTheEndAddsNothing() {
        XCTAssertEqual(SessionExtension.extraSeconds(originalEnd: end, savedAt: end), 0)
    }

    /// 기기 시계가 뒤로 튀어 저장 시각이 종료보다 이전이 될 수 있다.
    /// 음수를 그대로 더하면 세션이 줄어든다.
    func testSavingBeforeTheEndNeverShrinksTheSession() {
        let earlier = end.addingTimeInterval(-600)
        XCTAssertEqual(SessionExtension.extraSeconds(originalEnd: end, savedAt: earlier), 0)
        XCTAssertEqual(SessionExtension.extendedEnd(originalEnd: end, savedAt: earlier), end)
    }

    // MARK: - 늘리는 경우

    func testExtendsByTheElapsedTime() {
        let saved = end.addingTimeInterval(12 * 60)
        XCTAssertEqual(SessionExtension.extraSeconds(originalEnd: end, savedAt: saved), 12 * 60)
        XCTAssertEqual(SessionExtension.extendedEnd(originalEnd: end, savedAt: saved), saved)
    }

    /// 시트를 띄워 놓고 자리를 비웠을 수 있다. 상한이 없으면 하룻밤이 통째로 들어간다.
    func testExtensionIsCappedAtNinetyMinutes() {
        let saved = end.addingTimeInterval(10 * 60 * 60)
        XCTAssertEqual(SessionExtension.extraSeconds(originalEnd: end, savedAt: saved), 90 * 60)
        XCTAssertEqual(
            SessionExtension.extendedEnd(originalEnd: end, savedAt: saved),
            end.addingTimeInterval(90 * 60)
        )
    }

    func testCapMatchesOneDialTurn() {
        XCTAssertEqual(SessionExtension.maximumExtraSeconds, TimerEngine.maximumMinutes * 60)
    }

    // MARK: - 실제 집중 시간

    /// 일시정지가 있었던 세션은 `actualSeconds` 가 `endAt - startAt` 보다 짧다.
    /// 종료 시각으로 다시 계산하면 멈춰 있던 시간까지 집중한 것으로 잡힌다.
    func testActualSecondsAddsToTheOriginalRatherThanRecomputing() {
        // 25분짜리 계획인데 10분 쉬어서 실제로는 15분만 집중한 세션
        let paused = SessionRecord(
            id: UUID(),
            startAt: end.addingTimeInterval(-25 * 60),
            endAt: end,
            plannedSeconds: 25 * 60,
            actualSeconds: 15 * 60,
            isCompleted: true,
            memo: nil
        )

        let saved = end.addingTimeInterval(5 * 60)
        XCTAssertEqual(
            SessionExtension.extendedActualSeconds(original: paused, savedAt: saved),
            20 * 60,
            "15분 + 5분이어야 한다. 종료 시각으로 다시 계산하면 30분이 된다"
        )
    }

    func testActualSecondsUnchangedWhenNothingToExtend() {
        let session = record(actualSeconds: 1500, endAt: end)
        XCTAssertEqual(
            SessionExtension.extendedActualSeconds(original: session, savedAt: end),
            1500
        )
    }
}
