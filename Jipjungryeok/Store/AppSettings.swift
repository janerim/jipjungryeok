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
    private static let calendarIdentifierKey = "settings.calendar.identifier"
    private static let defaultMinutesKey = "settings.timer.defaultMinutes"
    private static let memoPromptKey = "settings.memo.prompt"

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

    /// §7 기록할 캘린더. `nil` 이면 사용자의 기본 캘린더.
    ///
    /// 쓰기 전용 권한에서도 캘린더 목록 조회가 된다는 것을 확인하고 넣은 기능이다.
    /// 전체 접근 권한으로 올릴 필요가 없다.
    ///
    /// 고른 캘린더가 사라지면(계정 삭제 등) 기록을 포기하지 않고 기본 캘린더로
    /// 되돌아간다 — `CalendarService.targetCalendar` 참고.
    var calendarIdentifier: String? {
        didSet {
            AppGroup.defaults.set(calendarIdentifier, forKey: Self.calendarIdentifierKey)
        }
    }

    /// §4.1 다이얼이 처음 가리키는 분.
    ///
    /// 매번 같은 시간으로 시작하는 사람이 많아서 기본값을 고를 수 있게 했다.
    /// 5분 단위인 이유는, 여기서 1분 단위로 맞출 일이 없기 때문이다 —
    /// 그날그날의 미세 조정은 다이얼이 한다.
    /// **`didSet` 안에서 자기 자신에 대입하지 말 것.** `@Observable` 이 저장 프로퍼티를
    /// 계산 프로퍼티로 바꾸기 때문에 setter 가 다시 불려 무한 재귀로 죽는다.
    /// 일반 저장 프로퍼티에서는 재귀하지 않지만 여기서는 다르다.
    /// 그래서 범위 보정은 아래 `setDefaultMinutes(_:)` 가 맡고, 바깥에서는 그것만 쓴다.
    private(set) var defaultMinutes: Int {
        didSet {
            AppGroup.defaults.set(defaultMinutes, forKey: Self.defaultMinutesKey)
        }
    }

    func setDefaultMinutes(_ minutes: Int) {
        defaultMinutes = Self.clampedMinutes(minutes)
    }

    static let minutesStep = 5

    static func clampedMinutes(_ minutes: Int) -> Int {
        min(TimerEngine.maximumMinutes, max(minutesStep, minutes))
    }

    /// §6-6 세션이 끝나면 메모 시트를 띄울지.
    ///
    /// 이 앱에서 유일하게 사용자를 멈춰 세우는 화면이라 끌 수 있어야 한다.
    /// 다만 **끄면 메모를 남길 방법이 없어진다** — 나중에 붙이는 화면이 아직 없다.
    /// 기본값은 켜짐이다.
    var isMemoPromptEnabled: Bool {
        didSet {
            AppGroup.defaults.set(isMemoPromptEnabled, forKey: Self.memoPromptKey)
        }
    }

    init() {
        isCalendarEnabled = AppGroup.defaults.bool(forKey: Self.calendarEnabledKey)
        // 저장된 적이 없으면 false 가 오므로 켜짐을 기본으로 뒤집는다.
        isMemoPromptEnabled = AppGroup.defaults.object(forKey: Self.memoPromptKey) as? Bool ?? true
        calendarIdentifier = AppGroup.defaults.string(forKey: Self.calendarIdentifierKey)

        let stored = AppGroup.defaults.integer(forKey: Self.defaultMinutesKey)
        // 한 번도 저장된 적이 없으면 0 이 온다. 그때는 기획서 기본값 25분이다.
        defaultMinutes = stored == 0 ? 25 : Self.clampedMinutes(stored)

        theme = ThemeStore.apply()
    }
}
