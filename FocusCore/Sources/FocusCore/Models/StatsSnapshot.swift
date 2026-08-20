import Foundation

/// §5 위젯용 스냅샷.
///
/// 위젯은 SwiftData 를 직접 조회하지 않는다 (§8.1). 세션이 저장될 때마다
/// 이 가벼운 값을 App Group `UserDefaults` 에 써두고, 위젯은 그것만 읽는다.
/// 익스텐션에서 스토어를 여는 것보다 실패 위험이 훨씬 낮다.
///
/// 실제로 쓰고 읽는 것은 M5 의 SnapshotWriter 가 맡는다.
public struct StatsSnapshot: Codable, Equatable, Sendable {

    public var todaySeconds: Int
    public var weekSeconds: Int
    public var monthSeconds: Int

    /// `[오늘, 어제, ...]` 순서, 초 단위. 최대 7개.
    public var last7Days: [Int]

    public var updatedAt: Date

    public init(
        todaySeconds: Int,
        weekSeconds: Int,
        monthSeconds: Int,
        last7Days: [Int],
        updatedAt: Date
    ) {
        self.todaySeconds = todaySeconds
        self.weekSeconds = weekSeconds
        self.monthSeconds = monthSeconds
        self.last7Days = last7Days
        self.updatedAt = updatedAt
    }

    public static let zero = StatsSnapshot(
        todaySeconds: 0,
        weekSeconds: 0,
        monthSeconds: 0,
        last7Days: Array(repeating: 0, count: 7),
        updatedAt: .distantPast
    )
}
