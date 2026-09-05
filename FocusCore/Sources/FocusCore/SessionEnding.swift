import Foundation

/// 세션이 **어떻게** 끝났는지 (§6-4, §6-7).
///
/// 끝난 세션 자체(`SessionRecord`)만으로는 이걸 알 수 없다. `isCompleted == false` 는
/// "중지 버튼을 눌렀다" 와 "다이얼을 돌려 새 시간을 맞췄다" 를 구분하지 못하는데,
/// 앞은 사유를 물어야 하고 뒤는 물으면 안 된다. 시간을 다시 맞추는 손동작 한가운데에
/// 시트가 뜨면 그건 방해다.
///
/// 순수 값이라 여기 둔다. 이 판단이 조용히 틀어지면 회고가 안 뜨거나(기록이 사라진 것처럼
/// 보인다) 엉뚱한 데서 뜨는데, 둘 다 화면을 띄워 봐야만 드러나는 종류의 버그다.
public enum SessionEnding: Equatable, Sendable {

    /// 계획한 시간을 채웠다.
    ///
    /// - Parameter endedWhileActive: 1초 타이머가 잡아낸 완료인지. 앱이 꺼져 있거나
    ///   백그라운드에 있는 동안 끝나 뒤늦게 정리하는 경우에는 `false` 다 (§6-7).
    case completed(endedWhileActive: Bool)

    /// 사용자가 중지를 눌렀다 (§6-4).
    case stopped

    /// 다이얼을 돌려 새 시간을 맞추면서 밀려났다 (§4.1).
    case replaced

    /// 회고를 물어볼 것인지.
    ///
    /// 중지도 묻는다. 예전에는 "2분 만에 접은 세션에 무엇을 했나요는 잡음" 이라고 보고
    /// 묻지 않았는데, 실제로는 회의에 불려 가느라 멈추는 경우가 흔했고 그때 남길 곳이
    /// 없었다. 다만 묻는 말이 다르다 — `MemoPromptKind` 참고.
    public var asksMemo: Bool {
        switch self {
        case .completed, .stopped: true
        case .replaced: false
        }
    }

    /// §6-7 회고를 저장한 시각까지 세션을 늘려도 되는지.
    ///
    /// **중지한 세션은 늘리지 않는다.** 연장의 전제는 "시간이 다 됐는데도 계속 일하고
    /// 있었다" 인데, 중지는 정반대로 그만두겠다는 뜻이다. 사유를 적는 동안 흐른 시간을
    /// 집중 시간에 더하면 자리를 뜬 시간이 기록에 들어간다.
    public var allowsExtension: Bool {
        guard case .completed(let endedWhileActive) = self else { return false }
        return endedWhileActive
    }
}
