import Foundation

/// App Group 식별자와 그 안의 공유 저장소 접근 지점 (§1-1, §5).
///
/// 앱 타겟과 위젯 익스텐션이 같은 값을 써야 하므로 `Shared/` 에 두고 두 타겟에
/// 함께 컴파일한다. FocusCore 에 넣지 않는 이유는, 이 값이 플랫폼 독립 로직이 아니라
/// 번들 구성(Capability)에 묶인 값이기 때문이다.
enum AppGroup {

    static let identifier = "group.com.janerim.jipjungryeok"

    /// 진행 중 상태(`RunningState`)와 통계 스냅샷(`StatsSnapshot`)이 들어가는 공유 UserDefaults.
    static var defaults: UserDefaults {
        guard let defaults = UserDefaults(suiteName: identifier) else {
            // App Groups Capability 가 두 타겟 중 한쪽에만 붙으면 여기서 걸린다 (§13-1).
            // project.yml 에서 양쪽 모두 선언하고 있으므로, 이게 뜨면 서명/프로비저닝 쪽 문제다.
            fatalError("App Group '\(identifier)' 에 접근할 수 없습니다. 앱·위젯 타겟 양쪽의 App Groups Capability 와 서명 설정을 확인하세요.")
        }
        return defaults
    }

    /// SwiftData 스토어가 놓일 컨테이너 디렉터리 (M2 에서 사용).
    static var containerURL: URL {
        guard let url = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: identifier) else {
            fatalError("App Group '\(identifier)' 컨테이너를 찾을 수 없습니다.")
        }
        return url
    }
}
