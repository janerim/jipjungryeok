import SwiftUI
import FocusCore

/// §4.1 원형 다이얼.
///
/// 12시 방향이 0, 시계방향으로 한 바퀴가 `TimerEngine.maximumMinutes`(90분).
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

    // MARK: - 눈금 간격

    /// 짧은 틱 간격(분). 스냅 단위(1분)와는 무관하다.
    private static let tickInterval = 5

    /// 굵은 틱과 숫자 라벨 간격(분).
    private static let labelInterval = 15

    /// 다이얼 한 바퀴에 해당하는 분
    private var fullTurnMinutes: Double { Double(TimerEngine.maximumMinutes) }

    // MARK: - 치수

    /// 터치 영역까지 포함한 뷰 전체 크기
    private var side: CGFloat { diameter + Metrics.dialHitSlop * 2 }
    private var center: CGPoint { CGPoint(x: side / 2, y: side / 2) }

    /// 눈금 링의 바깥 반지름
    private var radius: CGFloat { diameter / 2 }

    private var minorTickLength: CGFloat { radius * 0.055 }
    private var majorTickLength: CGFloat { radius * 0.10 }

    /// 숫자 라벨을 눈금 **바깥**에 둔다.
    ///
    /// 라벨이 눈금 안쪽에 있으면 부채꼴이 라벨에 막혀 반지름의 70%대에서 멈춘다.
    /// 밖으로 빼면 원 안쪽이 통째로 부채꼴 몫이 된다. 라벨이 차지하는 자리는
    /// 어차피 터치 여백(`dialHitSlop`, 사방 40pt)이라 화면을 더 먹지도 않는다.
    private var labelRadius: CGFloat { radius + 20 }

    /// 부채꼴은 눈금 안쪽 끝에서 4pt 만 띄운다.
    ///
    /// 채워진 넓이가 곧 남은 시간이라 이 도형이 화면의 주인공이다.
    /// 비율이 아니라 눈금 길이에서 빼는 이유는, 작은 기기에서 비율로 잡으면
    /// 간격이 같이 줄어 눈금에 붙어버리기 때문이다.
    private var sectorRadius: CGFloat { radius - majorTickLength - 4 }

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

    /// 1분마다 실눈금, 5분마다 중간, 15분마다 굵고 길게 (라벨이 붙는 자리).
    ///
    /// 세 단계로 나누는 것이 핵심이다. 90개를 같은 굵기로 그리면 정말 회색 띠가 되지만,
    /// 위계가 있으면 눈은 15분 단위를 먼저 읽고 그 사이를 1분 눈금으로 센다.
    /// 손목시계 문자판이 쓰는 방식이다.
    ///
    /// **스냅은 원래부터 1분 단위였다** — 눈금은 그것을 눈에 보이게 만들 뿐이고,
    /// 둘은 별개다.
    private var ticks: some View {
        ForEach(0..<TimerEngine.maximumMinutes, id: \.self) { minute in
            let tier = tickTier(for: minute)
            Path { path in
                path.move(to: point(atMinute: Double(minute), radius: radius))
                path.addLine(
                    to: point(atMinute: Double(minute), radius: radius - tier.length)
                )
            }
            .stroke(Palette.inkSecondary, lineWidth: tier.width)
            // 실눈금까지 같은 농도로 찍으면 링 전체가 탁해진다.
            .opacity(tier.opacity)
        }
    }

    private func tickTier(for minute: Int) -> (length: CGFloat, width: CGFloat, opacity: Double) {
        if minute % Self.labelInterval == 0 {
            return (majorTickLength, 2, 1)
        }
        if minute % Self.tickInterval == 0 {
            return (minorTickLength, 1, 0.85)
        }
        return (minorTickLength * 0.5, 0.75, 0.45)
    }

    /// 0, 15, 30, 45, 60, 75
    private var tickLabels: some View {
        ForEach(Array(stride(from: 0, to: TimerEngine.maximumMinutes, by: Self.labelInterval)), id: \.self) { minute in
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
            .position(point(atMinute: fraction * fullTurnMinutes, radius: sectorRadius))
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
                        Int((fraction * fullTurnMinutes).rounded())
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
            fraction: 25.0 / 90.0,
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
            fraction: 12.0 / 90.0,
            onDragBegan: {},
            onMinutesChanged: { _ in },
            onDragEnded: {},
            onTap: {},
            onLongPress: {}
        )
    }
    .preferredColorScheme(.dark)
}
