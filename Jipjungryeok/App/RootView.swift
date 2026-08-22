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
        content
            // §10 — `Palette` 는 static 접근이라 테마를 바꿔도 SwiftUI 가 무엇이
            // 달라졌는지 모른다. 화면을 통째로 다시 만들어야 새 색이 적용된다.
            // 테마 변경은 드문 일이라 이 비용은 문제가 되지 않는다.
            .id(settings.theme)
    }

    private var content: some View {
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
        .sheet(item: memoBinding) { session in
            MemoSheet(session: session) { memo in
                recorder.finalizeMemoPrompt(memo: memo)
            }
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
            // 백그라운드에서 끝난 세션이 있으면 지금 메모를 묻는다.
            recorder.refreshMemoPrompt()
        }
    }

    /// 시트에서 나가는 길은 오른쪽 위 X 와 아래로 내리기 둘 다이며, 어느 쪽이든
    /// 메모 없이 마무리한다. 그래야 캘린더 기록이 대기 상태로 남지 않는다.
    /// `finalizeMemoPrompt` 는 대기열을 먼저 비우므로 두 번 불려도 안전하다.
    private var memoBinding: Binding<SessionRecord?> {
        Binding(
            get: { recorder.memoPrompt },
            set: { newValue in
                guard newValue == nil else { return }
                recorder.finalizeMemoPrompt(memo: nil)
            }
        )
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
