import Foundation
import Observation
import FocusCore

/// §4.3 설정.
///
/// 기획서의 "설정을 만들지 않는다"(§2) 원칙 때문에 저장되는 값은 이것 하나뿐이다.
/// 테마·알림음·세션 종류 같은 것을 여기 추가하고 싶어지면 §3 의 제외 목록을 먼저 볼 것.
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

    init() {
        isCalendarEnabled = AppGroup.defaults.bool(forKey: Self.calendarEnabledKey)
    }
}
