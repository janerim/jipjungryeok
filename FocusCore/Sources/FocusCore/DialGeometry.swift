import CoreGraphics
import Foundation

/// §4.1 다이얼의 각도 계산.
///
/// 12시 방향이 0분, 시계방향으로 한 바퀴가 60분이다.
///
/// 화면 코드가 아니라 여기 있는 이유: 사분면과 경계 처리가 눈으로 확인하기
/// 까다로운 부분인데, 순수 함수로 빼두면 시뮬레이터 없이 단위 테스트로 못박을 수 있다.
/// 나중에 워치의 Digital Crown 입력(§8-1-2)도 같은 좌표계를 쓴다.
public enum DialGeometry {

    /// 각도를 신뢰할 수 없는 중심 근방의 반지름.
    /// 여기서는 손가락이 조금만 흔들려도 각도가 크게 튄다.
    public static let deadZoneRadius: CGFloat = 16

    /// 분 위치에 해당하는 원 위의 좌표.
    public static func point(
        atMinute minute: Double,
        radius: CGFloat,
        center: CGPoint
    ) -> CGPoint {
        let radians = CGFloat((minute / 60 * 360 - 90) * .pi / 180)
        return CGPoint(
            x: center.x + cos(radians) * radius,
            y: center.y + sin(radians) * radius
        )
    }

    /// 터치 좌표를 1분 단위로 스냅한 값으로 바꾼다 (최소 1분 / 최대 60분).
    ///
    /// - Parameter previous: 직전에 확정된 분. 12시 경계를 넘는 드래그의 방향 판정에 쓴다.
    public static func snappedMinutes(
        at location: CGPoint,
        center: CGPoint,
        previous: Int
    ) -> Int {
        let dx = location.x - center.x
        let dy = location.y - center.y

        // 정확히 중심이면 atan2(0, 0) 이 0 을 돌려줘 다이얼이 15분(3시 방향)으로 튄다.
        // 중심 근방은 애초에 방향이라는 게 없으므로 직전 값을 유지한다.
        if dx * dx + dy * dy < deadZoneRadius * deadZoneRadius {
            return previous
        }

        // atan2 의 0 은 3시 방향이므로 90 을 더해 12시 기준으로 돌린다.
        var degrees = atan2(dy, dx) * 180 / .pi + 90
        if degrees < 0 { degrees += 360 }

        var value = Int((degrees / 360 * 60).rounded())
        // 12시 정각 위치는 0분이 아니라 60분으로 읽는다. 0분짜리 세션은 없다.
        if value <= 0 || value > TimerEngine.maximumMinutes {
            value = TimerEngine.maximumMinutes
        }

        // 12시 경계를 그냥 넘기면 60 ↔ 1 로 값이 튄다. 직전 값으로 방향을 보고 붙잡는다.
        if previous >= 45 && value <= 15 { return TimerEngine.maximumMinutes }
        if previous <= 15 && value >= 45 { return TimerEngine.minimumMinutes }
        return value
    }
}
