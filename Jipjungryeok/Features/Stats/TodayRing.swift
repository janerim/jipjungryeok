import SwiftUI
import FocusCore

/// §4.2-1 오늘 집중 시간 링.
///
/// 다이얼과 같은 시각 언어를 쓴다. 12시에서 시작해 시계방향으로 차오르고, 채워진
/// 양이 곧 시간이다. 통계 화면에 들어왔을 때 "다른 앱" 처럼 보이지 않아야 한다.
///
/// 한 바퀴는 고정 5시간이다(`StatsSummary.fullRingSeconds`). 목표 설정 기능을 만들지
/// 않기 때문에(규칙 5) 기준이 하나 필요한데, 그날그날 최댓값에 맞춰 늘리면 잘한 날과
/// 못한 날이 똑같이 꽉 차 보인다.
///
/// 넘긴 만큼은 **안쪽에 얇은 두 번째 호**로 그린다. 같은 궤도에 겹쳐 그리면 색이
/// 같아 아예 안 보이고, 그렇다고 상한에서 멈추면 5시간·7시간·10시간이 전부
/// 똑같은 그림이 된다.
struct TodayRing: View {

    let seconds: Int

    private var fraction: Double { StatsSummary.fillFraction(forSeconds: seconds) }
    private var overflow: Double { StatsSummary.overflowFraction(forSeconds: seconds) }

    private let diameter: CGFloat = 168
    private let lineWidth: CGFloat = 14
    private let overflowLineWidth: CGFloat = 5

    /// 두 번째 호를 바깥 링 안쪽으로 들여놓는 양. 두 획이 닿으면 한 덩어리로 보인다.
    private var overflowInset: CGFloat { lineWidth / 2 + 4 + overflowLineWidth / 2 }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Palette.stroke, lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: fraction)
                .stroke(
                    Palette.ink,
                    // 끝을 둥글게 해야 값이 작을 때도 점이 아니라 획으로 보인다.
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                // trim 은 3시 방향에서 시작한다. 다이얼과 맞추려면 12시로 돌린다.
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.3), value: fraction)

            if overflow > 0 {
                Circle()
                    .trim(from: 0, to: overflow)
                    .stroke(
                        Palette.ink,
                        style: StrokeStyle(lineWidth: overflowLineWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .padding(overflowInset)
                    .animation(.easeInOut(duration: 0.3), value: overflow)
            }

            VStack(spacing: 2) {
                Text("오늘")
                    .font(Typography.statCaption)
                    .foregroundStyle(Palette.inkSecondary)

                Text(TimeDisplay.hhmm(seconds))
                    .font(Typography.statusLabel)
                    .foregroundStyle(Palette.ink)
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
        }
        .frame(width: diameter, height: diameter)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("오늘 집중 시간 \(TimeDisplay.hourMinuteText(seconds))")
    }
}

#Preview {
    ZStack {
        Palette.background.ignoresSafeArea()
        VStack(spacing: 32) {
            TodayRing(seconds: 0)
            TodayRing(seconds: 51 * 60)
            TodayRing(seconds: 5 * 3600)
        }
    }
}
