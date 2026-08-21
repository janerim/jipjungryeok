import Foundation
import FocusCore

/// §5 진행 중 상태를 App Group `UserDefaults` 에 보관한다.
///
/// 앱이 강제 종료(스와이프 kill)돼도 세션이 이어져야 한다 (§12).
/// SwiftData 를 쓰지 않는 이유는 §5 가 정한 대로다 — 세션이 **끝나야** 기록이고,
/// 진행 중인 것은 언제든 사라질 수 있는 가벼운 값이다.
///
/// 저장되는 것은 시작 시각과 누적 정지 시간뿐이다. 남은 시간은 저장하지 않는다.
/// 복원 시점에 절대시각으로 다시 계산하므로(§6-1), 앱이 죽어 있던 동안에도 값이 맞는다.
enum RunningStateStore {

    private static let key = "running.state"

    static func save(_ state: RunningState?) {
        guard let state else {
            clear()
            return
        }
        do {
            let data = try JSONEncoder().encode(state)
            AppGroup.defaults.set(data, forKey: key)
        } catch {
            // 저장에 실패해도 진행 중인 세션 자체는 멀쩡하다.
            // 앱이 죽었을 때 복구가 안 될 뿐이다.
            assertionFailure("진행 상태 저장 실패: \(error)")
        }
    }

    static func load() -> RunningState? {
        guard let data = AppGroup.defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(RunningState.self, from: data)
    }

    static func clear() {
        AppGroup.defaults.removeObject(forKey: key)
    }
}
