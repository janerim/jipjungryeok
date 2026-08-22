import Foundation
import Observation
import FocusCore

/// §4.3 설정.
///
/// 기획서의 "설정을 만들지 않는다"(§2) 원칙이 살아 있다. 여기 있는 둘은 각각
/// 근거가 있는 예외다 — 캘린더는 권한을 사용자가 켜야 하고(§4.3), 색 테마는 §10 참고.
/// 알림음·세션 종류 같은 것을 추가하고 싶어지면 §3 의 제외 목록을 먼저 볼 것.
@MainActor
@Observable
final class AppSettings {

    private static let calendarEnabledKey = "settings.calendar.enabled"

    /// §7 캘린더 자동 기록 여부.
    ///
    /// 기본값은 꺼짐이다. 권한을 묻는 시점이 사용자가 직접 켤 때여야 하기 때문이다(§4.3).
    /// 끄더라도 **이미 만들어진 과거 이벤트는 지우지 않는다** — 사용자의 캘린더이지
    /// 우리 데이터가 아니다.
    var isCalendarEnabled: Bool {
        didSet {
            AppGroup.defaults.set(isCalendarEnabled, forKey: Self.calendarEnabledKey)
        }
    }

    /// §10 색 테마.
    ///
    /// 앱과 위젯이 같은 값을 봐야 하므로 App Group 에 둔다. `Palette` 는 App Group 을
    /// 모르므로(FocusCore 순수성) 값을 여기서 넣어 준다.
    var theme: PaletteTheme {
        didSet {
            ThemeStore.save(theme)
            Palette.theme = theme
        }
    }

    init() {
        isCalendarEnabled = AppGroup.defaults.bool(forKey: Self.calendarEnabledKey)
        theme = ThemeStore.apply()
    }
}
