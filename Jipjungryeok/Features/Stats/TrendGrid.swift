import SwiftUI
import FocusCore

/// §4.2-1 추이 — 2행 그리드.
///
/// 1행: 오늘 / 이번 주 / 이번 달
/// 2행: 최근 7일 / 최근 28일
struct TrendGrid: View {

    let summary: StatsSummary

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                TrendCell(title: "오늘", seconds: summary.todaySeconds)
                TrendCell(title: "이번 주", seconds: summary.weekSeconds)
                TrendCell(title: "이번 달", seconds: summary.monthSeconds)
            }
            HStack(spacing: 10) {
                TrendCell(title: "최근 7일", seconds: summary.last7DaysSeconds)
                TrendCell(title: "최근 28일", seconds: summary.last28DaysSeconds)
            }
        }
    }
}

private struct TrendCell: View {

    let title: String
    let seconds: Int

    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(Typography.statCaption)
                .foregroundStyle(Palette.inkSecondary)
            Text(TimeDisplay.hhmm(seconds))
                .font(Typography.statValue)
                .foregroundStyle(Palette.ink)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .overlay(
            RoundedRectangle(cornerRadius: Metrics.cardCornerRadius)
                .stroke(Palette.stroke, lineWidth: Metrics.cardStrokeWidth)
        )
    }
}

#Preview {
    ZStack {
        Palette.background.ignoresSafeArea()
        TrendGrid(summary: .empty())
            .padding(20)
    }
}
