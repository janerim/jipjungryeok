import Foundation

/// §7 캘린더 이벤트 표기.
///
/// EventKit 을 모르는 순수 문자열 조립이라 여기 둔다. 이벤트 제목이 조용히 바뀌면
/// 이미 만들어진 과거 이벤트와 새 이벤트가 달라 보이므로 테스트로 못박아 둔다.
public enum CalendarEventFormat {

    /// §7 전용 캘린더 이름. 사용자의 캘린더 앱에 이 이름으로 나타난다.
    public static let calendarName = "집중"

    /// 이벤트 제목. 완료면 `🎯 집중 25분`, 중도 중지면 `🎯 집중 25분 (중단)`.
    ///
    /// 분은 `plannedSeconds` 가 아니라 **실제 집중한 시간**에서 뽑는다.
    /// 25분을 맞춰놓고 7분 만에 멈춘 세션이 캘린더에 "25분" 으로 남으면 안 된다.
    /// 완료된 세션은 둘이 같으므로 차이가 없다.
    public static func eventTitle(for record: SessionRecord) -> String {
        let minutes = TimeDisplay.minutes(record.actualSeconds)
        let base = "🎯 \(calendarName) \(minutes)분"
        return record.isCompleted ? base : "\(base) (중단)"
    }
}
