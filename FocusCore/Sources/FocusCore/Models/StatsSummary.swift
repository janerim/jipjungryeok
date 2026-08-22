import Foundation

/// 하루치 집중 시간. 차트의 막대 하나에 대응한다.
public struct DailyTotal: Equatable, Sendable, Identifiable {

    /// 그 날의 시작(자정)
    public let date: Date
    public let seconds: Int

    public var id: Date { date }

    public init(date: Date, seconds: Int) {
        self.date = date
        self.seconds = seconds
    }
}

/// §4.2 통계 화면이 필요로 하는 값 전부.
public struct StatsSummary: Equatable, Sendable {

    public let todaySeconds: Int

    /// 월요일 시작 기준 이번 주 (§1-1)
    public let weekSeconds: Int

    /// 달력상 1일 시작 기준 이번 달
    public let monthSeconds: Int

    /// 이번 주 집중 횟수
    public let weekSessionCount: Int

    /// 이번 주 **월요일부터 일요일까지** 7칸 (§1-1).
    ///
    /// 오래된 쪽이 앞이다 — 화면에서 왼쪽이 월요일, 오른쪽이 일요일이 된다.
    /// 시간은 어느 화면에서나 왼쪽에서 오른쪽으로 흐른다.
    /// 아직 오지 않은 요일도 0 으로 자리를 채운다. 주가 진행되면서 칸이 늘었다
    /// 줄었다 하면 한 주의 모양을 비교할 수 없다.
    public let weekdayTotals: [DailyTotal]

    /// 일별 원자료. §8.1 위젯 스냅샷이 최근 7일을 잘라 쓴다.
    /// **최신 날짜가 앞**이다. 화면에 놓는 순서는 쓰는 쪽이 정한다.
    public let dailyTotals: [DailyTotal]

    public init(
        todaySeconds: Int,
        weekSeconds: Int,
        monthSeconds: Int,
        weekSessionCount: Int,
        weekdayTotals: [DailyTotal],
        dailyTotals: [DailyTotal]
    ) {
        self.todaySeconds = todaySeconds
        self.weekSeconds = weekSeconds
        self.monthSeconds = monthSeconds
        self.weekSessionCount = weekSessionCount
        self.weekdayTotals = weekdayTotals
        self.dailyTotals = dailyTotals
    }

    /// §4.2 오늘 링과 주간 스트립이 한 바퀴를 채우는 기준 — 5시간.
    ///
    /// 목표 설정 기능을 만들지 않기 때문에(§2, 규칙 5) 분모가 필요하다.
    /// 고정값이라 어제와 오늘의 링을 눈으로 바로 비교할 수 있다. 그날그날
    /// 최댓값에 맞춰 늘리면 잘한 날과 못한 날이 똑같이 꽉 차 보인다.
    public static let fullRingSeconds = 5 * 3600

    /// 첫 바퀴가 채워진 비율 (0...1).
    public static func fillFraction(forSeconds seconds: Int) -> Double {
        guard seconds > 0 else { return 0 }
        return min(1, Double(seconds) / Double(fullRingSeconds))
    }

    /// 기준을 넘긴 만큼의 비율 (0...1). 링의 **두 번째 바퀴**, 막대의 초과 구간이 된다.
    ///
    /// 이게 없으면 5시간·7시간·10시간이 전부 똑같이 꽉 찬 모양이 된다. 특히 주간
    /// 스트립에서 오르막인 한 주가 평평하게 보여서, 한 주의 모양을 보여준다는
    /// 그림의 목적 자체가 무너진다.
    ///
    /// 두 번째 바퀴도 상한을 둔다 — 10시간이면 두 바퀴가 다 찬다. 셋째 바퀴까지
    /// 그리면 몇 바퀴인지 세야 해서 한눈에 읽히지 않는다.
    public static func overflowFraction(forSeconds seconds: Int) -> Double {
        let excess = Double(seconds) - Double(fullRingSeconds)
        guard excess > 0 else { return 0 }
        return min(1, excess / Double(fullRingSeconds))
    }

    /// 세션이 하나도 없을 때 (§12 — 빈 상태가 크래시 없이 그려져야 한다).
    public static func empty(now: Date = .now, calendar: Calendar = .focus) -> StatsSummary {
        StatsCalculator(calendar: calendar).summarize([], now: now)
    }

    /// §5 위젯용 스냅샷. 화면과 같은 값을 담는다 — 위젯이 앱과 다른 숫자를
    /// 보여주면 어느 쪽이 맞는지 알 수 없다.
    public func snapshot(updatedAt: Date) -> StatsSnapshot {
        StatsSnapshot(
            todaySeconds: todaySeconds,
            weekSeconds: weekSeconds,
            weekSessionCount: weekSessionCount,
            weekdaySeconds: weekdayTotals.map(\.seconds),
            updatedAt: updatedAt
        )
    }
}
