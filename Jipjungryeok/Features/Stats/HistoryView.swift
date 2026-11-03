import SwiftUI
import FocusCore

/// §4.2-3 기록 — 지난 세션을 **한 달씩** 훑어보는 시트.
///
/// 통계 화면의 달력이 "이번 달에 며칠 나왔나" 를 답한다면 여기는 "그때 뭘 했더라" 를
/// 찾아 들어가는 자리다. 그래서 메모가 주인공이다 — 다시 읽을 곳이 없으면
/// 애초에 메모를 쓸 이유도 없다.
///
/// **한 달씩 끊는 것이 이 화면의 구조다.** 예전에는 전체를 한 줄로 이어 붙였다.
/// 기록이 쌓일수록 끝없이 길어졌고, 중간에 "더 보기" 를 넣어 봐도 길이만 줄었지
/// 찾는 문제는 그대로였다 — 1년 치면 여러 번 누르고 스크롤해야 한다.
/// 한 달씩이면 **기록이 몇 년 쌓여도 한 페이지 길이가 그대로다.**
///
/// 달력과 같은 방식으로 넘긴다(화살표 + 좌우 스와이프). 바로 위 화면에서 쓰던
/// 손동작이라 새로 배울 것이 없다. 열 때도 **달력이 보고 있던 달**에서 시작한다.
///
/// 시간축을 왼쪽 열에 고정해 위에서 아래로 읽히게 했다. 세션마다 카드를 두르면
/// 하루에 여러 건 있을 때 테두리끼리 부딪혀 오히려 덩어리져 보인다.
struct HistoryView: View {

    let store: SessionStore
    let recorder: SessionRecorder

    /// 달력이 보고 있던 달. 거기서 "전체" 를 눌렀으니 같은 달이 열려야 한다.
    let initialMonth: Date

    @State private var months: [HistoryMonth] = []
    @State private var month: Date
    @State private var editing: SessionRecord?
    @Environment(\.dismiss) private var dismiss

    private let calendar = Calendar.focus

    init(store: SessionStore, recorder: SessionRecorder, initialMonth: Date) {
        self.store = store
        self.recorder = recorder
        self.initialMonth = initialMonth
        _month = State(initialValue: MonthCalendar.month(containing: initialMonth))
    }

