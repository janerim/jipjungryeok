import SwiftUI
import FocusCore

/// §4.2-3 일별 막대 차트.
///
/// - X축: 최근 10일. `dailyTotals` 가 이미 최신 순이므로 그대로 그리면 **최신이 왼쪽**이다.
/// - Y축: 0~8시간. 데이터가 넘으면 2시간 단위로 확장된 값이 `maxHours` 로 들어온다.
/// - 축 아래 `yyyy년 M월` 라벨.
struct DailyBarChart: View {

    let totals: [DailyTotal]
    let maxHours: Int
    let month: Date

    private let chartHeight: CGFloat = 140

    /// 값이 0인 날도 막대 자리는 보이게 둔다. 그래야 축이 읽힌다.
    private let minimumBarHeight: CGFloat = 2

    var body: some View {
        VStack(spacing: 8) {
            HStack(alignment: .top, spacing: 6) {
                Text("\(maxHours)h")
                    .font(Typography.statCaption)
                    .foregroundStyle(Palette.inkSecondary)
                    .frame(width: 24, alignment: .trailing)

                bars
            }

            Rectangle()
                .fill(Palette.stroke)
                .frame(height: Metrics.cardStrokeWidth)
                .padding(.leading, 30)

            Text(TimeDisplay.yearMonth(month))
                .font(Typography.statCaption)
                .foregroundStyle(Palette.inkSecondary)
        }
    }

    private var bars: some View {
        HStack(alignment: .bottom, spacing: 6) {
            ForEach(totals) { total in
                RoundedRectangle(cornerRadius: 3)
                    .fill(Palette.ink)
                    .frame(height: barHeight(for: total.seconds))
            }
        }
        .frame(height: chartHeight, alignment: .bottom)
    }

    private func barHeight(for seconds: Int) -> CGFloat {
        // maxHours 는 항상 8 이상이라 0으로 나눌 일은 없지만, 방어해 둔다.
        let capacity = CGFloat(max(1, maxHours) * 3600)
        let ratio = min(1, max(0, CGFloat(seconds) / capacity))
        return max(minimumBarHeight, ratio * chartHeight)
    }
}

#Preview("빈 상태") {
    let summary = StatsSummary.empty()
    return ZStack {
        Palette.background.ignoresSafeArea()
        DailyBarChart(
            totals: summary.dailyTotals,
            maxHours: summary.chartMaxHours,
            month: summary.chartMonth
        )
        .padding(20)
    }
}
