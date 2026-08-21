import SwiftUI

@main
struct JipjungryeokApp: App {

    @State private var store: SessionStore
    @State private var notifications: NotificationService
    @State private var timerModel: TimerViewModel

    init() {
        // 타이머가 끝낸 세션을 저장소가 받아야 하므로 여기서 한 번만 엮는다.
        //
        // NotificationService 를 앱 시작 시점에 만드는 이유: 생성자에서
        // UNUserNotificationCenter 델리게이트를 붙인다. 알림이 도착하기 전에
        // 붙어 있어야 포그라운드 배너를 막을 수 있다 (§6-3).
        let store = SessionStore()
        let notifications = NotificationService()
        _store = State(initialValue: store)
        _notifications = State(initialValue: notifications)
        _timerModel = State(
            initialValue: TimerViewModel(store: store, notifications: notifications)
        )
    }

    var body: some Scene {
        WindowGroup {
            RootView(store: store, timerModel: timerModel)
        }
        // §10 — `.preferredColorScheme` 을 지정하지 않는다. 시스템 설정을 그대로 따른다.
    }
}
