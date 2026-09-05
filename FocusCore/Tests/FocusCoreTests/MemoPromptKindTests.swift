import XCTest
@testable import FocusCore

/// §6-4 · §6-6 회고 시트가 무엇을 묻는지.
final class MemoPromptKindTests: XCTestCase {

    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)

    private func record(completed: Bool) -> SessionRecord {
        SessionRecord(
            id: UUID(),
            startAt: t0,
            endAt: t0.addingTimeInterval(600),
            plannedSeconds: 1500,
            actualSeconds: 600,
            isCompleted: completed
        )
    }

    func testCompletedRecordAsksWhatYouDid() {
        let kind = MemoPromptKind(record: record(completed: true))
        XCTAssertEqual(kind, .completed)
        XCTAssertEqual(kind.placeholder, "무엇을 했나요?")
        XCTAssertEqual(kind.title(minutes: 25), "25분 집중 완료")
    }

    /// "무엇을 했나요" 는 뭔가 해냈다는 전제가 깔린 질문이라, 회의에 불려 가
    /// 멈춘 사람에게는 답할 말이 없다.
    func testStoppedRecordAsksWhyYouStopped() {
        let kind = MemoPromptKind(record: record(completed: false))
        XCTAssertEqual(kind, .stopped)
        XCTAssertEqual(kind.placeholder, "왜 멈췄나요?")
        XCTAssertEqual(kind.title(minutes: 12), "12분에서 중단")
    }

    /// 두 시트(`MemoSheet`, `MemoEditSheet`)가 같은 질문을 써야 한다.
    /// 문구를 화면에 흩어 두면 한쪽만 바뀐다.
    func testKindIsDerivedFromRecordAlone() {
        XCTAssertEqual(MemoPromptKind(record: record(completed: true)), .completed)
        XCTAssertEqual(MemoPromptKind(record: record(completed: false)), .stopped)
    }
}
