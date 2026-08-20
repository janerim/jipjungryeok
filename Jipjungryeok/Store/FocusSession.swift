import Foundation
import SwiftData
import FocusCore

/// §5 저장되는 세션 1건.
///
/// SwiftData 에 묶인 클래스라 `FocusCore` 가 아니라 앱 타깃에 둔다.
/// 엔진과 통계 계산은 이걸 모르고, 값 타입인 `SessionRecord` 만 주고받는다.
@Model
final class FocusSession {

    @Attribute(.unique) var id: UUID

    /// 세션 시작 절대시각. **모든 통계의 날짜 판정 기준이다** (§4.2).
    var startAt: Date

    /// 종료(완료 또는 중지) 절대시각
    var endAt: Date

    var plannedSeconds: Int

    /// 실제 집중한 시간. 일시정지 구간은 빠져 있다.
    var actualSeconds: Int

    /// 끝까지 갔으면 `true`, 중도 중지면 `false`
    var isCompleted: Bool

    /// EventKit 이벤트 식별자. 캘린더 기록(§7, M4)이 성공해야 채워진다.
    var calendarEventID: String?

    init(record: SessionRecord, calendarEventID: String? = nil) {
        self.id = record.id
        self.startAt = record.startAt
        self.endAt = record.endAt
        self.plannedSeconds = record.plannedSeconds
        self.actualSeconds = record.actualSeconds
        self.isCompleted = record.isCompleted
        self.calendarEventID = calendarEventID
    }

    var record: SessionRecord {
        SessionRecord(
            id: id,
            startAt: startAt,
            endAt: endAt,
            plannedSeconds: plannedSeconds,
            actualSeconds: actualSeconds,
            isCompleted: isCompleted
        )
    }

    /// 같은 `id` 의 세션을 덮어쓴다.
    /// 워치에서 올라온 세션을 upsert 할 때도 이 경로를 쓴다 (§8-1-4).
    func apply(_ record: SessionRecord) {
        startAt = record.startAt
        endAt = record.endAt
        plannedSeconds = record.plannedSeconds
        actualSeconds = record.actualSeconds
        isCompleted = record.isCompleted
    }
}
