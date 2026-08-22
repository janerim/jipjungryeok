import SwiftUI
import FocusCore

/// §4.2 기록 — 지난 세션 전체를 날짜별로 훑어보는 시트.
///
/// 통계 화면의 회고 카드는 최근 3건만 보여준다. 그건 "요즘 어땠나" 를 흘깃 보는 자리고,
/// 이 화면은 "그때 뭘 했더라" 를 찾아 들어가는 자리다. 그래서 메모가 주인공이다.
/// 메모를 다시 읽을 곳이 없으면 애초에 메모를 쓸 이유도 없다.
///
/// 시간축을 왼쪽 열에 고정해 위에서 아래로 읽히게 했다. 세션마다 카드를 두르면
/// 하루에 여러 건 있을 때 테두리끼리 부딪혀 오히려 덩어리져 보인다.
struct HistoryView: View {

    let days: [HistoryDay]

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
        .presentationDragIndicator(.visible)
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
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 28) {
                ForEach(days) { day in
                    VStack(alignment: .leading, spacing: 14) {
                        dayHeader(day)

                        ForEach(day.sessions) { session in
                            SessionRow(session: session)
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
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
    let t0 = Date()
    let sessions = [
        SessionRecord(
            id: UUID(),
            startAt: t0.addingTimeInterval(-3000),
            endAt: t0.addingTimeInterval(-1500),
            plannedSeconds: 1500,
            actualSeconds: 1500,
            isCompleted: true,
            memo: "기획서 §7 다시 읽기"
        ),
        SessionRecord(
            id: UUID(),
            startAt: t0.addingTimeInterval(-9000),
            endAt: t0.addingTimeInterval(-8580),
            plannedSeconds: 1500,
            actualSeconds: 420,
            isCompleted: false,
            memo: nil
        ),
    ]
    return HistoryView(days: SessionHistory.byDay(sessions))
}
