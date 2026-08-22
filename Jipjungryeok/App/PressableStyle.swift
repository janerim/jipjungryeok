import SwiftUI
import FocusCore

/// 눌렀을 때 반응하는 버튼.
///
/// SwiftUI 의 기본 `Button` 은 라벨을 직접 그리면 눌림 상태를 표시해 주지 않는다.
/// 색도 크기도 그대로라 눌린 건지 아닌지 알 수 없고, 저장처럼 한 번뿐인 동작에서는
/// 두 번 누르게 된다.
///
/// 색을 바꾸지 않고 투명도와 크기만 건드린다. 팔레트에 "눌린 상태" 토큰을 새로
/// 만들면 테마 3종마다 그 값을 정해야 하는데, 그만한 값어치가 없다.
struct PressableStyle: ButtonStyle {

    /// 채워진 버튼은 조금 더 눌러도 티가 나야 한다.
    var scale: CGFloat = 0.97

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.55 : 1)
            .scaleEffect(configuration.isPressed ? scale : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

extension View {
    /// 햅틱은 붙이지 않는다. 이 앱에서 햅틱은 다이얼 스냅과 세션 완료의 신호라
    /// (§6-3), 일반 버튼까지 울리면 그 의미가 묽어진다.
    func pressable(scale: CGFloat = 0.97) -> some View {
        buttonStyle(PressableStyle(scale: scale))
    }
}
