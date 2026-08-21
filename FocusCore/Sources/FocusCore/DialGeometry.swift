import CoreGraphics
import Foundation

/// §4.1 다이얼의 각도 계산.
///
/// 12시 방향이 0분, 시계방향으로 **한 바퀴가 `TimerEngine.maximumMinutes`** 다.
/// 스케일이 그 상수 하나에서 나오므로 최대 시간을 바꿔도 여기는 손댈 필요가 없다.
///
/// 화면 코드가 아니라 여기 있는 이유: 사분면과 경계 처리가 눈으로 확인하기
/// 까다로운 부분인데, 순수 함수로 빼두면 시뮬레이터 없이 단위 테스트로 못박을 수 있다.
/// 나중에 워치의 Digital Crown 입력(§8-1-2)도 같은 좌표계를 쓴다.
public enum DialGeometry {

    /// 각도를 신뢰할 수 없는 중심 근방의 반지름.
    /// 여기서는 손가락이 조금만 흔들려도 각도가 크게 튄다.
    public static let deadZoneRadius: CGFloat = 16

    /// 다이얼 한 바퀴에 해당하는 분.
    private static var fullTurnMinutes: Double {
        Double(TimerEngine.maximumMinutes)
    }

    /// 분 위치에 해당하는 원 위의 좌표.
    public static func point(
        atMinute minute: Double,
        radius: CGFloat,
        center: CGPoint
    ) -> CGPoint {
        let radians = CGFloat((minute / fullTurnMinutes * 360 - 90) * .pi / 180)
        return CGPoint(
            x: center.x + cos(radians) * radius,
            y: center.y + sin(radians) * radius
        )
    }

    /// 터치 좌표를 1분 단위로 스냅한 값으로 바꾼다 (최소 1분 / 최대 `maximumMinutes`).
    ///
    /// - Parameter previous: 직전에 확정된 분. 12시 경계를 넘는 드래그의 방향 판정에 쓴다.
    public static func snappedMinutes(
        at location: CGPoint,
        center: CGPoint,
        previous: Int
    ) -> Int {
        let dx = location.x - center.x
        let dy = location.y - center.y

        // 정확히 중심이면 atan2(0, 0) 이 0 을 돌려줘 다이얼이 3시 방향 값으로 튄다.
        // 중심 근방은 애초에 방향이라는 게 없으므로 직전 값을 유지한다.
        if dx * dx + dy * dy < deadZoneRadius * deadZoneRadius {
            return previous
        }

        // atan2 의 0 은 3시 방향이므로 90 을 더해 12시 기준으로 돌린다.
        var degrees = atan2(dy, dx) * 180 / .pi + 90
        if degrees < 0 { degrees += 360 }

        var value = Int((degrees / 360 * CGFloat(fullTurnMinutes)).rounded())
        // 12시 정각 위치는 0분이 아니라 최대값으로 읽는다. 0분짜리 세션은 없다.
        if value <= 0 || value > TimerEngine.maximumMinutes {
            value = TimerEngine.maximumMinutes
        }

        // 12시 경계를 그냥 넘기면 최대값 ↔ 1분 으로 값이 튄다.
        // 직전 값이 어느 쪽 사분면에 있었는지 보고 붙잡는다.
        let upperQuarter = fullTurnMinutes * 0.75
        let lowerQuarter = fullTurnMinutes * 0.25
        if Double(previous) >= upperQuarter && Double(value) <= lowerQuarter {
            return TimerEngine.maximumMinutes
        }
        if Double(previous) <= lowerQuarter && Double(value) >= upperQuarter {
            return TimerEngine.minimumMinutes
        }
        return value
    }
}
