import Foundation
import Combine
import EventKit
import FocusCore

/// §7 iPhone 캘린더 연동.
///
/// `main` 은 **쓰기 전용 권한만 요청한다** (`requestWriteOnlyAccessToEvents`). 읽기 권한은
/// 필요 없고, 심사·프라이버시에서도 불리하다.
///
/// `ios15` 브랜치는 그럴 수 없다. 쓰기 전용 권한이 iOS 17 에 생겼고, 그 전에는
/// `requestAccess(to:)` 하나로 읽기·쓰기를 한꺼번에 받는다. 그래서 권한 상태가
/// `.authorized` 하나뿐이고, 기록과 캘린더 선택이 같은 권한으로 된다.
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
final class CalendarService: ObservableObject {

    @Published private(set) var authorizationStatus: EKAuthorizationStatus

    private let eventStore = EKEventStore()

    init() {
        authorizationStatus = EKEventStore.authorizationStatus(for: .event)
    }

    /// 이벤트를 만들 수 있는 상태인지.
    ///
    /// `.authorized` 는 iOS 17 SDK 에서 deprecated 경고가 나지만 iOS 15 에는 이것뿐이다.
    /// iOS 17 의 `.fullAccess` 와 raw value 가 같아서 iOS 17 시뮬레이터에서도 맞게 판정된다.
    var canWrite: Bool {
        authorizationStatus == .authorized
    }

    /// 캘린더 **목록을 읽을 수 있는** 상태인지.
    ///
    /// `main` 에서는 쓰기 전용 권한과 구분하느라 따로 있다. iOS 15 에서는 권한이 하나라
    /// `canWrite` 와 같다. 호출하는 쪽을 `main` 과 같게 두려고 이름을 남긴다.
    var canListCalendars: Bool {
        canWrite
    }

    var isDenied: Bool {
        authorizationStatus == .denied || authorizationStatus == .restricted
    }

    // MARK: - 권한

    /// §4.3 — 설정에서 캘린더 기록을 **켤 때** 불린다.
    @discardableResult
    func requestAccess() async -> Bool {
        if canWrite { return true }

        let granted = (try? await eventStore.requestAccess(to: .event)) ?? false
        authorizationStatus = EKEventStore.authorizationStatus(for: .event)
        return granted && canWrite
    }

    /// §4.3 — 사용자가 "캘린더 선택" 을 누를 때만 부른다.
    ///
    /// iOS 15 에서는 기록 권한과 같은 권한이라 `requestAccess()` 로 충분하다.
    @discardableResult
    func requestFullAccess() async -> Bool {
        await requestAccess()
    }

    func refreshAuthorization() {
        authorizationStatus = EKEventStore.authorizationStatus(for: .event)
    }

    // MARK: - 캘린더 목록

    /// §4.3 설정에서 고를 수 있는 캘린더.
    ///
    /// **쓰기 전용 권한에서도 이 조회는 동작한다** — 시뮬레이터에서 확인했다
    /// (`status=writeOnly` 인 상태로 `calendars(for:)` 가 목록을 돌려줬다).
    /// 그래서 캘린더 선택을 위해 전체 접근 권한으로 올릴 필요가 없다.
    ///
    /// 구독 캘린더나 생일 달력처럼 쓸 수 없는 것은 걸러 낸다. 목록에 보였는데
    /// 고르고 나서 기록이 안 되는 것이 제일 헷갈린다.
    func writableCalendars() -> [EKCalendar] {
        guard canListCalendars else { return [] }
        return eventStore.calendars(for: .event)
            .filter(\.allowsContentModifications)
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    /// 식별자로 캘린더 이름을 찾는다. 못 찾으면 `nil` — 설정 화면이 "기본 캘린더" 로 표시한다.
    func calendarTitle(for identifier: String?) -> String? {
        guard let identifier, canWrite else { return nil }
        return eventStore.calendar(withIdentifier: identifier)?.title
    }

    /// 고른 캘린더가 사라졌거나 쓸 수 없게 됐으면 기본 캘린더로 되돌아간다.
    /// 기록을 통째로 포기하는 것보다 낫다 — 사용자는 어딘가에 남기를 원했다.
    private func targetCalendar(_ identifier: String?) -> EKCalendar? {
        if let identifier,
           let picked = eventStore.calendar(withIdentifier: identifier),
           picked.allowsContentModifications {
            return picked
        }
        return eventStore.defaultCalendarForNewEvents
    }

    // MARK: - 기록

    /// 세션을 캘린더에 기록하고 `eventIdentifier` 를 돌려준다.
    ///
    /// 실패하면 `nil`. 호출한 쪽은 세션 저장을 정상 진행하고 재시도 큐에 넣는다 (§7).
    /// **사용자에게 모달을 띄우지 않는다** — 캘린더는 부가 기능이고, 타이머는 멀쩡하다.
    func record(_ record: SessionRecord, in identifier: String?) -> String? {
        guard canWrite else { return nil }
        // 쓸 캘린더가 없을 수 있다(쓰기 가능한 캘린더가 하나도 없는 계정 구성).
        // 그 경우 nil 을 돌려주면 호출한 쪽이 재시도 큐에 넣는다.
        guard let calendar = targetCalendar(identifier) else { return nil }

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

    /// §4.2-3 기록 화면에서 메모를 고쳤을 때, 이미 만든 이벤트의 notes 도 맞춘다.
    ///
    /// **쓰기 전용 권한에서는 되지 않는다.** 이벤트를 고치려면 먼저 꺼내와야 하는데
    /// (`event(withIdentifier:)`) 그게 읽기이기 때문이다. 그 경우 조용히 `false` 를
    /// 돌려주고 앱 안의 기록만 고친다 — 메모 수정을 막을 이유는 없다.
    /// §6-6 이 "캘린더 기록은 메모가 정해진 뒤에" 로 피해 갔던 문제가 여기서는
    /// 피할 수 없는 형태로 돌아온 것이다. 이미 만든 이벤트를 고치는 일이니까.
    ///
    /// 재시도 큐에 넣지 않는다. 큐는 "세션이 캘린더에 아예 없다" 를 고치는 장치이고,
    /// 여기는 이벤트가 이미 있는데 notes 만 옛것인 상태다. 다음 수정 때 다시 맞춰진다.
    @discardableResult
    func updateNotes(eventID: String, notes: String?) -> Bool {
        guard canListCalendars,
              let event = eventStore.event(withIdentifier: eventID) else { return false }

        event.notes = notes
        do {
            try eventStore.save(event, span: .thisEvent, commit: true)
            return true
        } catch {
            return false
        }
    }
}
