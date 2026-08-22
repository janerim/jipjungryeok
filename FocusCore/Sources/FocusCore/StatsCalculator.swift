import Foundation

/// §4.2 통계 집계.
///
/// **핵심 규칙: 모든 집계는 `session.startAt` 기준으로 날짜를 판정한다.**
/// 23:50 에 시작해 00:15 에 끝난 세션은 전부 시작일에 귀속되며, 두 날에 나눠
/// 배분하지 않는다. 링·주간 스트립·기록 전부 같은 규칙이다.
///
/// SwiftData 를 모르는 순수 계산이다. 저장소에서 꺼낸 `SessionRecord` 배열만 받는다.
public struct StatsCalculator {

    /// §8.1 위젯 스냅샷이 쓰는 일별 원자료 길이
    public static let dailySeriesDayCount = 10

    /// 한 주는 7칸 (§1-1 월요일 시작)
    public static let weekdayCount = 7

    private let calendar: Calendar

    public init(calendar: Calendar = .focus) {
        self.calendar = calendar
    }

    // MARK: -

    /// 집계에 필요한 가장 이른 날짜. 저장소에서 이 날짜 이후만 꺼내오면 충분하다.
    ///
    /// "이번 달" 시작과 일별 원자료 10일 중 더 이른 쪽이 기준이다.
    /// 주간 7칸은 항상 그 안에 들어온다.
    public func windowStart(for now: Date) -> Date {
        let today = calendar.startOfDay(for: now)
        let monthStart = startOfMonth(containing: now)
        let seriesStart = calendar.date(
            byAdding: .day, value: -(Self.dailySeriesDayCount - 1), to: today
        ) ?? today
        return min(monthStart, min(seriesStart, startOfWeek(containing: now)))
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

        // 오늘 이후는 세지 않는다. 기기 시계가 앞으로 튀었다가 돌아온 경우를 막는다.
        func total(from start: Date) -> Int {
            secondsByDay.reduce(0) { sum, entry in
                (entry.key >= start && entry.key <= today) ? sum + entry.value : sum
            }
        }

        // 월요일이 앞. 아직 오지 않은 요일도 0 으로 자리를 채운다.
        let weekdayTotals: [DailyTotal] = (0..<Self.weekdayCount).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: weekStart) else {
                return nil
            }
            return DailyTotal(date: day, seconds: secondsByDay[day] ?? 0)
        }

        let dailyTotals: [DailyTotal] = (0..<Self.dailySeriesDayCount).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else {
                return nil
            }
            return DailyTotal(date: day, seconds: secondsByDay[day] ?? 0)
        }

        let weekSessionCount = countByDay.reduce(0) { sum, entry in
            (entry.key >= weekStart && entry.key <= today) ? sum + entry.value : sum
        }

        return StatsSummary(
            todaySeconds: secondsByDay[today] ?? 0,
            weekSeconds: total(from: weekStart),
            monthSeconds: total(from: monthStart),
            weekSessionCount: weekSessionCount,
            weekdayTotals: weekdayTotals,
            dailyTotals: dailyTotals
        )
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
