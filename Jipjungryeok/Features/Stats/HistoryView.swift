import SwiftUI
import FocusCore

/// §4.2 기록 — 지난 세션 전체를 날짜별로 훑어보는 시트.
///
/// 통계 화면의 회고 카드는 최근 5건만 보여준다. 그건 "요즘 어땠나" 를 흘깃 보는 자리고,
/// 이 화면은 "그때 뭘 했더라" 를 찾아 들어가는 자리다. 그래서 메모가 주인공이다.
/// 메모를 다시 읽을 곳이 없으면 애초에 메모를 쓸 이유도 없다.
///
/// 시간축을 왼쪽 열에 고정해 위에서 아래로 읽히게 했다. 세션마다 카드를 두르면
/// 하루에 여러 건 있을 때 테두리끼리 부딪혀 오히려 덩어리져 보인다.
///
/// 예전에는 목록을 열 때 한 번 읽어 통째로 넘겨받았다. 여기서 메모를 고칠 수 있게
/// 되면서 그 방식은 성립하지 않는다 — 방금 고친 메모가 화면에 그대로 옛 값으로
/// 남는다. 스토어를 들고 있다가 고칠 때마다 다시 읽는다.
struct HistoryView: View {

    let store: SessionStore
    let recorder: SessionRecorder

    @State private var days: [HistoryDay] = []
    @State private var editing: SessionRecord?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Palette.background
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                header

                if days.isEmpty {
                    emptyState
                } else {
                    list
                }
            }
        }
        .task { reload() }
        .sheet(item: $editing) { session in
            MemoEditSheet(session: session) { memo in
                recorder.updateMemo(memo, for: session.id)
                // 목록은 `days` 에 담아 둔 값이라 스스로 갱신되지 않는다.
                reload()
            }
        }
    }

    /// 정렬과 묶기는 `SessionHistory` 가 §4.2 규칙(`startAt` 기준)에 맞춰 한다.
    /// 여기서 다시 정렬하면 규칙이 두 곳으로 갈라진다.
    private func reload() {
        days = SessionHistory.byDay(store.allRecords())
    }

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

    /// §12 — 세션 0건이어도 크래시 없이 그려져야 한다.
    private var emptyState: some View {
        VStack(spacing: 6) {
            Text("아직 기록이 없습니다")
                .font(Typography.statValue)
                .foregroundStyle(Palette.ink)
            Text("세션을 하나 끝내면 여기에 쌓입니다")
                .font(Typography.statCaption)
                .foregroundStyle(Palette.inkSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var list: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: 28) {
                ForEach(days) { day in
                    VStack(alignment: .leading, spacing: 14) {
                        dayHeader(day)

                        ForEach(day.sessions) { session in
                            SessionRow(session: session) { editing = session }
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 40)
        }
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
        )
    )
}
