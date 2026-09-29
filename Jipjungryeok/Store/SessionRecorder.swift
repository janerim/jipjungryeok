import Foundation
import Observation
import FocusCore

/// 끝난 세션 1건을 처리하는 지점.
///
/// 저장(§5), 메모 받기, 캘린더 기록(§7)을 하나로 묶는다. 타이머는 `finish` 하나만
/// 부르면 되고 EventKit 을 알 필요가 없다. 앱 시작 시 재시도도 여기 있다 —
/// 타이머와 무관한 일이라 `TimerViewModel` 에 둘 자리가 아니다.
///
/// **캘린더 기록은 메모가 정해진 뒤에 한다.** 먼저 쓰고 나중에 메모를 붙이려면
/// 이미 만든 이벤트를 다시 꺼내 고쳐야 하는데, 쓰기 전용 권한(§7)에서는 그게
/// 막힐 수 있다. 순서를 뒤집어 그 문제를 통째로 피한다.
@MainActor
@Observable
final class SessionRecorder {

    /// 이 시간이 지난 세션은 묻지 않고 조용히 확정한다.
    /// 어제 세션을 오늘 물어봐야 답이 나오지 않는다.
    private static let memoPromptWindow: TimeInterval = 12 * 60 * 60

    /// 메모를 물어볼 세션. 화면이 이걸 보고 시트를 띄운다.
    private(set) var memoPrompt: SessionRecord?

    @ObservationIgnored let store: SessionStore
    @ObservationIgnored private let calendar: CalendarService
    @ObservationIgnored private let settings: AppSettings

    init(store: SessionStore, calendar: CalendarService, settings: AppSettings) {
        self.store = store
        self.calendar = calendar
        self.settings = settings
    }

    // MARK: - 세션 종료

    /// §6-7 지금 떠 있는 회고를 저장할 때 세션을 늘려도 되는지.
    ///
    /// **앱을 보고 있는 상태에서 끝난 완료 세션에만** true 다. 판단은 `SessionEnding` 이
    /// 한다 — 백그라운드에서 끝난 세션이나 중지한 세션까지 늘리면 있지도 않은
    /// 긴 세션이 만들어진다.
    private(set) var canExtendPrompt = false

    /// 세션을 저장하고, 물어볼 세션이면 회고를 띄울 준비를 한다.
    ///
    /// - Parameter ending: 어떻게 끝났는지 (§6-4). 회고를 물을지, 늘려도 되는지가
    ///   여기서 갈린다. `record.isCompleted` 만으로는 중지와 다이얼 교체가 구분되지 않는다.
    func finish(_ record: SessionRecord, ending: SessionEnding) {
        // 앞 세션의 메모를 아직 못 받았다면 여기서 메모 없이 확정한다.
        // 안 그러면 그 세션이 캘린더에 영영 올라가지 않는다.
        finalizeMemoPrompt(memo: nil)

        store.save(record)

        // 다이얼을 돌려 밀려난 세션은 묻지 않는다. 설정에서 회고를 껐을 때도 같은
        // 길로 간다 — 묻지 않고 바로 캘린더에 올린다.
        guard ending.asksMemo, settings.isMemoPromptEnabled else {
            writeToCalendar(record)
            return
        }

        PendingMemoStore.save(PendingMemo(sessionID: record.id, finishedAt: .now))
        canExtendPrompt = ending.allowsExtension
        // 포그라운드였다면 이 순간 시트가 뜬다. 백그라운드였다면 다음에 앱을 열 때
        // `refreshMemoPrompt()` 가 같은 값을 되살린다.
        memoPrompt = record
    }

    // MARK: - 메모

    /// 앱을 열거나 포그라운드로 돌아왔을 때, 물어볼 메모가 남아 있는지 확인한다.
    func refreshMemoPrompt(now: Date = .now) {
        // 대기 중인 것이 남아 있는 상태로 설정을 껐을 수 있다. 그냥 두면 그 세션이
        // 영영 캘린더에 안 올라가므로, 묻지 않고 메모 없이 확정한다.
        guard settings.isMemoPromptEnabled else {
            finalizeMemoPrompt(memo: nil)
            return
        }

        guard let pending = PendingMemoStore.load() else {
            canExtendPrompt = false
            memoPrompt = nil
            return
        }

        let isFresh = now.timeIntervalSince(pending.finishedAt) <= Self.memoPromptWindow

        // 같은 회고가 이미 떠 있으면 손대지 않는다. 화면을 껐다 켜거나 제어 센터를
        // 내렸다 올려도 포그라운드 복귀로 여기에 오는데, 그때 연장을 끄면 시트를 띄운 채
        // 계속 일하던 시간이 사라진다(§6-7). 실제로 세션이 끝나고 자동 잠금으로 화면이
        // 꺼졌다가 켜는 순간 제목이 `N분 집중 완료` 로 바뀌었다. 자리를 비운 경우는
        // 90분 상한(`SessionExtension`)이 막는다.
        //
        // `memoPrompt` 는 메모리에만 있으므로, 앱을 새로 띄워 되살린 회고는 여기 걸리지 않는다.
        if isFresh, memoPrompt?.id == pending.sessionID { return }

        // 앱을 다시 열어 되살린 회고는 늘리지 않는다. 언제 끝났는지와 지금이
        // 얼마나 떨어져 있는지 알 수 없다.
        canExtendPrompt = false

        guard isFresh else {
            // 너무 오래됐다. 묻지 않고 확정만 한다.
            finalizeMemoPrompt(memo: nil)
            return
        }

        guard let record = store.record(with: pending.sessionID) else {
            // 세션이 지워졌으면 물어볼 대상이 없다.
            PendingMemoStore.clear()
            memoPrompt = nil
            return
        }

        memoPrompt = record
    }

