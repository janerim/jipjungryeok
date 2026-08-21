import Foundation
import Observation
import FocusCore

/// 끝난 세션 1건을 처리하는 지점.
///
/// 저장(§5)과 캘린더 기록(§7)을 함께 묶는다. 타이머는 이 하나만 부르면 되고,
/// EventKit 을 알 필요가 없다. 앱 시작 시 재시도(§7)도 같은 경로를 쓴다 —
/// 타이머와 무관한 일이라 `TimerViewModel` 에 둘 자리가 아니다.
@MainActor
@Observable
final class SessionRecorder {

    @ObservationIgnored let store: SessionStore
    @ObservationIgnored private let calendar: CalendarService
    @ObservationIgnored private let settings: AppSettings

    init(store: SessionStore, calendar: CalendarService, settings: AppSettings) {
        self.store = store
        self.calendar = calendar
        self.settings = settings
    }

    /// 세션을 저장하고, 설정이 켜져 있으면 캘린더에도 기록한다.
    ///
    /// 캘린더 기록이 실패해도 **세션 저장은 그대로 유지된다** (§7).
    /// 실패한 건은 재시도 큐에 넣고 조용히 넘어간다.
    func finish(_ record: SessionRecord) {
        store.save(record)
        writeToCalendar(record)
    }

    /// §7 — 앱 시작 시 1회, 지난번에 실패한 것들을 다시 시도한다.
    ///
    /// 그 사이에 권한을 허용했거나 네트워크가 돌아왔으면 여기서 성공한다.
    func retryPendingCalendarWrites() {
        guard settings.isCalendarEnabled, calendar.canWrite else { return }

        for id in CalendarRetryQueue.pending() {
            guard let record = store.record(with: id) else {
                // 세션이 지워졌으면 재시도할 대상이 없다.
                CalendarRetryQueue.remove(id)
                continue
            }
            if let eventID = calendar.record(record) {
                store.attachCalendarEvent(eventID, to: id)
                CalendarRetryQueue.remove(id)
            }
            // 또 실패하면 큐에 남겨 다음 실행 때 다시 시도한다.
        }
    }

    /// §4.3 데이터 초기화. 세션이 사라지므로 재시도 큐도 함께 비운다.
    ///
    /// **이미 만들어진 캘린더 이벤트는 지우지 않는다** (§7). 사용자의 캘린더이지
    /// 우리가 마음대로 지울 데이터가 아니다.
    func resetAllData() {
        store.deleteAll()
        CalendarRetryQueue.clear()
    }

    // MARK: -

    private func writeToCalendar(_ record: SessionRecord) {
        // 설정이 꺼져 있으면 기록하지 않는다. 재시도 큐에도 넣지 않는다 —
        // 실패가 아니라 사용자가 원하지 않은 것이다 (§7).
        guard settings.isCalendarEnabled else { return }

        guard calendar.canWrite, let eventID = calendar.record(record) else {
            CalendarRetryQueue.add(record.id)
            return
        }
        store.attachCalendarEvent(eventID, to: record.id)
    }
}
