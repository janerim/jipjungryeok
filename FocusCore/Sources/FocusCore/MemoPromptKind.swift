import Foundation

/// 회고 시트가 무엇을 묻는지 (§6-4, §6-6).
///
/// 끝까지 간 세션과 중간에 멈춘 세션은 물어볼 말이 다르다. "무엇을 했나요" 는
/// 뭔가 해냈다는 전제가 깔린 질문이라, 회의에 불려 가 멈춘 사람에게는 답할 말이 없다.
///
/// 문구를 화면이 아니라 여기 두는 이유는 두 곳(`MemoSheet`, `MemoEditSheet`)이
/// 같은 말을 써야 하기 때문이다. 나중에 고칠 때 한쪽만 바뀌면 같은 메모를 쓰는
/// 자리인데 다른 질문이 뜬다. `CalendarEventFormat` 이 이벤트 제목을 한 곳에 모아
/// 둔 것과 같은 이유다.
public enum MemoPromptKind: Equatable, Sendable {

    /// 계획한 시간을 채운 세션.
    case completed

    /// 중도 중지한 세션.
    case stopped

    public init(record: SessionRecord) {
        self = record.isCompleted ? .completed : .stopped
    }

    /// 입력 칸의 placeholder. 이 한 줄이 사실상 질문이다.
    public var placeholder: String {
        switch self {
        case .completed: "무엇을 했나요?"
        case .stopped:   "왜 멈췄나요?"
        }
    }

    /// 시트 제목.
    ///
    /// - Parameter minutes: 실제로 집중한 분.
    public func title(minutes: Int) -> String {
        switch self {
        case .completed: "\(minutes)분 집중 완료"
        case .stopped:   "\(minutes)분에서 중단"
        }
    }
}
