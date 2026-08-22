import ActivityKit
import Foundation

/// §8.3 Live Activity 가 주고받는 값.
///
/// 앱이 만들고 위젯 익스텐션이 그리므로 `Shared/` 에 둔다. 두 타겟이 같은 타입을
/// 봐야 하고, 한쪽만 바꾸면 실행 중에 조용히 디코딩이 실패한다.
///
/// **남은 초를 담지 않는다.** 종료 예정 시각만 넘기고 화면이
/// `Text(timerInterval:countsDown:)` 으로 스스로 줄인다. 초마다 갱신을 밀어 넣으면
/// 시스템이 업데이트 예산을 깎고, 앱이 백그라운드에 있는 동안에는 아예 못 민다.
struct FocusActivityAttributes: ActivityAttributes {

    struct ContentState: Codable, Hashable {

        /// 이 세션이 끝날 절대시각. 일시정지 후 재개하면 그만큼 뒤로 밀린다.
        var endDate: Date

        /// 진행 링을 그리기 위한 시작 시각. `endDate` 와 짝을 이룬다.
        var startDate: Date

        /// 일시정지 중이면 그 순간의 남은 초. 진행 중이면 `nil`.
        ///
        /// 멈춰 있는 동안에는 `Text(timerInterval:)` 을 쓸 수 없다 — 시스템 카운트다운은
        /// 멈추지 않는다. 그래서 얼어붙은 값을 따로 실어 보낸다.
        var pausedRemainingSeconds: Int?

        var isPaused: Bool { pausedRemainingSeconds != nil }
    }

    /// 사용자가 다이얼로 정한 시간. 화면에서 "25분 세션" 같은 맥락에 쓴다.
    var plannedMinutes: Int
}
