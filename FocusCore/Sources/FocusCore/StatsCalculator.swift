import Foundation

/// §4.2 통계 집계.
///
/// **핵심 규칙: 모든 집계는 `session.startAt` 기준으로 날짜를 판정한다.**
/// 23:50 에 시작해 00:15 에 끝난 세션은 전부 시작일에 귀속되며, 두 날에 나눠
/// 배분하지 않는다. 차트·회고·시간 요약 전부 같은 규칙이다.
///
/// SwiftData 를 모르는 순수 계산이다. 저장소에서 꺼낸 `SessionRecord` 배열만 받는다.
public struct StatsCalculator {

    /// §4.2 차트 X축 일수
    public static let chartDayCount = 10

    /// §4.2 차트 Y축 기본 최댓값(시간)
    public static let defaultChartMaxHours = 8

    private let calendar: Calendar

    public init(calendar: Calendar = .focus) {
        self.calendar = calendar
    }

    // MARK: -

    /// 집계에 필요한 가장 이른 날짜. 저장소에서 이 날짜 이후만 꺼내오면 충분하다.
    ///
    /// "이번 달" 과 "최근 28일" 중 더 이른 쪽이 기준이다. 차트 10일과 주간 7일은
    /// 항상 그 안에 들어온다.
    public func windowStart(for now: Date) -> Date {
        let today = calendar.startOfDay(for: now)
        let monthStart = startOfMonth(containing: now)
        let rollingStart = calendar.date(byAdding: .day, value: -27, to: today) ?? today
        return min(monthStart, rollingStart)
    }

    public func summarize(_ sessions: [SessionRecord], now: Date) -> StatsSummary {
        let today = calendar.startOfDay(for: now)

        // 날짜 판정은 startAt 기준. 하루 단위로 먼저 뭉쳐 두면 이후 집계가 전부 단순해진다.
        var secondsByDay: [Date: Int] = [:]
        var countByDay: [Date: Int] = [:]
        for session in sessions {
            let day = calendar.startOfDay(for: session.startAt)
            secondsByDay[day, default: 0] += max(0, session.actualSeconds)
            countByDay[day, default: 0] += 1
        }

        let weekStart = startOfWeek(containing: now)
        let monthStart = startOfMonth(containing: now)
        let last7Start = calendar.date(byAdding: .day, value: -6, to: today) ?? today
        let last28Start = calendar.date(byAdding: .day, value: -27, to: today) ?? today

        // 오늘 이후는 세지 않는다. 기기 시계가 앞으로 튀었다가 돌아온 경우를 막는다.
        func total(from start: Date) -> Int {
            secondsByDay.reduce(0) { sum, entry in
                (entry.key >= start && entry.key <= today) ? sum + entry.value : sum
            }
        }

        let dailyTotals: [DailyTotal] = (0..<Self.chartDayCount).compactMap { offset in
            // offset 0 이 오늘이고 배열 맨 앞이다 → 화면에서 최신이 왼쪽 (§4.2)
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else {
                return nil
            }
            return DailyTotal(date: day, seconds: secondsByDay[day] ?? 0)
        }

        let monthSessionCount = countByDay.reduce(0) { sum, entry in
            (entry.key >= monthStart && entry.key <= today) ? sum + entry.value : sum
        }

        return StatsSummary(
            todaySeconds: secondsByDay[today] ?? 0,
            weekSeconds: total(from: weekStart),
            monthSeconds: total(from: monthStart),
            last7DaysSeconds: total(from: last7Start),
            last28DaysSeconds: total(from: last28Start),
            dailyTotals: dailyTotals,
            chartMaxHours: Self.chartMaxHours(forMaxSeconds: dailyTotals.map(\.seconds).max() ?? 0),
            chartMonth: monthStart,
            monthSessionCount: monthSessionCount
        )
    }

    /// §4.2 — 기본 0~8시간. 데이터 최댓값이 8을 넘으면 2시간 단위로 확장한다.
    public static func chartMaxHours(forMaxSeconds seconds: Int) -> Int {
        let hours = Double(max(0, seconds)) / 3600
        guard hours > Double(defaultChartMaxHours) else { return defaultChartMaxHours }
        return Int((hours / 2).rounded(.up)) * 2
    }

    // MARK: -

    /// 월요일 시작 (§1-1). `Calendar.focus` 의 `firstWeekday` 가 반영된다.
    private func startOfWeek(containing date: Date) -> Date {
        calendar.dateInterval(of: .weekOfYear, for: date)?.start
            ?? calendar.startOfDay(for: date)
    }

    private func startOfMonth(containing date: Date) -> Date {
        calendar.dateInterval(of: .month, for: date)?.start
            ?? calendar.startOfDay(for: date)
    }
}
