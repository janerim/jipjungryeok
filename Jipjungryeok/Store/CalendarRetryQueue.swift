import Foundation
import FocusCore

/// §7 캘린더 기록에 실패한 세션을 다음 실행 때 다시 시도하기 위한 큐.
///
/// 세션 자체는 이미 SwiftData 에 저장돼 있으므로 여기에는 **id 만** 담는다.
/// 세션 내용을 복제해 두면 두 벌이 어긋날 여지가 생긴다.
///
/// 실패해도 큐에 남긴다. 권한을 나중에 허용하거나 iCloud 가 돌아오면 그때 성공하므로
/// 매 실행마다 한 번씩 재시도하는 편이 스스로 복구된다. 대신 무한정 쌓이지 않도록
/// 최근 것 위주로 잘라 둔다 — 오래된 실패는 사용자도 이미 잊었다.
enum CalendarRetryQueue {

    private static let key = "calendar.retry.pending"

    /// 보관할 최대 개수. 넘으면 오래된 것부터 버린다.
    static let capacity = 20

    static func pending() -> [UUID] {
        let raw = AppGroup.defaults.stringArray(forKey: key) ?? []
        return raw.compactMap(UUID.init(uuidString:))
    }

    static func add(_ id: UUID) {
        var ids = pending()
        guard !ids.contains(id) else { return }

        ids.append(id)
        if ids.count > capacity {
            ids.removeFirst(ids.count - capacity)
        }
        write(ids)
    }

    static func remove(_ id: UUID) {
        write(pending().filter { $0 != id })
    }

    static func clear() {
        AppGroup.defaults.removeObject(forKey: key)
    }

    private static func write(_ ids: [UUID]) {
        AppGroup.defaults.set(ids.map(\.uuidString), forKey: key)
    }
}
