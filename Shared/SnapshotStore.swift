import Foundation
import FocusCore

/// §5·§8.1 위젯이 읽는 통계 스냅샷의 보관소.
///
/// 앱이 쓰고 위젯이 읽는다. 두 타겟이 **같은 키와 같은 인코딩**을 써야 하므로
/// `Shared/` 에 두고 양쪽에 함께 컴파일한다. 한쪽만 고치면 위젯이 조용히 0 을
/// 그리기 시작하는데, 크래시가 아니라서 한참 모른다.
enum SnapshotStore {

    private static let key = "stats.snapshot"

    /// 읽기는 절대 실패하지 않는다. 값이 없거나 깨졌으면 `zero` 다.
    ///
    /// 위젯 익스텐션에서 던지거나 죽으면 사용자에게는 그냥 빈 칸으로 보인다.
    /// 그럴 바에는 0 이라도 정상적인 모양으로 그리는 편이 낫다.
    static func load() -> StatsSnapshot {
        guard let data = AppGroup.defaults.data(forKey: key),
              let snapshot = try? JSONDecoder().decode(StatsSnapshot.self, from: data) else {
            return .zero
        }
        return snapshot
    }

    static func save(_ snapshot: StatsSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        AppGroup.defaults.set(data, forKey: key)
    }
}
