import SwiftUI

@main
struct JipjungryeokApp: App {

    @State private var store: SessionStore
    @State private var settings: AppSettings
    @State private var calendar: CalendarService
    @State private var notifications: NotificationService
    @State private var recorder: SessionRecorder
    @State private var timerModel: TimerViewModel

    init() {
        // 의존 관계를 여기서 한 번만 엮는다.
        //
        // NotificationService 를 앱 시작 시점에 만드는 이유: 생성자에서
        // UNUserNotificationCenter 델리게이트를 붙인다. 알림이 도착하기 전에
        // 붙어 있어야 포그라운드 배너를 막을 수 있다 (§6-3).
        let store = SessionStore()
        let settings = AppSettings()
        let calendar = CalendarService()
        let notifications = NotificationService()
        let recorder = SessionRecorder(store: store, calendar: calendar, settings: settings)

        _store = State(initialValue: store)
        _settings = State(initialValue: settings)
        _calendar = State(initialValue: calendar)
        _notifications = State(initialValue: notifications)
        _recorder = State(initialValue: recorder)
        _timerModel = State(
            initialValue: TimerViewModel(recorder: recorder, notifications: notifications)
        )
    }

    var body: some Scene {
        WindowGroup {
            RootView(
                store: store,
                recorder: recorder,
                settings: settings,
                calendar: calendar,
                notifications: notifications,
                timerModel: timerModel
            )
            .task {
                // §7 — 지난 실행에서 캘린더 기록에 실패한 세션을 다시 시도한다.
                recorder.retryPendingCalendarWrites()
                // 앱이 꺼져 있는 동안 끝난 세션이 있으면 메모를 묻는다.
                recorder.refreshMemoPrompt()
            }
        }
        // §10 — `.preferredColorScheme` 을 지정하지 않는다. 시스템 설정을 그대로 따른다.
    }
}
