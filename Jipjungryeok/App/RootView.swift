import SwiftUI
import FocusCore

/// §4.0 화면 전환 구조.
///
/// ```
/// [ 통계 ] ←스와이프→ [ 타이머 ] ←스와이프→ [ 설정 ]
///                     (초기 화면)
/// ```
///
/// 타이머 모델을 여기서 들고 있는 이유: 페이지를 넘겨도 세션이 끊기지 않아야 한다
/// (§12 "타이머 실행 중 통계로 넘어갔다 돌아와도 세션이 유지된다").
struct RootView: View {

    private enum Page: Int, CaseIterable, Hashable {
        case stats, timer, settings
    }

    let store: SessionStore
    let recorder: SessionRecorder
    let settings: AppSettings
    let calendar: CalendarService
    let notifications: NotificationService
    let timerModel: TimerViewModel

    @State private var page: Page = .timer
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack(alignment: .bottom) {
            Palette.background
                .ignoresSafeArea()

            TabView(selection: $page) {
                StatsView(store: store)
                    .tag(Page.stats)
                TimerView(model: timerModel)
                    .tag(Page.timer)
                SettingsView(
                    recorder: recorder,
                    settings: settings,
                    calendar: calendar,
                    notifications: notifications
                )
                .tag(Page.settings)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            PageIndicator(pageCount: Page.allCases.count, currentIndex: page.rawValue)
                .padding(.bottom, 10)
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            // §6-2 — 포그라운드로 돌아오면 절대시각으로 다시 계산하고,
            // 종료 시각이 이미 지났으면 그 시점으로 완료 처리한다.
            timerModel.refresh()
            // 자정을 넘겨 돌아왔다면 "오늘" 이 달라져 있다.
            store.reload()
            // 시스템 설정에서 권한을 바꾸고 돌아왔을 수 있다 (§4.3).
            calendar.refreshAuthorization()
        }
    }
}

#Preview("라이트") {
    RootView.preview.preferredColorScheme(.light)
}

#Preview("다크") {
    RootView.preview.preferredColorScheme(.dark)
}

extension RootView {
    /// 프리뷰용 조립. 디스크에 아무것도 남기지 않는다.
    static var preview: RootView {
        let store = SessionStore(inMemory: true)
        let settings = AppSettings()
        let calendar = CalendarService()
        let notifications = NotificationService()
        let recorder = SessionRecorder(store: store, calendar: calendar, settings: settings)
        return RootView(
            store: store,
            recorder: recorder,
            settings: settings,
            calendar: calendar,
            notifications: notifications,
            timerModel: TimerViewModel(recorder: recorder, notifications: notifications)
        )
    }
}
