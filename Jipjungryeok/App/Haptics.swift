import UIKit

/// §6-3 — 이 앱은 알림음을 쓰지 않는다.
///
/// **햅틱은 다이얼 스냅에만 쓴다.** 세션 완료·중지에는 진동을 주지 않는다.
/// 완료는 "조용히" 가 이 앱의 약속이고(§6-3), 집중이 끝난 순간 손목이나 주머니가
/// 울리는 것은 그 약속과 어긋난다. 백그라운드에서는 무음 배너가, 포그라운드에서는
/// 화면 자체가 이미 끝났다는 것을 말해 준다.
///
/// 다이얼 스냅 햅틱은 남긴다. 1분 단위로 걸렸다는 신호가 없으면 몇 분에 멈췄는지
/// 손끝으로 알 수 없어서, 화면을 계속 봐야 한다.
///
/// UIKit 에 의존하므로 `FocusCore` 가 아니라 앱 타깃에 둔다.
@MainActor
enum Haptics {

    /// 다이얼 1분 스냅마다 (§4.1). 연타되는 자리라 제너레이터를 재사용한다.
    private static let selectionGenerator = UISelectionFeedbackGenerator()

    /// 드래그를 시작할 때 한 번 불러 두면 첫 스냅의 지연이 줄어든다.
    static func prepareSelection() {
        selectionGenerator.prepare()
    }

    static func selection() {
        selectionGenerator.selectionChanged()
    }
}
