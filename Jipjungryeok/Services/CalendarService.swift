import Foundation
import Observation
import EventKit
import FocusCore

/// §7 iPhone 캘린더 연동.
///
/// **쓰기 전용 권한만 요청한다** (`requestWriteOnlyAccessToEvents`). 읽기 권한은
/// 필요 없고, 심사·프라이버시에서도 불리하다.
///
/// **전용 "집중" 캘린더는 만들지 않는다. 기본 캘린더에만 기록한다.**
/// 전용 캘린더를 유지하려면 매번 기존 것을 찾아내야 하는데, 그 조회
/// (`calendar(withIdentifier:)`, `calendars(for:)`)가 쓰기 전용 권한에서 막힐 수 있다.
/// 막히면 세션마다 "집중" 캘린더가 새로 생겨 사용자 캘린더 목록이 오염된다.
/// 조회가 아예 필요 없는 구조로 바꿔서 그 실패 모드를 없앴다.
///
/// 대신 집중 세션이 사용자의 일반 일정과 같은 캘린더에 섞인다. 이벤트 제목의
/// `🎯` 접두어가 유일한 구분 수단이다 (§7).
@MainActor
@Observable
final class CalendarService {

    private(set) var authorizationStatus: EKAuthorizationStatus

    @ObservationIgnored private let eventStore = EKEventStore()

    init() {
        authorizationStatus = EKEventStore.authorizationStatus(for: .event)
    }

    /// 쓰기 전용이든 전체든, 이벤트를 만들 수 있는 상태인지.
    var canWrite: Bool {
        authorizationStatus == .writeOnly || authorizationStatus == .fullAccess
    }

    var isDenied: Bool {
        authorizationStatus == .denied || authorizationStatus == .restricted
    }

    // MARK: - 권한

    /// §4.3 — 설정에서 캘린더 기록을 **켤 때** 불린다.
    @discardableResult
    func requestAccess() async -> Bool {
        if canWrite { return true }

        let granted = (try? await eventStore.requestWriteOnlyAccessToEvents()) ?? false
        authorizationStatus = EKEventStore.authorizationStatus(for: .event)
        return granted && canWrite
    }

    func refreshAuthorization() {
        authorizationStatus = EKEventStore.authorizationStatus(for: .event)
    }

    // MARK: - 기록

    /// 세션을 캘린더에 기록하고 `eventIdentifier` 를 돌려준다.
    ///
    /// 실패하면 `nil`. 호출한 쪽은 세션 저장을 정상 진행하고 재시도 큐에 넣는다 (§7).
    /// **사용자에게 모달을 띄우지 않는다** — 캘린더는 부가 기능이고, 타이머는 멀쩡하다.
    func record(_ record: SessionRecord) -> String? {
        guard canWrite else { return nil }
        // 기본 캘린더가 없을 수 있다(쓰기 가능한 캘린더가 하나도 없는 계정 구성).
        // 그 경우 nil 을 돌려주면 호출한 쪽이 재시도 큐에 넣는다.
        guard let calendar = eventStore.defaultCalendarForNewEvents else { return nil }

        let event = EKEvent(eventStore: eventStore)
        event.title = CalendarEventFormat.eventTitle(for: record)
        event.startDate = record.startAt
        event.endDate = record.endAt
        event.calendar = calendar
        // §7 — 알람은 붙이지 않는다. 이미 끝난 일에 알람이 울리면 안 된다.
        event.alarms = nil
        // 세션 직후 받은 한 줄 메모. 없으면 nil 이다.
        event.notes = CalendarEventFormat.eventNotes(for: record)

        do {
            try eventStore.save(event, span: .thisEvent, commit: true)
            return event.eventIdentifier
        } catch {
            return nil
        }
    }
}
