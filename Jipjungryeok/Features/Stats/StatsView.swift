import SwiftUI
import FocusCore

/// §4.2 통계 화면 — 세로 스크롤 단일 화면.
///
/// 위에서부터 오늘 링 / 이번 주 7칸 / 달력.
///
/// 셋이 서로 다른 질문에 답한다. 링은 **오늘 얼마나**, 주간 막대는 **이번 주 얼마나**,
/// 달력은 **이번 달 며칠 나왔나** 다. 달력 자리에는 최근 세션 5건이 있었는데,
/// 그건 한 탭 거리의 기록 시트를 잘라 놓은 것이라 자리값을 못 했다.
/// 달력은 그 자리에서 다른 질문에 답하고, 날짜를 눌러 그날로 들어가는 문도 된다.
struct StatsView: View {

    let store: SessionStore

    /// 메모 수정(§4.2-3)은 캘린더 notes 까지 건드리므로 레코더를 거친다.
    let recorder: SessionRecorder

    /// 달력이 쓰는 전체 기록. 화면에 들어올 때 한 번 읽는다 —
    /// 달을 넘길 때마다 스토어를 치지 않으려는 것이고, 세션은 수천 건이어도 가볍다.
    @State private var records: [SessionRecord] = []
    @State private var month: Date = MonthCalendar.month(containing: .now)
    @State private var selectedDay: DaySelection?
    @State private var showsHistory = false

    /// §4.4 와 같은 이유로 시트를 두 층에 나눠 단다. 한 뷰에 `sheet` 를 두 개 붙이면
    /// 나중 것만 살아남아서, 기록 시트를 달면 그날 시트가 조용히 죽는다.
    var body: some View {
        content
            .sheet(isPresented: $showsHistory) {
                HistoryView(store: store, recorder: recorder)
            }
    }

    private var content: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 28) {
                TodayRing(seconds: store.summary.todaySeconds)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)

                section("이번 주", accessory: weekTotal) {
                    WeekStrip(totals: store.summary.weekdayTotals)
                }

                section("기록", accessory: historyButton) {
                    MonthCalendarView(
                        grid: grid,
                        earliestMonth: MonthCalendar.earliestMonth(in: records),
                        onShiftMonth: { month = MonthCalendar.shift(month, by: $0) },
                        onSelectDay: { selectedDay = DaySelection(date: $0.date) }
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 28)
            // 하단 페이지 인디케이터에 가리지 않게 띄운다
            .padding(.bottom, 44)
        }
        .onAppear(perform: reload)
        .sheet(item: $selectedDay, onDismiss: reload) { selection in
            DayRecordsSheet(date: selection.date, store: store, recorder: recorder)
        }
    }

    /// 자정을 넘겼거나 다른 화면에서 세션이 끝났을 수 있다.
    /// 그날 시트에서 메모를 고치고 돌아왔을 수도 있다.
    private func reload() {
        store.reload()
        records = store.allRecords()
    }

    private var grid: MonthGrid {
        MonthCalendar.grid(for: month, sessions: records)
    }

    private var weekTotal: some View {
        Text("\(store.summary.weekSessionCount)회 · \(TimeDisplay.hhmm(store.summary.weekSeconds))")
            .font(Typography.statCaption)
            .foregroundStyle(Palette.inkSecondary)
            .monospacedDigit()
    }

    /// 달력은 한 달씩 보여준다. 날짜를 가로질러 메모를 훑고 싶을 때는 여기로 간다 (§4.2-3).
    /// 둘은 다른 질문에 답하므로 달력이 생겨도 이 문은 남긴다.
    private var historyButton: some View {
        Button {
            showsHistory = true
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

/// `sheet(item:)` 이 Identifiable 을 요구해서 감싸는 값. 날짜가 곧 신원이다.
private struct DaySelection: Identifiable {
    let date: Date
    var id: Date { date }
}

#Preview {
    let store = SessionStore(inMemory: true)
    let settings = AppSettings()
    return ZStack {
        Palette.background.ignoresSafeArea()
        StatsView(
            store: store,
            recorder: SessionRecorder(
                store: store,
                calendar: CalendarService(),
                settings: settings
            )
        )
    }
}
