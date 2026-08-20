import SwiftUI
import FocusCore

/// §4.2 통계 화면 — 세로 스크롤 단일 화면.
struct StatsView: View {

    let store: SessionStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                section("추이") {
                    TrendGrid(summary: store.summary)
                }

                section("회고") {
                    RetrospectRow(sessions: store.recent)
                }

                section("차트") {
                    DailyBarChart(
                        totals: store.summary.dailyTotals,
                        maxHours: store.summary.chartMaxHours,
                        month: store.summary.chartMonth
                    )
                }

                timeSummary
            }
            .padding(.horizontal, 20)
            .padding(.top, 28)
            // 하단 페이지 인디케이터에 가리지 않게 띄운다
            .padding(.bottom, 44)
        }
        .scrollIndicators(.hidden)
        .onAppear {
            // 자정을 넘겼거나 다른 화면에서 세션이 끝났을 수 있다.
            store.reload()
        }
    }

    /// §4.2-4 시간 요약 — 차트에 표시된 달 기준
    private var timeSummary: some View {
        HStack {
            Text("집중 횟수 \(store.summary.monthSessionCount)회")
            Spacer()
            Text("합계 \(TimeDisplay.hourMinuteText(store.summary.monthSeconds))")
        }
        .font(Typography.statCaption)
        .foregroundStyle(Palette.inkSecondary)
    }

    private func section<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(Typography.statCaption)
                .foregroundStyle(Palette.inkSecondary)
            content()
        }
    }
}

#Preview {
    ZStack {
        Palette.background.ignoresSafeArea()
        StatsView(store: SessionStore(inMemory: true))
    }
}
