import Foundation

/// §5 위젯용 스냅샷.
///
/// 위젯은 SwiftData 를 직접 조회하지 않는다 (§8.1). 세션이 저장될 때마다 이 가벼운
/// 값을 App Group `UserDefaults` 에 써두고, 위젯은 그것만 읽는다. 익스텐션에서
/// 스토어를 여는 것보다 실패 위험이 훨씬 낮고, 마이그레이션에 끌려다니지도 않는다.
///
/// 담는 값은 §4.2 통계 화면과 같다 — 오늘, 이번 주, 그리고 월~일 7칸.
/// 위젯이 앱과 다른 숫자를 보여주면 어느 쪽이 맞는지 알 수 없다.
public struct StatsSnapshot: Codable, Equatable, Sendable {

    public var todaySeconds: Int
    public var weekSeconds: Int
    public var weekSessionCount: Int

    /// 이번 주 **월요일부터 일요일까지** 7칸, 초 단위 (§1-1).
    ///
    /// 화면과 같은 순서다. 위젯에서 뒤집어 그리면 같은 주가 두 가지 모양으로 보인다.
    public var weekdaySeconds: [Int]

    /// 이 스냅샷을 쓴 시각. 위젯이 낡은 값을 그리고 있는지 판별할 때 쓴다.
    public var updatedAt: Date

    public init(
        todaySeconds: Int,
        weekSeconds: Int,
        weekSessionCount: Int,
        weekdaySeconds: [Int],
        updatedAt: Date
    ) {
        self.todaySeconds = todaySeconds
        self.weekSeconds = weekSeconds
        self.weekSessionCount = weekSessionCount
        self.weekdaySeconds = weekdaySeconds
        self.updatedAt = updatedAt
    }

    /// 아직 한 번도 쓰인 적 없을 때. 위젯의 placeholder 이자 읽기 실패 시 대체값이다.
    ///
    /// 7칸을 0 으로 채워 두는 것이 중요하다. 빈 배열을 주면 위젯이 막대를 하나도
    /// 못 그려서 "고장난 위젯" 처럼 보인다.
    public static let zero = StatsSnapshot(
        todaySeconds: 0,
        weekSeconds: 0,
        weekSessionCount: 0,
        weekdaySeconds: Array(repeating: 0, count: StatsCalculator.weekdayCount),
        updatedAt: .distantPast
    )
}
