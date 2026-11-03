import SwiftUI
import FocusCore

/// §4.2-3 통계 화면의 달력.
///
/// 책력과 같은 틀이다 — 월요일 시작, 앞뒤 달 날짜로 주를 채움, 좌우로 달 넘김.
/// 다른 것은 칸 **안**이다. 책력은 그날 끝낸 책을 표지로 그리지만 집중력에는
/// 그릴 "물건" 이 없다. 대신 그날 집중한 양을 **농담**으로 칠한다.
///
/// 농도 기준은 5시간으로, 오늘 링·주간 막대와 같다(`StatsSummary.fullRingSeconds`).
/// 셋이 다른 기준을 쓰면 같은 화면에서 서로 다른 말을 하게 된다.
struct MonthCalendarView: View {

    let grid: MonthGrid
    /// 뒤로 넘길 수 있는 한계. 기록이 시작된 달이다.
    let earliestMonth: Date?
    let onShiftMonth: (Int) -> Void
    let onSelectDay: (CalendarDay) -> Void

    private let calendar = Calendar.focus

    /// 요일 머리글. 월요일부터다 (§1-1).
    private static let weekdayLabels = ["월", "화", "수", "목", "금", "토", "일"]

    /// 칸 높이. 책력은 표지를 넣느라 120pt 지만 여기는 숫자와 농담뿐이라 훨씬 낮다.
    /// 44pt 면 손가락도 닿고 6줄이어도 한 화면에 들어온다.
    private static let cellHeight: CGFloat = 44

