import SwiftUI
import FocusCore

/// §4.2 통계 화면 — 세로 스크롤 단일 화면.
///
/// 위에서부터 오늘 한 줄 / 주간 막대 / 달력.
///
/// 셋이 서로 다른 질문에 답한다. 맨 줄은 **오늘 얼마나**, 막대는 **이번 주 얼마나**,
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
    @State private var weekAnchor: Date = WeekSeries.week(containing: .now)
    @State private var selectedDay: DaySelection?
    @State private var showsHistory = false

    /// §4.4 와 같은 이유로 시트를 두 층에 나눠 단다. 한 뷰에 `sheet` 를 두 개 붙이면
    /// 나중 것만 살아남아서, 기록 시트를 달면 그날 시트가 조용히 죽는다.
    var body: some View {
        content
            .sheet(isPresented: $showsHistory) {
                HistoryView(store: store, recorder: recorder, initialMonth: month)
            }
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                today

                section(TimeDisplay.relativeWeek(weekAnchor), accessory: weekNav) {
                    WeekStrip(totals: week.totals)
                        // 달력과 같은 손동작으로 넘긴다. 한 화면에서 두 그림이
                        // 다르게 움직이면 어느 쪽이 넘어가는지 매번 확인해야 한다.
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 24)
                                .onEnded { value in
                                    guard abs(value.translation.width) > abs(value.translation.height) else { return }
                                    if value.translation.width < -40, canGoForwardWeek {
                                        weekAnchor = WeekSeries.shift(weekAnchor, by: 1)
                                    } else if value.translation.width > 40, canGoBackWeek {
                                        weekAnchor = WeekSeries.shift(weekAnchor, by: -1)
                                    }
                                }
                        )
                }

                section("기록", accessory: historyButton) {
                    MonthCalendarView(
                        grid: grid,
                        earliestMonth: MonthCalendar.earliestMonth(in: records),
                        onShiftMonth: { month = MonthCalendar.shift(month, by: $0) },
                        onGoToday: goToday,
                        onSelectDay: { selectedDay = DaySelection(date: $0.date) }
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 28)
            // 하단 페이지 인디케이터에 가리지 않게 띄운다
            .padding(.bottom, 44)
        }
        .scrollIndicators(.hidden)
        .onAppear(perform: reload)
        .sheet(item: $selectedDay, onDismiss: reload) { selection in
            DayRecordsSheet(date: selection.date, store: store, recorder: recorder)
        }
    }

    /// §4.2-1 오늘. 이 자리에는 지름 168pt 짜리 링이 있었다.
    ///
    /// 링은 본래 **목표 대비 얼마나**를 말하는 도형인데, 목표 설정을 만들지
    /// 않으므로(규칙 5) 분모를 5시간으로 박아 둔 가짜였다. 보통 날엔 1/4 쯤 차고
    /// 나머지는 아무 말도 하지 않았다. 게다가 오늘은 바로 아래 주간 막대의 진한
    /// 칸으로 **같은 기준에서 한 번 더** 그려진다 — 한 화면에서 제일 넓은 자리가
    /// 제일 적은 정보를 들고 있었다.
    ///
    /// 그래서 숫자 한 줄로 줄이고 그 공간을 막대에 넘겼다. 위젯은 링을 그대로
    /// 쓴다(§8.1) — 작은 정사각형과 긴 스크롤은 다른 그릇이고, 숫자도 기준도
    /// 같아서 둘이 다른 말을 하지는 않는다.
    ///
    /// **주를 넘겨도 이 줄은 안 변한다.** 그래서 주간 섹션 바깥에 둔다 — 안에
    /// 넣으면 지난주를 보는 동안 오늘이 그 주의 값처럼 읽힌다.
    private var today: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("오늘")
                .font(Typography.statCaption)
                .foregroundStyle(Palette.inkSecondary)

            Text(TimeDisplay.hhmm(store.summary.todaySeconds))
                .font(Typography.statValue)
                .foregroundStyle(Palette.ink)
                .monospacedDigit()
                .contentTransition(.numericText())

            Spacer(minLength: 8)

            // 합계만으로는 한 번에 80분 한 날과 25분씩 세 번 한 날이 같아 보인다.
            // 0회일 때는 적지 않는다 — 빈 날에 "0회" 를 박아 두면 꾸짖는 투가 된다.
            if store.summary.todaySessionCount > 0 {
                Text("\(store.summary.todaySessionCount)회")
                    .font(Typography.statCaption)
                    .foregroundStyle(Palette.inkSecondary)
                    .monospacedDigit()
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(todayAccessibilityLabel)
    }

    private var todayAccessibilityLabel: String {
        let time = TimeDisplay.hourMinuteText(store.summary.todaySeconds)
        guard store.summary.todaySessionCount > 0 else { return "오늘 집중 시간 없음" }
        return "오늘 집중 시간 \(time), \(store.summary.todaySessionCount)회"
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

    private var week: WeekSummary {
        WeekSeries.summary(forWeekContaining: weekAnchor, sessions: records)
    }

    /// 주간 막대 머리줄의 `‹ N회 · HH:mm ›`.
    ///
    /// 합계 양옆에 화살표를 둔다. 달력 머리줄과 같은 모양이라 둘이 같은 방식으로
    /// 움직인다는 것이 한눈에 읽힌다.
    private var weekNav: some View {
        HStack(spacing: 0) {
            weekArrow("chevron.left", enabled: canGoBackWeek, label: "이전 주") {
                weekAnchor = WeekSeries.shift(weekAnchor, by: -1)
            }

            Text("\(week.sessionCount)회 · \(TimeDisplay.hhmm(week.totalSeconds))")
                .font(Typography.statCaption)
                .foregroundStyle(Palette.inkSecondary)
                .monospacedDigit()

            weekArrow("chevron.right", enabled: canGoForwardWeek, label: "다음 주") {
                weekAnchor = WeekSeries.shift(weekAnchor, by: 1)
            }
        }
    }

    /// 넘길 수 없는 쪽도 지우지 않고 흐리게 둔다. 사라지면 자리가 바뀌어 합계가 움직인다.
    private func weekArrow(
        _ systemName: String,
        enabled: Bool,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Palette.inkSecondary)
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
        }
        .pressable()
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.25)
        .accessibilityLabel(label)
        .accessibilityHidden(!enabled)
    }

    /// 앞으로는 이번 주까지만. 아직 오지 않은 주를 볼 이유가 없다.
    private var canGoForwardWeek: Bool {
        weekAnchor < WeekSeries.week(containing: .now)
    }

    private var canGoBackWeek: Bool {
        guard let earliest = WeekSeries.earliestWeek(in: records) else { return false }
        return weekAnchor > earliest
    }

    /// 달력의 "오늘" 은 **주간 막대까지 함께** 되돌린다.
    /// 버튼을 둘 두면 한 화면에 "오늘" 이 두 개가 되고, 하나만 눌렀을 때
    /// 위아래가 다른 시점을 가리키게 된다.
    private func goToday() {
        month = MonthCalendar.month(containing: .now)
        weekAnchor = WeekSeries.week(containing: .now)
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
