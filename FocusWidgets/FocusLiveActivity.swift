import ActivityKit
import WidgetKit
import SwiftUI
import FocusCore

/// §8.3 잠금화면 Live Activity 와 Dynamic Island.
///
/// 카운트다운은 전부 `Text(timerInterval:countsDown:)` 과
/// `ProgressView(timerInterval:)` 이 맡는다. 시스템이 알아서 줄여 주므로 앱이
/// 백그라운드에 있어도, push 가 없어도 초 단위로 정확하다.
///
/// 일시정지 중에는 그것들을 쓸 수 없다 — 시스템 카운트다운은 멈추지 않는다.
/// 그래서 얼어붙은 값을 정적 텍스트로 보여준다.
struct FocusLiveActivity: Widget {

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FocusActivityAttributes.self) { context in
            lockScreen(context)
                .activityBackgroundTint(Palette.background)
                .activitySystemActionForegroundColor(Palette.ink)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    ring(context)
                        .frame(width: 44, height: 44)
                }
                DynamicIslandExpandedRegion(.center) {
                    remaining(context)
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(endsAtText(context))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } compactLeading: {
                Text("🎯")
            } compactTrailing: {
                remaining(context)
                    .font(.caption2)
                    .monospacedDigit()
            } minimal: {
                ring(context)
            }
        }
    }

    // MARK: -

    private func lockScreen(
        _ context: ActivityViewContext<FocusActivityAttributes>
    ) -> some View {
        HStack(spacing: 16) {
            ring(context)
                .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: 4) {
                Text("🎯 집중")
                    .font(Typography.statCaption)
                    .foregroundStyle(Palette.inkSecondary)

                remaining(context)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(Palette.ink)

                Text(endsAtText(context))
                    .font(Typography.statCaption)
                    .foregroundStyle(Palette.inkSecondary)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
    }

    @ViewBuilder
    private func remaining(
        _ context: ActivityViewContext<FocusActivityAttributes>
    ) -> some View {
        if let frozen = context.state.pausedRemainingSeconds {
            Text(TimeDisplay.countdown(frozen))
                .monospacedDigit()
        } else {
            Text(timerInterval: context.state.startDate...context.state.endDate,
                 pauseTime: nil,
                 countsDown: true)
                .monospacedDigit()
        }
    }

    @ViewBuilder
    private func ring(
        _ context: ActivityViewContext<FocusActivityAttributes>
    ) -> some View {
        if context.state.isPaused {
            // 멈춘 링은 진행이 없으므로 시스템 타이머 스타일을 쓸 수 없다.
            Circle()
                .stroke(Palette.stroke, lineWidth: 5)
                .overlay(
                    Image(systemName: "pause.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Palette.inkSecondary)
                )
        } else {
            ProgressView(
                timerInterval: context.state.startDate...context.state.endDate,
                countsDown: true
            ) {
                EmptyView()
            } currentValueLabel: {
                EmptyView()
            }
            .progressViewStyle(.circular)
            .tint(Palette.ink)
        }
    }

    private func endsAtText(
        _ context: ActivityViewContext<FocusActivityAttributes>
    ) -> String {
        if context.state.isPaused { return "일시정지" }
        return "\(TimeDisplay.clockTime(context.state.endDate)) 종료 예정"
    }
}
