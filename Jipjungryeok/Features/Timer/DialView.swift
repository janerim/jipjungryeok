import SwiftUI
import FocusCore

/// §4.1 원형 다이얼.
///
/// 12시 방향이 0, 시계방향으로 60분 한 바퀴.
/// 그려지는 지름은 `diameter` 이지만 뷰의 실제 크기는 사방으로 `Metrics.dialHitSlop`
/// 만큼 넓다. §4.0 의 "다이얼 영역 = 반지름 + 40pt" 가 이 여백이며, 그 안에서
/// 시작한 드래그는 `highPriorityGesture` 로 페이지 스와이프를 이긴다.
struct DialView: View {

    /// 그려지는 다이얼의 지름
    let diameter: CGFloat

    let phase: TimerPhase

    /// 0...1. 부채꼴 채움 비율이자 핸들 위치.
    let fraction: Double

    let onDragBegan: () -> Void
    /// 1분 스냅이 적용된 값이 들어온다.
    let onMinutesChanged: (Int) -> Void
    let onDragEnded: () -> Void
    let onTap: () -> Void
    let onLongPress: () -> Void

    @State private var isDragging = false
    @State private var lastMinutes = TimerEngine.maximumMinutes

    // MARK: - 치수

    /// 터치 영역까지 포함한 뷰 전체 크기
    private var side: CGFloat { diameter + Metrics.dialHitSlop * 2 }
    private var center: CGPoint { CGPoint(x: side / 2, y: side / 2) }

    /// 눈금 링의 바깥 반지름
    private var radius: CGFloat { diameter / 2 }

    private var minorTickLength: CGFloat { radius * 0.055 }
    private var majorTickLength: CGFloat { radius * 0.10 }
    private var labelRadius: CGFloat { radius * 0.80 }
    /// 부채꼴은 숫자 라벨 안쪽에 그려야 눈금과 겹치지 않는다.
    private var sectorRadius: CGFloat { radius * 0.68 }

    // MARK: -

    var body: some View {
        ZStack {
            sector
            ticks
            tickLabels
            handle
        }
        .frame(width: side, height: side)
        .contentShape(Circle())
        .highPriorityGesture(dragGesture, including: allowsDrag ? .all : .subviews)
        .onTapGesture {
            if allowsTap { onTap() }
        }
        .onLongPressGesture(minimumDuration: 0.6) {
            if allowsLongPress { onLongPress() }
        }
    }

    // MARK: - 그리기

    private var sector: some View {
        Path { path in
            path.move(to: center)
            path.addArc(
                center: center,
                radius: sectorRadius,
                startAngle: .degrees(-90),
                endAngle: .degrees(-90 + 360 * fraction),
                // SwiftUI 는 y 축이 아래로 향하므로, false 가 화면상 시계방향이다.
                clockwise: false
            )
            path.closeSubpath()
        }
        .fill(Palette.ink)
        // 일시정지 중임을 알 수 있게 살짝 죽인다. 상단 상태 표시는 §4.1 대로 고정이라
        // 다른 단서가 없다.
        .opacity(phase == .paused ? 0.45 : 1)
        .animation(.easeInOut(duration: 0.2), value: phase)
    }

    /// 1분마다 짧은 틱, 5분마다 굵은 틱
    private var ticks: some View {
        ForEach(0..<60, id: \.self) { minute in
            let isMajor = minute % 5 == 0
            Path { path in
                path.move(to: point(atMinute: Double(minute), radius: radius))
                path.addLine(
                    to: point(
                        atMinute: Double(minute),
                        radius: radius - (isMajor ? majorTickLength : minorTickLength)
                    )
                )
            }
            .stroke(Palette.inkSecondary, lineWidth: isMajor ? 2 : 1)
        }
    }

    /// 0, 5, 10 … 55
    private var tickLabels: some View {
        ForEach(Array(stride(from: 0, to: 60, by: 5)), id: \.self) { minute in
            Text("\(minute)")
                .font(Typography.dialTick)
                .foregroundStyle(Palette.inkSecondary)
                .position(point(atMinute: Double(minute), radius: labelRadius))
        }
    }

    private var handle: some View {
        Circle()
            .fill(Palette.handle)
            .overlay(
                Circle().stroke(Palette.stroke, lineWidth: Metrics.cardStrokeWidth)
            )
            .frame(width: 22, height: 22)
            .position(point(atMinute: fraction * 60, radius: sectorRadius))
    }

    // MARK: - 제스처

    private var allowsDrag: Bool { phase == .idle || phase == .paused }
    private var allowsTap: Bool { phase == .running || phase == .paused }
    private var allowsLongPress: Bool { phase != .idle }

    private var dragGesture: some Gesture {
        // minimumDistance 를 0 으로 두면 탭까지 드래그가 삼켜 일시정지가 동작하지 않는다.
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                if !isDragging {
                    isDragging = true
                    // 경계 판정의 기준점을 현재 다이얼 값으로 맞춰 둔다.
                    lastMinutes = max(
                        TimerEngine.minimumMinutes,
                        Int((fraction * 60).rounded())
                    )
                    onDragBegan()
                }
                let minutes = snappedMinutes(from: value.location)
                lastMinutes = minutes
                onMinutesChanged(minutes)
            }
            .onEnded { _ in
                isDragging = false
                onDragEnded()
            }
    }

    // MARK: - 기하

    /// 각도 계산 자체는 `FocusCore.DialGeometry` 에 있다.
    /// 화면 없이 단위 테스트로 검증돼야 하는 순수 계산이라 여기 두지 않는다 (§9).
    private func point(atMinute minute: Double, radius r: CGFloat) -> CGPoint {
        DialGeometry.point(atMinute: minute, radius: r, center: center)
    }

    private func snappedMinutes(from location: CGPoint) -> Int {
        DialGeometry.snappedMinutes(at: location, center: center, previous: lastMinutes)
    }
}

#Preview("idle · 25분") {
    ZStack {
        Palette.background.ignoresSafeArea()
        DialView(
            diameter: 260,
            phase: .idle,
            fraction: 25.0 / 60.0,
            onDragBegan: {},
            onMinutesChanged: { _ in },
            onDragEnded: {},
            onTap: {},
            onLongPress: {}
        )
    }
}

#Preview("paused · 12분 남음") {
    ZStack {
        Palette.background.ignoresSafeArea()
        DialView(
            diameter: 260,
            phase: .paused,
            fraction: 12.0 / 60.0,
            onDragBegan: {},
            onMinutesChanged: { _ in },
            onDragEnded: {},
            onTap: {},
            onLongPress: {}
        )
    }
    .preferredColorScheme(.dark)
}
