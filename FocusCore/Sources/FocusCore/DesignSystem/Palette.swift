import SwiftUI

/// §10 색 테마.
///
/// 원래 기획서는 테마 선택을 만들지 않기로 했었다(§2). 그 판단을 뒤집은 이유는 §10 에
/// 적어 두었다 — 요약하면, 화면 대부분이 다이얼이라는 거대한 단색 덩어리라서 색이
/// 곧 앱의 인상이고, 그 인상을 하나로 못박을 근거가 약했다.
public enum PaletteTheme: String, CaseIterable, Codable, Sendable {

    /// 따뜻한 크림 배경 + 짙은 잉크. 종이 위에 쓰는 느낌.
    case paper

    /// 옅은 세이지 배경 + 짙은 포레스트.
    case sage

    /// 거의 흰 배경 + 거의 검정. 대비가 가장 높다.
    case mono

    public static let `default`: PaletteTheme = .paper

    public var displayName: String {
        switch self {
        case .paper: "종이"
        case .sage:  "세이지"
        case .mono:  "모노"
        }
    }

    /// Asset Catalog 의 Color Set 이름 앞에 붙는다 (`paperBackground` 등).
    func assetName(_ token: String) -> String {
        rawValue + token.prefix(1).uppercased() + token.dropFirst()
    }
}

/// §10 디자인 토큰.
///
/// 실제 색값은 `Shared/Colors.xcassets` 의 Color Set 에 **테마별로 라이트/다크 두 벌씩**
/// 들어 있고, 여기서는 이름만 조립한다. 코드 어디에서도 하드코딩된 hex 나
/// `.gray` 같은 시스템 색을 직접 쓰지 않는다.
///
/// Color Set 은 앱 타겟과 위젯 익스텐션 타겟 양쪽의 소스에 포함되어 있으므로
/// (`project.yml` 의 `- path: Shared`), 어느 번들에서 불려도 `.main` 에서 해석된다.
///
/// 라이트/다크는 여전히 **시스템 설정을 그대로 따른다.** `.preferredColorScheme` 을
/// 지정하지 않는다. 사용자가 고르는 것은 색 계열이지 밝기가 아니다.
public enum Palette {

    /// 지금 적용된 테마.
    ///
    /// `FocusCore` 는 App Group 을 모르므로(순수성 규칙) 값을 스스로 읽지 않는다.
    /// 앱과 위젯이 각자 시작할 때 저장된 값을 여기에 넣어 준다.
    ///
    /// 이 값을 바꾼 뒤에는 화면을 다시 그려야 한다 — 앱은 `RootView` 를 테마로
    /// `.id()` 해서 통째로 새로 만든다.
    nonisolated(unsafe) public static var theme: PaletteTheme = .default

    /// 전체 배경
    public static var background: Color { color("background") }

    /// 다이얼 채움, 주요 텍스트, 차트 막대
    public static var ink: Color { color("ink") }

    /// 눈금 라벨, 보조 텍스트
    public static var inkSecondary: Color { color("inkSecondary") }

    /// 카드 테두리, 구분선
    public static var stroke: Color { color("stroke") }

    /// 다이얼 드래그 핸들
    public static var handle: Color { color("handle") }

    /// 상태 점
    public static var accent: Color { color("accent") }

    private static func color(_ token: String) -> Color {
        Color(theme.assetName(token), bundle: .main)
    }
}
