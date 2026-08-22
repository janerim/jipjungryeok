import SwiftUI
import FocusCore

/// 눌렀을 때 반응하는 버튼.
///
/// SwiftUI 의 기본 `Button` 은 라벨을 직접 그리면 눌림 상태를 표시해 주지 않는다.
/// 색도 크기도 그대로라 눌린 건지 알 수 없고, 저장처럼 한 번뿐인 동작에서는
/// 두 번 누르게 된다.
///
/// - Important: 배경·여백은 **버튼 라벨 안쪽**에 있어야 한다. 바깥에 붙이면
///   `configuration.label` 에 들어오지 않아 글자만 흐려지고 배경은 그대로다.
///   처음 만들 때 이걸 틀려서 "눌러도 티가 안 난다" 는 소리를 들었다.
struct PressableStyle: ButtonStyle {

    var scale: CGFloat = 0.96

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.5 : 1)
            .scaleEffect(configuration.isPressed ? scale : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

/// 채워진 버튼 — 저장처럼 화면에서 가장 중요한 동작.
///
/// 배경을 스타일이 직접 그린다. 그래야 눌렀을 때 **채움 색 자체를 바꿀 수 있다.**
/// 투명도만 낮추면 배경이 옅어지는 것인지 화면이 흐려진 것인지 구분이 안 간다.
///
/// 눌린 색으로 `inkSecondary` 를 쓴다. 팔레트에 "눌린 상태" 토큰을 새로 만들면
/// 테마 3종마다 값을 정해야 하는데, 이미 한 단계 옅은 토큰이 있으니 그걸 쓴다.
struct FilledButtonStyle: ButtonStyle {

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Palette.background)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(
                RoundedRectangle(cornerRadius: Metrics.cardCornerRadius)
                    .fill(configuration.isPressed ? Palette.inkSecondary : Palette.ink)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

extension View {
    /// 햅틱은 붙이지 않는다. 이 앱에서 햅틱은 다이얼 스냅과 세션 완료의 신호라
    /// (§6-3), 일반 버튼까지 울리면 그 의미가 묽어진다.
    func pressable(scale: CGFloat = 0.96) -> some View {
        buttonStyle(PressableStyle(scale: scale))
    }

    func filledButton() -> some View {
        buttonStyle(FilledButtonStyle())
    }
}
