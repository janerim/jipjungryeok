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

    /// 오늘을 포함한 롤링 7일
    public let last7DaysSeconds: Int

    /// 오늘을 포함한 롤링 28일
    public let last28DaysSeconds: Int

    /// 차트용 일별 집계. **최신 날짜가 앞**이다 (§4.2 — 최신이 왼쪽).
    public let dailyTotals: [DailyTotal]

    /// 차트 Y축 최댓값(시간). 기본 8, 데이터가 넘으면 2시간 단위로 확장.
    public let chartMaxHours: Int

    /// 차트 아래 라벨의 기준 달
    public let chartMonth: Date

    /// 차트에 표시된 달의 집중 횟수
    public let monthSessionCount: Int

    public init(
        todaySeconds: Int,
        weekSeconds: Int,
        monthSeconds: Int,
        last7DaysSeconds: Int,
        last28DaysSeconds: Int,
        dailyTotals: [DailyTotal],
        chartMaxHours: Int,
        chartMonth: Date,
        monthSessionCount: Int
    ) {
        self.todaySeconds = todaySeconds
        self.weekSeconds = weekSeconds
        self.monthSeconds = monthSeconds
        self.last7DaysSeconds = last7DaysSeconds
        self.last28DaysSeconds = last28DaysSeconds
        self.dailyTotals = dailyTotals
        self.chartMaxHours = chartMaxHours
        self.chartMonth = chartMonth
        self.monthSessionCount = monthSessionCount
    }

    /// 세션이 하나도 없을 때 (§12 — 빈 상태가 크래시 없이 그려져야 한다).
    public static func empty(now: Date = .now, calendar: Calendar = .focus) -> StatsSummary {
        StatsCalculator(calendar: calendar).summarize([], now: now)
    }

    /// §5 위젯용 스냅샷. App Group 에 쓰는 것은 M5 의 몫이다.
    public func snapshot(updatedAt: Date) -> StatsSnapshot {
        StatsSnapshot(
            todaySeconds: todaySeconds,
            weekSeconds: weekSeconds,
            monthSeconds: monthSeconds,
            last7Days: dailyTotals.prefix(7).map(\.seconds),
            updatedAt: updatedAt
        )
    }
}
