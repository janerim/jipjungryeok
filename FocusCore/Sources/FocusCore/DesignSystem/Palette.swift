import SwiftUI

/// §10 디자인 토큰.
///
/// 실제 색값은 `Shared/Colors.xcassets` 의 Color Set 에 라이트/다크 두 벌로 들어 있고,
/// 여기서는 이름만 참조한다. 코드 어디에서도 하드코딩된 hex 나 `.gray` 같은
/// 시스템 색을 직접 쓰지 않는다.
///
/// Color Set 은 앱 타겟과 위젯 익스텐션 타겟 양쪽의 소스에 포함되어 있으므로
/// (`project.yml` 의 `- path: Shared`), 어느 번들에서 불려도 `.main` 에서 해석된다.
///
/// 테마 선택 기능은 만들지 않는다. `.preferredColorScheme` 을 지정하지 않고
/// 시스템 설정을 그대로 따른다.
public enum Palette {

    /// 전체 배경. 라이트 `#DDE3F2` / 다크 `#1A1E29`
    public static let background = Color("background", bundle: .main)

    /// 다이얼 채움, 주요 텍스트, 차트 막대. 라이트 `#4A5468` / 다크 `#C9D1E4`
    public static let ink = Color("ink", bundle: .main)

    /// 눈금 라벨, 보조 텍스트. 라이트 `#7A849B` / 다크 `#828CA6`
    public static let inkSecondary = Color("inkSecondary", bundle: .main)

    /// 카드 테두리, 구분선. 라이트 `#B9C2D8` / 다크 `#333B4D`
    public static let stroke = Color("stroke", bundle: .main)

    /// 다이얼 드래그 핸들. 라이트 `#FFFFFF` / 다크 `#E8EDF7`
    public static let handle = Color("handle", bundle: .main)

    /// 상태 점 (초록). 라이트·다크 동일 `#8BD344`
    public static let accent = Color("accent", bundle: .main)
}
