import Foundation

/// 끝난 세션 1건. `TimerEngine` 이 내놓는 결과값이다.
///
/// M2 에서 SwiftData `@Model final class FocusSession` (§5) 으로 옮겨 저장하는데,
/// 그 변환은 앱 타깃의 SessionStore 가 맡는다. **`FocusCore` 는 SwiftData 에 의존하지 않는다** —
/// 타이머 로직을 시뮬레이터 없이 순수하게 테스트할 수 있어야 하기 때문이다.
///
/// `FocusSession` 대비 빠진 필드는 `calendarEventID` 하나뿐이고, 그건 저장 이후
/// 캘린더 기록(§7)이 성공해야 채워지는 값이라 엔진의 관심사가 아니다.
public struct SessionRecord: Equatable, Identifiable, Sendable {

    public let id: UUID

    /// 세션 시작 절대시각
    public let startAt: Date

    /// 종료(완료 또는 중지) 절대시각
    public let endAt: Date

    /// 사용자가 다이얼로 설정한 시간
    public let plannedSeconds: Int

    /// 실제 집중한 시간. 일시정지 구간은 빠져 있다.
    public let actualSeconds: Int

    /// 끝까지 갔으면 `true`, 중도 중지면 `false`
    public let isCompleted: Bool

    /// 세션이 끝난 직후 사용자가 남긴 한 줄 메모. 건너뛰면 `nil`.
    ///
    /// 회고 카드(§4.2)와 캘린더 이벤트의 notes(§7)에 함께 쓰인다.
    /// 엔진은 이 값을 만들지 않는다 — 세션이 끝난 뒤 화면에서 붙는다.
    public let memo: String?

    public init(
        id: UUID,
        startAt: Date,
        endAt: Date,
        plannedSeconds: Int,
        actualSeconds: Int,
        isCompleted: Bool,
        memo: String? = nil
    ) {
        self.id = id
        self.startAt = startAt
        self.endAt = endAt
        self.plannedSeconds = plannedSeconds
        self.actualSeconds = actualSeconds
        self.isCompleted = isCompleted
        self.memo = memo
    }
}
