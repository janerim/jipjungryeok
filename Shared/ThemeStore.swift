import Foundation
import FocusCore

/// §10 선택된 색 테마의 보관소.
///
/// 앱이 쓰고 앱과 위젯이 함께 읽는다. `SnapshotStore` 와 같은 이유로 `Shared/` 에 둔다 —
/// 두 타겟이 **같은 키**를 써야 하고, 한쪽만 고치면 위젯 색만 조용히 달라진다.
///
/// `FocusCore.Palette` 가 이 값을 직접 읽지 않는 이유는 순수성 규칙 때문이다.
/// `FocusCore` 는 App Group 을 모른다. 그래서 읽는 쪽이 `apply()` 로 넣어 준다.
enum ThemeStore {

    private static let key = "settings.theme"

    static func load() -> PaletteTheme {
        guard let raw = AppGroup.defaults.string(forKey: key),
              let theme = PaletteTheme(rawValue: raw) else {
            return .default
        }
        return theme
    }

    static func save(_ theme: PaletteTheme) {
        AppGroup.defaults.set(theme.rawValue, forKey: key)
    }

    /// 저장된 테마를 `Palette` 에 적용한다.
    ///
    /// 위젯은 앱과 다른 프로세스라 앱이 넣어 준 값이 오지 않는다. 그릴 때마다
    /// 불러야 홈 화면에서 색이 따로 놀지 않는다.
    @discardableResult
    static func apply() -> PaletteTheme {
        let theme = load()
        Palette.theme = theme
        return theme
    }
}
