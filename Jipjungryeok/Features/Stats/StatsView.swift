import SwiftUI
import FocusCore

/// §4.2 통계 화면 — 세로 스크롤 단일 화면.
///
/// 위에서부터 오늘 링 / 이번 주 7칸 / 최근 기록.
///
/// 지표를 오늘과 이번 주 둘로 줄였다. 이전에는 오늘·이번 주·이번 달·최근 7일·
/// 최근 28일 다섯 칸이 있었는데, "이번 주" 와 "최근 7일" 은 사실상 같은 질문에
/// 답하면서 정의만 달랐다. 숫자를 늘어놓는 것과 알려주는 것은 다르다.
/// 더 긴 기간이 궁금하면 기록 화면에서 날짜별로 훑는다.
struct StatsView: View {

    let store: SessionStore

    /// 시트를 열 때 한 번 읽어서 담아 둔다. 상시 보관하지 않는 이유는 SessionStore 참고.
    @State private var history: IdentifiedDays?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                TodayRing(seconds: store.summary.todaySeconds)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)

                section("이번 주", accessory: weekTotal) {
                    WeekStrip(totals: store.summary.weekdayTotals)
                }

                section("기록", accessory: historyButton) {
                    recentSessions
                }
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

    private var weekTotal: some View {
        Text("\(store.summary.weekSessionCount)회 · \(TimeDisplay.hhmm(store.summary.weekSeconds))")
            .font(Typography.statCaption)
            .foregroundStyle(Palette.inkSecondary)
            .monospacedDigit()
    }

    /// §12 — 세션 0건이어도 크래시 없이 빈 상태가 그려져야 한다.
    @ViewBuilder
    private var recentSessions: some View {
        if store.recent.isEmpty {
            Text("아직 기록이 없습니다")
                .font(Typography.statCaption)
                .foregroundStyle(Palette.inkSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 8)
        } else {
            // 날짜 없이 시각만 늘어놓으면 14:05 다음에 16:22 가 와서 순서가 틀린 줄 안다.
            // 기록 시트와 같은 묶기를 쓰되, 여기서는 회수·합계 없이 라벨만 얹는다.
            VStack(alignment: .leading, spacing: 18) {
                ForEach(SessionHistory.byDay(store.recent)) { day in
                    VStack(alignment: .leading, spacing: 12) {
                        Text(TimeDisplay.relativeDay(day.date))
                            .font(Typography.statCaption)
                            .foregroundStyle(Palette.inkSecondary)

                        ForEach(day.sessions) { session in
                            SessionRow(session: session)
                        }
                    }
                }
            }
        }
    }

    /// 최근 몇 건 너머를 보려면 여기로 들어간다 (§4.2-3).
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
        .pressable()
    }

    private func section<Content: View, Accessory: View>(
        _ title: String,
        accessory: Accessory = EmptyView(),
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
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
