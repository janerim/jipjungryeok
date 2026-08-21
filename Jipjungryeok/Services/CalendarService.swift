import Foundation
import Observation
import EventKit
import FocusCore

/// §7 iPhone 캘린더 연동.
///
/// **쓰기 전용 권한만 요청한다** (`requestWriteOnlyAccessToEvents`). 읽기 권한은
/// 필요 없고, 심사·프라이버시에서도 불리하다.
///
/// ⚠️ 쓰기 전용 권한에서는 기존 캘린더를 조회하는 것이 제한될 수 있다.
/// `calendar(withIdentifier:)` 가 항상 nil 을 돌려주면 전용 캘린더를 매번 새로 만들어
/// 중복이 쌓인다. 실기기에서 반드시 확인할 것 — 문제가 되면 전용 캘린더를 포기하고
/// `defaultCalendarForNewEvents` 로만 기록하거나, 전체 접근 권한으로 바꿔야 한다.
@MainActor
@Observable
final class CalendarService {

    private static let calendarIdentifierKey = "calendar.focus.identifier"

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
        guard let calendar = focusCalendar() else { return nil }

        let event = EKEvent(eventStore: eventStore)
        event.title = CalendarEventFormat.eventTitle(for: record)
        event.startDate = record.startAt
        event.endDate = record.endAt
        event.calendar = calendar
        // §7 — 알람도 메모도 붙이지 않는다. 이미 끝난 일에 알람이 울리면 안 된다.
        event.alarms = nil
        event.notes = nil

        do {
            try eventStore.save(event, span: .thisEvent, commit: true)
            return event.eventIdentifier
        } catch {
            return nil
        }
    }

    // MARK: - 전용 캘린더

    /// §7 전용 "집중" 캘린더를 찾거나 만든다.
    ///
    /// 순서: 저장해 둔 식별자 → 같은 이름의 기존 캘린더 → 새로 생성.
    /// 두 번째 단계가 있는 이유는, 사용자가 캘린더를 지웠다가 다시 만들었거나
    /// 기기를 옮겨 식별자가 달라진 경우에 중복 생성을 막기 위해서다.
    private func focusCalendar() -> EKCalendar? {
        let defaults = AppGroup.defaults

        if let identifier = defaults.string(forKey: Self.calendarIdentifierKey),
           let existing = eventStore.calendar(withIdentifier: identifier) {
            return existing
        }

        if let sameName = eventStore.calendars(for: .event)
            .first(where: { $0.title == CalendarEventFormat.calendarName }) {
            defaults.set(sameName.calendarIdentifier, forKey: Self.calendarIdentifierKey)
            return sameName
        }

        return createFocusCalendar()
    }

    private func createFocusCalendar() -> EKCalendar? {
        guard let source = preferredSource() else { return nil }

        let calendar = EKCalendar(for: .event, eventStore: eventStore)
        calendar.title = CalendarEventFormat.calendarName
        calendar.source = source

        do {
            try eventStore.saveCalendar(calendar, commit: true)
            AppGroup.defaults.set(calendar.calendarIdentifier, forKey: Self.calendarIdentifierKey)
            return calendar
        } catch {
            // 계정 종류에 따라 캘린더 생성이 막혀 있을 수 있다.
            // 그 경우 기본 캘린더에라도 남기는 편이 아무것도 안 하는 것보다 낫다.
            return eventStore.defaultCalendarForNewEvents
        }
    }

    /// §7 source 우선순위: iCloud → 로컬 → 기본 캘린더의 source.
    ///
    /// iCloud 를 먼저 쓰는 이유는 기기를 바꿔도 기록이 따라오기 때문이다.
    private func preferredSource() -> EKSource? {
        let sources = eventStore.sources

        if let iCloud = sources.first(where: { $0.sourceType == .calDAV && $0.title == "iCloud" }) {
            return iCloud
        }
        if let local = sources.first(where: { $0.sourceType == .local }) {
            return local
        }
        return eventStore.defaultCalendarForNewEvents?.source
    }
}
