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

    @State private var page: Page = .timer
    @State private var timerModel = TimerViewModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack(alignment: .bottom) {
            Palette.background
                .ignoresSafeArea()

            TabView(selection: $page) {
                StatsView()
                    .tag(Page.stats)
                TimerView(model: timerModel)
                    .tag(Page.timer)
                SettingsView()
                    .tag(Page.settings)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            PageIndicator(pageCount: Page.allCases.count, currentIndex: page.rawValue)
                .padding(.bottom, 10)
        }
        .onChange(of: scenePhase) { _, newPhase in
            // §6-2 — 포그라운드로 돌아오면 절대시각으로 다시 계산하고,
            // 종료 시각이 이미 지났으면 그 시점으로 완료 처리한다.
            if newPhase == .active {
                timerModel.refresh()
            }
        }
    }
}

#Preview("라이트") {
    RootView()
        .preferredColorScheme(.light)
}

#Preview("다크") {
    RootView()
        .preferredColorScheme(.dark)
}
