import XCTest
import CoreGraphics
@testable import FocusCore

/// §4.1 다이얼 각도 계산.
///
/// 사분면 부호를 하나 뒤집어도 컴파일은 멀쩡히 되고 앱도 실행된다.
/// 다이얼만 엉뚱하게 돌 뿐이다. 그래서 좌표를 직접 못박아 둔다.
final class DialGeometryTests: XCTestCase {

    private let center = CGPoint(x: 170, y: 170)
    private let radius: CGFloat = 100

    private func assertPoint(
        _ actual: CGPoint,
        _ expectedX: CGFloat,
        _ expectedY: CGFloat,
        _ message: String,
        line: UInt = #line
    ) {
        XCTAssertEqual(actual.x, expectedX, accuracy: 0.001, message, line: line)
        XCTAssertEqual(actual.y, expectedY, accuracy: 0.001, message, line: line)
    }

    // MARK: - 12시가 0분, 시계방향

    func testZeroMinuteIsAtTwelveOClock() {
        let p = DialGeometry.point(atMinute: 0, radius: radius, center: center)
        assertPoint(p, 170, 70, "0분은 12시 방향(위)이어야 한다")
    }

    func testQuarterHoursGoClockwise() {
        assertPoint(
            DialGeometry.point(atMinute: 15, radius: radius, center: center),
            270, 170, "15분은 3시 방향(오른쪽)"
        )
        assertPoint(
            DialGeometry.point(atMinute: 30, radius: radius, center: center),
            170, 270, "30분은 6시 방향(아래)"
        )
        assertPoint(
            DialGeometry.point(atMinute: 45, radius: radius, center: center),
            70, 170, "45분은 9시 방향(왼쪽)"
        )
    }

    // MARK: - 터치 위치 → 분

    func testTouchPositionsMapToExpectedMinutes() {
        XCTAssertEqual(
            DialGeometry.snappedMinutes(at: CGPoint(x: 170, y: 70), center: center, previous: 30),
            60, "위쪽 터치는 60분"
        )
        XCTAssertEqual(
            DialGeometry.snappedMinutes(at: CGPoint(x: 270, y: 170), center: center, previous: 30),
            15, "오른쪽 터치는 15분"
        )
        XCTAssertEqual(
            DialGeometry.snappedMinutes(at: CGPoint(x: 170, y: 270), center: center, previous: 30),
            30, "아래쪽 터치는 30분"
        )
        XCTAssertEqual(
            DialGeometry.snappedMinutes(at: CGPoint(x: 70, y: 170), center: center, previous: 30),
            45, "왼쪽 터치는 45분"
        )
    }

    /// point() 로 만든 좌표를 다시 분으로 되돌리면 같은 값이 나와야 한다.
    func testPointAndSnapRoundTrip() {
        for minute in [1, 7, 13, 22, 29, 38, 44, 51, 59] {
            let p = DialGeometry.point(atMinute: Double(minute), radius: radius, center: center)
            XCTAssertEqual(
                DialGeometry.snappedMinutes(at: p, center: center, previous: minute),
                minute,
                "\(minute)분 왕복 실패"
            )
        }
    }

    // MARK: - 12시 경계 (§4.1 최소 1분 / 최대 60분)

    /// 58분 자리에서 12시를 넘어 2분 자리로 끌면 60분에서 붙잡혀야 한다.
    /// 안 그러면 다이얼이 한 바퀴 돌아 시간이 확 줄어든다.
    func testDraggingForwardPastTwelveClampsToMax() {
        let p = DialGeometry.point(atMinute: 2, radius: radius, center: center)
        XCTAssertEqual(DialGeometry.snappedMinutes(at: p, center: center, previous: 58), 60)
    }

    /// 반대 방향으로 넘으면 1분에서 붙잡힌다.
    func testDraggingBackwardPastTwelveClampsToMin() {
        let p = DialGeometry.point(atMinute: 58, radius: radius, center: center)
        XCTAssertEqual(DialGeometry.snappedMinutes(at: p, center: center, previous: 2), 1)
    }

    /// 경계를 넘지 않는 평범한 이동은 그대로 통과한다.
    func testNormalMovementIsNotClamped() {
        let cases: [(from: Int, to: Int)] = [(30, 35), (58, 59), (3, 2), (20, 19)]
        for c in cases {
            let p = DialGeometry.point(atMinute: Double(c.to), radius: radius, center: center)
            XCTAssertEqual(
                DialGeometry.snappedMinutes(at: p, center: center, previous: c.from),
                c.to,
                "\(c.from)분 → \(c.to)분 이동이 붙잡히면 안 된다"
            )
        }
    }

    /// 12시 정각은 0분이 아니라 60분으로 읽는다. 0분짜리 세션은 존재하지 않는다.
    func testExactTwelveReadsAsSixtyNotZero() {
        let top = CGPoint(x: center.x, y: center.y - radius)
        XCTAssertEqual(DialGeometry.snappedMinutes(at: top, center: center, previous: 59), 60)
    }

    // MARK: - 중심 데드존

    /// 정확히 중심을 누르면 atan2(0, 0) 이 0 을 돌려줘 15분으로 튄다.
    /// 방향이라는 게 없는 자리이므로 직전 값이 유지돼야 한다.
    func testCenterTouchKeepsPreviousValue() {
        XCTAssertEqual(DialGeometry.snappedMinutes(at: center, center: center, previous: 30), 30)
    }

    func testInsideDeadZoneKeepsPreviousValue() {
        for offset in [CGFloat(0), 5, 15] {
            let p = CGPoint(x: center.x + offset, y: center.y)
            XCTAssertEqual(
                DialGeometry.snappedMinutes(at: p, center: center, previous: 42),
                42,
                "중심에서 \(offset)pt 는 데드존 안이어야 한다"
            )
        }
    }

    func testOutsideDeadZoneReadsTheAngle() {
        let p = CGPoint(x: center.x + 17, y: center.y)
        XCTAssertEqual(
            DialGeometry.snappedMinutes(at: p, center: center, previous: 14),
            15,
            "데드존 밖이면 3시 방향이므로 15분"
        )
    }
}
