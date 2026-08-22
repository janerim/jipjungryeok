import SwiftUI
import FocusCore

/// §4.1 타이머 화면 — 앱 실행 시 첫 화면.
struct TimerView: View {

    let model: TimerViewModel

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // 화면 맨 위에 붙으면 노치 바로 아래에 매달린 것처럼 보인다.
                // 비율로 잡아 작은 기기에서도 같은 인상이 되게 한다.
                statusHeader
                    .padding(.top, geometry.size.height * 0.12)

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

                // 다이얼과 숫자 사이는 고정 간격이다. 여기에 Spacer 를 두면 남는 세로
                // 공간이 전부 이 틈으로 몰려 숫자가 화면 맨 아래에 떨어져 붙는다.
                Spacer(minLength: 0)
                    .frame(height: 48)

                // 숫자가 곧 시작·정지 버튼이다 (§4.1). 다이얼은 시간을 맞추는 일만 한다.
                VStack(spacing: 6) {
                    Text(model.countdownText)
                        .font(Typography.countdown)
                        .foregroundStyle(Palette.ink)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .animation(.easeInOut(duration: 0.2), value: model.countdownText)

                    // 눌러야 시작한다는 것을 알 방법이 이것뿐이다. 돌아가기 시작하면
                    // 사라진다 — 그때부터는 숫자 자체가 상태를 말한다.
                    Text(model.primaryHint)
                        .font(Typography.statCaption)
                        .foregroundStyle(Palette.inkSecondary)
                        .opacity(model.primaryHint.isEmpty ? 0 : 1)
                        .animation(.easeInOut(duration: 0.2), value: model.primaryHint)
                }
                // 글자만으로는 손가락이 닿기 어렵다.
                .padding(.horizontal, 32)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
                .onTapGesture { model.primaryTapped() }

                // 남는 공간은 전부 숫자 아래로 보낸다. 최소값은 하단 페이지
                // 인디케이터와 겹치지 않을 만큼.
                Spacer(minLength: 44)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }

    /// 다이얼은 터치 여백(§4.0, 사방 40pt)까지 포함해서 자리를 차지하므로,
    /// 화면 폭에서 그만큼을 먼저 빼고 크기를 정한다. 고정값을 쓰면 좁은 기기에서
    /// 좌우가 잘린다.
    ///
    /// 좌우 여유를 32pt 에서 16pt 로 줄이고 상한도 올려 다이얼을 키웠다.
    /// 그만큼 다이얼 히트 영역이 화면 가장자리에 가까워지므로, 다이얼과 같은 높이의
    /// 좌우 끝에서는 페이지 스와이프가 어려워진다. 다이얼 **위아래** 여백은 그대로
    /// 남아 있어서 §4.0 의 "바깥에서 스와이프" 자체는 유지된다.
    private func dialDiameter(in size: CGSize) -> CGFloat {
        let widthLimit = size.width - Metrics.dialHitSlop * 2 - 16
        let heightLimit = size.height * 0.56
        return max(160, min(320, min(widthLimit, heightLimit)))
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
            model: TimerViewModel(
                recorder: recorder,
                notifications: NotificationService(),
                defaultMinutes: settings.defaultMinutes
            )
        )
    }
}