    var body: some View {
        VStack(spacing: 10) {
            header
            weekdayHeader
            weeks
        }
        // 스와이프로 달을 넘긴다. 세로 성분이 크면 통계 화면 스크롤에 양보한다 —
        // 안 그러면 달력 위에서 스크롤이 먹지 않는다.
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 24)
                .onEnded { value in
                    guard abs(value.translation.width) > abs(value.translation.height) else { return }
                    if value.translation.width < -40, canGoForward {
                        onShiftMonth(1)
                    } else if value.translation.width > 40, canGoBack {
                        onShiftMonth(-1)
                    }
                }
        )
    }

    // MARK: - 머리줄

    private var header: some View {
        HStack(spacing: 0) {
            arrow(systemName: "chevron.left", enabled: canGoBack, label: "이전 달") {
                onShiftMonth(-1)
            }

            // "며칠 나왔나" 를 달 이름 옆에 붙인다. §4.2 가 이 그림의 목적으로 꼽은
            // 숫자라 따로 줄을 내주기보다 제목과 한 덩어리로 읽히는 편이 낫다.
            // 합계 시간은 넣지 않는다 — 얼마나 했는지는 위의 링과 주간 막대가 답한다.
            Text(headerText)
                .font(Typography.statCaption)
                .foregroundStyle(Palette.ink)
                .monospacedDigit()
                .frame(maxWidth: .infinity)
                // 달을 넘길 때 글자가 밀리지 않게 한 줄로 못박는다.
                .lineLimit(1)

            arrow(systemName: "chevron.right", enabled: canGoForward, label: "다음 달") {
                onShiftMonth(1)
            }
        }
    }

    private var headerText: String {
        let month = TimeDisplay.yearMonth(grid.month)
        guard grid.activeDayCount > 0 else { return month }
        return "\(month) · \(grid.activeDayCount)일"
    }

    /// 넘길 수 없는 쪽은 **지우지 않고 흐리게** 둔다. 버튼이 사라지면 자리가
    /// 바뀌어서 달 이름이 좌우로 움직인다.
    private func arrow(
        systemName: String,
        enabled: Bool,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Palette.inkSecondary)
                .frame(width: 44, height: 32)
                .contentShape(Rectangle())
        }
        .pressable()
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.25)
        .accessibilityLabel(label)
        .accessibilityHidden(!enabled)
    }

    /// 앞으로는 이번 달까지만. 빈 격자를 넘길 이유가 없다.
    private var canGoForward: Bool {
        grid.month < MonthCalendar.month(containing: .now, calendar: calendar)
    }

    private var canGoBack: Bool {
        guard let earliestMonth else { return false }
        return grid.month > earliestMonth
    }

    // MARK: - 격자

    private var weekdayHeader: some View {
        HStack(spacing: 4) {
            ForEach(Self.weekdayLabels, id: \.self) { label in
                Text(label)
                    .font(Typography.statCaption)
                    .foregroundStyle(Palette.inkSecondary)
                    .frame(maxWidth: .infinity)
            }
        }
        // 토·일을 다른 색으로 칠하지 않는다. 색을 늘리면 테마 3종 × 라이트/다크를
        // 전부 대비 기준에 맞춰야 하고(§10), 집중력은 평일과 주말을 구분하지 않는다.
        .accessibilityHidden(true)
    }

    private var weeks: some View {
        VStack(spacing: 4) {
            ForEach(Array(grid.weeks.enumerated()), id: \.offset) { _, week in
                HStack(spacing: 4) {
                    ForEach(week) { day in
                        cell(day)
                    }
                }
            }
        }
    }

    private func cell(_ day: CalendarDay) -> some View {
        let isToday = calendar.isDateInToday(day.date)

        return Button {
            onSelectDay(day)
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Palette.ink.opacity(intensity(for: day)))

                // 오늘은 농담과 무관하게 테두리로 표시한다. 집중을 안 한 날에도
                // 오늘이 어디인지는 보여야 한다.
                if isToday {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Palette.accent, lineWidth: 1.5)
                }

                Text("\(calendar.component(.day, from: day.date))")
                    .font(Typography.statCaption)
                    .monospacedDigit()
                    .foregroundStyle(numberColor(for: day))

                // §4.2 — 기준(5시간)을 넘긴 날. 링이 넘친 만큼을 두 번째 호로 그리는 것과
                // 같은 장치다. 농도만으로는 5시간·7시간·10시간이 전부 상한에 붙어
                // 같은 칸으로 보인다.
                if overflows(day) {
                    Circle()
                        .fill(Palette.accent)
                        .frame(width: 4, height: 4)
                        .frame(maxHeight: .infinity, alignment: .bottom)
                        .padding(.bottom, 5)
                        .opacity(day.isInMonth ? 1 : 0.4)
                }
            }
            .frame(height: Self.cellHeight)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .pressable(scale: 0.92)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel(for: day))
        .accessibilityHint("두 번 탭하여 그날 기록 보기")
    }

    /// 칸 농도. 5시간이면 상한에 닿는다 — 링·막대와 같은 기준이다
    /// (`StatsSummary.fullRingSeconds`). 셋이 다른 기준을 쓰면 한 화면에서 서로 다른 말을 한다.
    ///
    /// 상한이 0.35 인 이유는 칸 위에 날짜 숫자가 올라가기 때문이다 —
    /// `Metrics.calendarMaxFill` 참고. 그래서 **숫자 색을 뒤집지 않는다.**
    ///
    /// 앞뒤 달 칸은 절반만 칠한다. 날짜 숫자만 흐리게 하면 농담이 그 달 것처럼 읽힌다.
    private func intensity(for day: CalendarDay) -> Double {
        guard day.seconds > 0 else { return 0 }
        let fill = StatsSummary.fillFraction(forSeconds: day.seconds)
        let span = Metrics.calendarMaxFill - Metrics.calendarMinFill
        let value = Metrics.calendarMinFill + fill * span
        return day.isInMonth ? value : value * 0.4
    }

    private func overflows(_ day: CalendarDay) -> Bool {
        StatsSummary.overflowFraction(forSeconds: day.seconds) > 0
    }

    /// 농도에 상한이 있으므로 잉크 숫자가 어느 칸에서나 읽힌다. 뒤집지 않는다.
    private func numberColor(for day: CalendarDay) -> Color {
        day.isInMonth ? Palette.ink : Palette.inkSecondary.opacity(0.45)
    }

    private func accessibilityLabel(for day: CalendarDay) -> String {
        let month = calendar.component(.month, from: day.date)
        let dayNumber = calendar.component(.day, from: day.date)
        let time = day.seconds > 0 ? TimeDisplay.hourMinuteText(day.seconds) : "기록 없음"
        return "\(month)월 \(dayNumber)일, \(time)"
    }
}

#Preview {
    let calendar = Calendar.focus
    let now = Date()
    let month = MonthCalendar.month(containing: now, calendar: calendar)
    let sessions: [SessionRecord] = [0, 2, 3, 9, 10, 16].map { offset in
        let start = calendar.date(byAdding: .day, value: offset, to: month) ?? month
        return SessionRecord(
            id: UUID(),
            startAt: start,
            endAt: start,
            plannedSeconds: 1500,
            actualSeconds: (offset + 1) * 1200,
            isCompleted: true
        )
    }

    return ZStack {
        Palette.background.ignoresSafeArea()
        MonthCalendarView(
            grid: MonthCalendar.grid(for: now, sessions: sessions, calendar: calendar),
            earliestMonth: MonthCalendar.earliestMonth(in: sessions, calendar: calendar),
            onShiftMonth: { _ in },
            onSelectDay: { _ in }
        )
        .padding(.horizontal, 20)
    }
}
