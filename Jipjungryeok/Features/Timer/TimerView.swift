import SwiftUI
import FocusCore

/// §4.1 타이머 화면 — 앱 실행 시 첫 화면.
struct TimerView: View {

    let model: TimerViewModel

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                statusHeader
                    .padding(.top, 28)

                Spacer(minLength: 8)

                DialView(
                    diameter: dialDiameter(in: geometry.size),
                    phase: model.phase,
                    fraction: model.dialFraction,
                    onDragBegan: { model.dialDragBegan() },
                    onMinutesChanged: { model.dialDragged(toMinutes: $0) },
                    onDragEnded: { model.dialDragEnded() },
                    onTap: { model.dialTapped() },
                    onLongPress: { model.dialLongPressed() }
                )

                Spacer(minLength: 8)

                Text(model.countdownText)
                    .font(Typography.countdown)
                    .foregroundStyle(Palette.ink)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(.easeInOut(duration: 0.2), value: model.countdownText)

                // 하단 페이지 인디케이터와 겹치지 않게 띄운다
                Spacer()
                    .frame(height: 44)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }

    /// 다이얼은 터치 여백(§4.0, 사방 40pt)까지 포함해서 자리를 차지하므로,
    /// 화면 폭에서 그만큼을 먼저 빼고 크기를 정한다. 고정값을 쓰면 좁은 기기에서
    /// 좌우가 잘린다.
    private func dialDiameter(in size: CGSize) -> CGFloat {
        let widthLimit = size.width - Metrics.dialHitSlop * 2 - 32
        let heightLimit = size.height * 0.46
        return max(160, min(280, min(widthLimit, heightLimit)))
    }

    /// 세션이 하나뿐이므로 선택 UI 없이 고정 표시 (§4.1)
    private var statusHeader: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Palette.accent)
                .frame(width: 8, height: 8)
            Text("🎯 집중")
                .font(Typography.statusLabel)
                .foregroundStyle(Palette.ink)
        }
    }
}

#Preview {
    let store = SessionStore(inMemory: true)
    let settings = AppSettings()
    let recorder = SessionRecorder(
        store: store,
        calendar: CalendarService(),
        settings: settings
    )
    return ZStack {
        Palette.background.ignoresSafeArea()
        TimerView(
            model: TimerViewModel(recorder: recorder, notifications: NotificationService())
        )
    }
}
