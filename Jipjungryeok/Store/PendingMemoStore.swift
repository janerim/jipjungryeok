import Foundation
import FocusCore

/// 메모를 아직 못 받은 세션 (§4.1 확장).
///
/// 세션은 백그라운드에서 끝날 수 있다. 그때는 물어볼 화면이 없으므로 여기에 적어 두고
/// **다음에 앱을 열 때 한 번** 묻는다.
///
/// 대기 중인 세션은 언제나 최대 한 건이다. 새 세션이 끝나면 앞의 것은 메모 없이
/// 확정된다 — 안 그러면 그 세션이 캘린더에 영영 올라가지 않는다.
struct PendingMemo: Codable, Equatable {
    let sessionID: UUID
    let finishedAt: Date
}

enum PendingMemoStore {

    private static let key = "memo.pending"

    static func load() -> PendingMemo? {
        guard let data = AppGroup.defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(PendingMemo.self, from: data)
    }

    static func save(_ pending: PendingMemo) {
        guard let data = try? JSONEncoder().encode(pending) else { return }
        AppGroup.defaults.set(data, forKey: key)
    }

    static func clear() {
        AppGroup.defaults.removeObject(forKey: key)
    }
}
