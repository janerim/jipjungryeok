import SwiftUI
import FocusCore

/// §4.2-2 이번 주 7칸. 통계 화면과 홈 위젯(§8.1)이 함께 쓴다.
///
/// 총합보다 "며칠 나왔나" 가 행동을 바꾼다. 그래서 막대 높이보다 **빈 칸이 보이는 것**이
/// 이 그림의 목적이다.
///
/// 왼쪽이 월요일, 오른쪽이 일요일이다(§1-1). 시간은 왼쪽에서 오른쪽으로 흐른다 —
/// 사용자가 살면서 본 모든 차트가 그렇다.
struct WeekStrip: View {

    let totals: [DailyTotal]

    /// `weekdayTotals` 는 월요일이 0번임이 집계에서 보장된다(테스트로 못박음).
    private static let labels = ["월", "화", "수", "목", "금", "토", "일"]

    /// 위젯은 세로가 좁아서 낮게 그린다.
    var barHeight: CGFloat = 76
    var showsLabels: Bool = true

    private let calendar = Calendar.focus

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            ForEach(Array(totals.enumerated()), id: \.element.id) { index, total in
                column(index: index, total: total)
            }
        }
    }

    private func column(index: Int, total: DailyTotal) -> some View {
        let isToday = calendar.isDate(total.date, inSameDayAs: Date())

        return VStack(spacing: 8) {
            ZStack(alignment: .bottom) {
                // 바닥 선이 있어야 빈 날도 "자리는 있는데 비었다" 로 읽힌다.
                RoundedRectangle(cornerRadius: 3)
                    .fill(Palette.stroke)
                    .frame(height: 3)

                RoundedRectangle(cornerRadius: 3)
                    .fill(isToday ? Palette.ink : Palette.inkSecondary)
                    .frame(height: height(for: total.seconds))
            }
            .frame(height: barHeight, alignment: .bottom)

            if showsLabels {
                Text(Self.labels[min(index, Self.labels.count - 1)])
                    .font(Typography.statCaption)
                    .foregroundStyle(isToday ? Palette.ink : Palette.inkSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(Self.labels[min(index, Self.labels.count - 1)])요일 "
            + TimeDisplay.hourMinuteText(total.seconds)
        )
    }

    /// 기준(5시간)이 칸 높이의 몇 할을 차지하는가.
    ///
    /// 위쪽 22% 를 초과분 몫으로 비워 둔다. 기준에서 막대를 잘라 버리면 5시간·7시간·
    /// 10시간이 전부 같은 높이가 되어, 오르막인 한 주가 평평하게 보인다.
    private let referenceRatio: Double = 0.78

    /// 링과 같은 기준으로 재야 링과 막대가 같은 말을 한다.
    ///
    /// 값이 0 보다 크면 최소 6pt 는 보장한다. 5분짜리 세션이 바닥 선에 묻혀
    /// 안 한 날처럼 보이면 이 그림의 목적이 무너진다.
    private func height(for seconds: Int) -> CGFloat {
        guard seconds > 0 else { return 0 }
        let fill = StatsSummary.fillFraction(forSeconds: seconds) * referenceRatio
        let over = StatsSummary.overflowFraction(forSeconds: seconds) * (1 - referenceRatio)
        return max(6, barHeight * (fill + over))
    }
}

#Preview {
    let calendar = Calendar.focus
    let monday = calendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
    let seconds = [30 * 60, 2 * 3600, 45 * 60, 3 * 3600, 0, 0, 0]

    return ZStack {
        Palette.background.ignoresSafeArea()
        WeekStrip(
            totals: (0..<7).map { offset in
                DailyTotal(
                    date: calendar.date(byAdding: .day, value: offset, to: monday) ?? monday,
                    seconds: seconds[offset]
                )
            }
        )
        .padding(.horizontal, 20)
    }
}