    /// 메모 입력이 끝났을 때 부른다. 건너뛰기·시트 닫기는 `nil` 이다.
    ///
    /// **여기서 비로소 캘린더에 기록한다.**
    func finalizeMemoPrompt(memo: String?, savedAt: Date = .now) {
        memoPrompt = nil
        let canExtend = canExtendPrompt
        canExtendPrompt = false

        guard let pending = PendingMemoStore.load() else { return }
        PendingMemoStore.clear()

        // §6-7 — 시트를 띄워 둔 채 계속 일한 경우 저장 시각까지가 세션이다.
        // 메모를 붙이기 전에 늘려야 아래에서 다시 읽은 값에 반영된다.
        if canExtend {
            store.extendSession(pending.sessionID, savedAt: savedAt)
        }

        if let text = CalendarEventFormat.normalizedMemo(memo) {
            store.setMemo(text, on: pending.sessionID)
        }

        // 메모가 붙은 뒤의 값을 다시 읽어야 캘린더 notes 에 들어간다.
        guard let record = store.record(with: pending.sessionID) else { return }
        writeToCalendar(record)
    }

    /// §4.2-3 이미 저장된 세션의 메모를 고친다. 비우면 지운다.
    ///
    /// 회고는 세션이 끝난 직후 딱 한 번 뜨고 사라진다. 그 순간에 제대로 못 적거나
    /// (회의에 불려 가는 중이었다) 나중에 생각나는 일이 있는데, 고칠 길이 없으면
    /// 그 메모는 틀린 채로 영영 남는다.
    ///
    /// 캘린더 notes 도 함께 맞춘다. 실패해도 앱 안의 기록은 그대로 고쳐진다 —
    /// 쓰기 전용 권한에서는 이벤트를 다시 꺼낼 수 없기 때문이다(`updateNotes` 참고).
    func updateMemo(_ memo: String?, for sessionID: UUID) {
        let normalized = CalendarEventFormat.normalizedMemo(memo)
        store.setMemo(normalized, on: sessionID)

        // 캘린더 기록을 꺼 뒀다면 손대지 않는다. 과거 이벤트를 지우지 않는 것과
        // 같은 이유다 — 사용자의 캘린더다 (§7).
        guard settings.isCalendarEnabled,
              let eventID = store.calendarEventID(for: sessionID) else { return }

        calendar.updateNotes(eventID: eventID, notes: normalized)
    }

    // MARK: - 캘린더 (§7)

    /// 앱 시작 시 1회, 지난번에 실패한 것들을 다시 시도한다.
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
            if let eventID = calendar.record(record, in: settings.calendarIdentifier) {
                store.attachCalendarEvent(eventID, to: id)
                CalendarRetryQueue.remove(id)
            }
            // 또 실패하면 큐에 남겨 다음 실행 때 다시 시도한다.
        }
    }

    /// §4.3 데이터 초기화. 세션이 사라지므로 대기 중인 것들도 함께 비운다.
    ///
    /// **이미 만들어진 캘린더 이벤트는 지우지 않는다** (§7). 사용자의 캘린더이지
    /// 우리가 마음대로 지울 데이터가 아니다.
    func resetAllData() {
        store.deleteAll()
        CalendarRetryQueue.clear()
        PendingMemoStore.clear()
        memoPrompt = nil
    }

    // MARK: -

    private func writeToCalendar(_ record: SessionRecord) {
        // 설정이 꺼져 있으면 기록하지 않는다. 재시도 큐에도 넣지 않는다 —
        // 실패가 아니라 사용자가 원하지 않은 것이다 (§7).
        guard settings.isCalendarEnabled else { return }

        guard calendar.canWrite,
              let eventID = calendar.record(record, in: settings.calendarIdentifier) else {
            CalendarRetryQueue.add(record.id)
            return
        }
        store.attachCalendarEvent(eventID, to: record.id)
    }
}
