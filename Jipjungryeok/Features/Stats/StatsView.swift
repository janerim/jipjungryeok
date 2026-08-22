import SwiftUI
import FocusCore

/// §4.2 통계 화면 — 세로 스크롤 단일 화면.
struct StatsView: View {

    let store: SessionStore

    /// 시트를 열 때 한 번 읽어서 담아 둔다. 상시 보관하지 않는 이유는 SessionStore 참고.
    @State private var history: IdentifiedDays?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                section("추이") {
                    TrendGrid(summary: store.summary)
                }

                section("회고", accessory: historyButton) {
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
        .sheet(item: $history) { days in
            HistoryView(days: days.value)
        }
    }

    /// 회고 카드는 최근 3건뿐이다. 그 너머를 보려면 여기로 들어간다 (§4.2).
    private var historyButton: some View {
        Button {
            history = IdentifiedDays(value: SessionHistory.byDay(store.allRecords()))
        } label: {
            HStack(spacing: 4) {
                Text("전체")
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
            }
            .font(Typography.statCaption)
            .foregroundStyle(Palette.inkSecondary)
            // 글자만으로는 44pt 히트 영역이 안 나온다.
            .padding(.vertical, 8)
            .padding(.leading, 12)
            .contentShape(Rectangle())
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

    private func section<Content: View, Accessory: View>(
        _ title: String,
        accessory: Accessory = EmptyView(),
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 0) {
                Text(title)
                    .font(Typography.statCaption)
                    .foregroundStyle(Palette.inkSecondary)
                Spacer(minLength: 8)
                accessory
            }
            content()
        }
    }
}

/// `sheet(item:)` 은 Identifiable 을 요구하는데 배열에는 신원이 없다.
/// 별도 상태 플래그를 두는 것보다, 열 때 읽은 값을 그대로 시트에 넘기는 편이
/// "여는 순간의 목록" 이라는 의도가 분명하다.
private struct IdentifiedDays: Identifiable {
    let id = UUID()
    let value: [HistoryDay]
}

#Preview {
    ZStack {
        Palette.background.ignoresSafeArea()
        StatsView(store: SessionStore(inMemory: true))
    }
}
