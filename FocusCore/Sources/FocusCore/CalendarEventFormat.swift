import Foundation

/// §7 캘린더 이벤트 표기.
///
/// EventKit 을 모르는 순수 문자열 조립이라 여기 둔다. 이벤트 제목이 조용히 바뀌면
/// 이미 만들어진 과거 이벤트와 새 이벤트가 달라 보이므로 테스트로 못박아 둔다.
public enum CalendarEventFormat {

    /// §7 이벤트 제목에 들어가는 라벨.
    ///
    /// 전용 캘린더를 만들지 않으므로(기본 캘린더에 기록한다) 사용자의 일반 일정과
    /// 섞인다. 제목의 `🎯` 와 이 라벨이 집중 세션을 알아보는 유일한 단서다.
    public static let sessionLabel = "집중"

    /// 이벤트 제목. 완료면 `🎯 집중`, 중도 중지면 `🎯 집중 (중단)`.
    ///
    /// **분은 넣지 않는다.** 이벤트에 시작·종료 시각이 이미 들어 있어서 캘린더 앱이
    /// 길이를 알아서 보여준다. 제목에까지 적으면 같은 정보가 두 번 나오고,
    /// 하루치를 펼쳤을 때 제목이 길어 읽기만 나빠진다.
    ///
    /// `(중단)` 은 남긴다. 계획한 시간을 못 채웠다는 사실은 시작·종료 시각만으로는
    /// 드러나지 않는다.
    public static func eventTitle(for record: SessionRecord) -> String {
        let base = "🎯 \(sessionLabel)"
        return record.isCompleted ? base : "\(base) (중단)"
    }

    /// 이벤트 notes. 메모가 없거나 공백뿐이면 `nil`.
    public static func eventNotes(for record: SessionRecord) -> String? {
        normalizedMemo(record.memo)
    }

    /// 저장할 가치가 있는 메모만 남긴다.
    ///
    /// 앞뒤 공백을 털고, 털고 나서 빈 문자열이면 `nil` 이다.
    /// 빈 문자열을 그대로 저장하면 "메모 있음" 과 "없음" 이 구분되지 않아
    /// 회고 카드에 빈 줄이 남는다.
    public static func normalizedMemo(_ memo: String?) -> String? {
        guard let trimmed = memo?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else { return nil }
        return trimmed
    }
}
