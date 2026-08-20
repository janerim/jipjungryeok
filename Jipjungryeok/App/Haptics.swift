import UIKit

/// §6-3 — 이 앱은 알림음을 쓰지 않는다. 피드백은 전부 햅틱이다.
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

    /// 세션 완료 (§6-3)
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    /// 세션 중지 (§4.1 길게 누르기)
    static func warning() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }
}