    var body: some View {
        ZStack {
            Palette.background
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                header
                monthBar

                if let current, !current.days.isEmpty {
                    list(current)
                } else {
                    emptyState
                }
            }
            // 달력과 같은 손동작. 목록 위 어디서 쓸어도 달이 넘어간다.
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 24)
                    .onEnded { value in
                        guard abs(value.translation.width) > abs(value.translation.height) else { return }
                        if value.translation.width < -40, canGoForward {
                            shift(1)
                        } else if value.translation.width > 40, canGoBack {
                            shift(-1)
                        }
                    }
            )
        }
        .task { reload() }
        .sheet(item: $editing) { session in
            MemoEditSheet(session: session) { memo in
                recorder.updateMemo(memo, for: session.id)
                // 목록은 `months` 에 담아 둔 값이라 스스로 갱신되지 않는다.
                reload()
            }
        }
    }

    /// 정렬과 묶기는 `SessionHistory` 가 §4.2 규칙(`startAt` 기준)에 맞춰 한다.
    /// 여기서 다시 정렬하면 규칙이 두 곳으로 갈라진다.
    private func reload() {
        months = SessionHistory.byMonth(store.allRecords())
    }

    private var current: HistoryMonth? {
        months.first { $0.month == month }
    }

    private func shift(_ delta: Int) {
        month = MonthCalendar.shift(month, by: delta)
    }

    /// 앞으로는 이번 달까지만. 아직 오지 않은 달에는 기록이 있을 수 없다.
    private var canGoForward: Bool {
        month < MonthCalendar.month(containing: .now, calendar: calendar)
    }

    /// 뒤로는 첫 기록이 있는 달까지. 끝없이 넘어가면 "더 있나" 를 확인할 방법이 없다.
    private var canGoBack: Bool {
        guard let earliest = months.last?.month else { return false }
        return month > earliest
    }

    // MARK: - 머리줄

    private var header: some View {
        HStack {
            Text("기록")
                .font(Typography.sheetTitle)
                .foregroundStyle(Palette.ink)

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Palette.inkSecondary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .padding(.trailing, -12)
            .pressable()
            .accessibilityLabel("닫기")
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
    }

    /// 달력 머리줄과 같은 모양이다 — 양옆 화살표, 가운데 달 이름.
    /// 오른쪽 합계는 그 달에 며칠 나왔는지다(§4.2).
    private var monthBar: some View {
        HStack(spacing: 0) {
            arrow("chevron.left", enabled: canGoBack, label: "이전 달") { shift(-1) }

            Text(TimeDisplay.yearMonth(month))
                .font(Typography.statValue)
                .foregroundStyle(Palette.ink)
                .monospacedDigit()
                .lineLimit(1)

            arrow("chevron.right", enabled: canGoForward, label: "다음 달") { shift(1) }

            Spacer(minLength: 8)

            if let current {
                Text("\(current.dayCount)일 · \(TimeDisplay.hhmm(current.totalSeconds))")
                    .font(Typography.statCaption)
                    .foregroundStyle(Palette.inkSecondary)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 14)
        .padding(.bottom, 4)
    }

    /// 넘길 수 없는 쪽도 지우지 않고 흐리게 둔다. 사라지면 달 이름이 좌우로 움직인다.
    private func arrow(
        _ systemName: String,
        enabled: Bool,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Palette.inkSecondary)
                .frame(width: 36, height: 36)
                .contentShape(Rectangle())
        }
        .pressable()
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.25)
        .accessibilityLabel(label)
        .accessibilityHidden(!enabled)
    }

    // MARK: - 목록

    /// §12 — 세션 0건이어도 크래시 없이 그려져야 한다.
    /// 기록이 있는 달 사이에 빈 달이 끼어 있을 수도 있다.
    private var emptyState: some View {
        VStack(spacing: 6) {
            Text(months.isEmpty ? "아직 기록이 없습니다" : "이 달은 기록이 없습니다")
                .font(Typography.statValue)
                .foregroundStyle(Palette.ink)
            Text(months.isEmpty ? "세션을 하나 끝내면 여기에 쌓입니다" : "화살표로 다른 달을 봅니다")
                .font(Typography.statCaption)
                .foregroundStyle(Palette.inkSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func list(_ current: HistoryMonth) -> some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: 28) {
                ForEach(current.days) { day in
                    VStack(alignment: .leading, spacing: 14) {
                        dayHeader(day)

                        ForEach(day.sessions) { session in
                            SessionRow(session: session) { editing = session }
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 40)
        }
        // 달을 넘길 때 목록이 맨 위에서 시작해야 한다. 스크롤 위치가 남아 있으면
        // 짧은 달로 넘어갔을 때 빈 화면처럼 보인다.
        .id(month)
    }

    private func dayHeader(_ day: HistoryDay) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(TimeDisplay.monthDay(day.date))
                    .font(Typography.statValue)
                    .foregroundStyle(Palette.ink)

                Spacer()

                Text("\(day.sessionCount)회 · \(TimeDisplay.hhmm(day.totalSeconds))")
                    .font(Typography.statCaption)
                    .foregroundStyle(Palette.inkSecondary)
                    .monospacedDigit()
            }

            Rectangle()
                .fill(Palette.stroke)
                .frame(height: Metrics.cardStrokeWidth)
        }
    }
}

#Preview {
    let store = SessionStore(inMemory: true)
    let settings = AppSettings()
    return HistoryView(
        store: store,
        recorder: SessionRecorder(
            store: store,
            calendar: CalendarService(),
            settings: settings
        ),
        initialMonth: .now
    )
}
