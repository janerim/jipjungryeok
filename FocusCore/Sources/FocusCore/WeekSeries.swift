import Foundation

/// §4.2-2 한 주치 집계.
public struct WeekSummary: Equatable, Sendable {

    /// 그 주 **월요일**의 자정 (§1-1)
    public let weekStart: Date

    /// 월요일부터 일요일까지 7칸. 아직 오지 않은 요일도 0 으로 자리를 채운다 —
    /// 주가 진행되며 칸 수가 달라지면 한 주의 모양을 비교할 수 없다.
    public let totals: [DailyTotal]

    public let sessionCount: Int
    public let totalSeconds: Int
}

/// §4.2-2 주간 막대를 임의의 주로 옮기기 위한 집계.
///
/// `StatsCalculator` 는 **이번 주**만 계산한다. 위젯과 오늘 링이 쓰는 값이라 범위를
/// 좁게 잡아 둔 것이고, 그 설계는 그대로 둔다. 지난주를 보는 것은 화면이 들고 있는
/// 전체 기록에서 그때그때 뽑는다 — 달력이 달을 넘기는 것과 같은 방식이다.
///
/// 순수 날짜 계산이라 여기 둔다. 주 경계는 시간대·서머타임에서 조용히 어긋나는
/// 자리이고, 어긋나면 화면을 띄워야만 드러난다.
public enum WeekSeries {

    /// 그 주 월요일 자정. 주 안이면 어느 날을 줘도 같은 값이 나온다.
    public static func week(containing date: Date, calendar: Calendar = .focus) -> Date {
        calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? calendar.startOfDay(for: date)
    }

    public static func shift(_ week: Date, by delta: Int, calendar: Calendar = .focus) -> Date {
        let base = self.week(containing: week, calendar: calendar)
        return calendar.date(byAdding: .weekOfYear, value: delta, to: base) ?? base
    }

    /// 기록이 있는 가장 이른 주. 뒤로 넘기는 한계가 된다.
    public static func earliestWeek(
        in sessions: [SessionRecord],
        calendar: Calendar = .focus
    ) -> Date? {
        guard let earliest = sessions.map(\.startAt).min() else { return nil }
        return week(containing: earliest, calendar: calendar)
    }

    /// - Parameter date: 보고 싶은 주. 그 주 안이면 어느 날이든 상관없다.
    public static func summary(
        forWeekContaining date: Date,
        sessions: [SessionRecord],
        calendar: Calendar = .focus
    ) -> WeekSummary {
        let start = week(containing: date, calendar: calendar)

        // 날짜 판정은 `startAt` 기준이다 (§4.2). 23:50 에 시작해 자정을 넘긴 세션도
        // 전부 시작일에 귀속된다.
        var secondsByDay: [Date: Int] = [:]
        var countByDay: [Date: Int] = [:]
        for session in sessions {
            let day = calendar.startOfDay(for: session.startAt)
            secondsByDay[day, default: 0] += session.actualSeconds
            countByDay[day, default: 0] += 1
        }

        var totals: [DailyTotal] = []
        for offset in 0..<StatsCalculator.weekdayCount {
            guard let day = calendar.date(byAdding: .day, value: offset, to: start) else { break }
            totals.append(DailyTotal(date: day, seconds: secondsByDay[day] ?? 0))
        }

        return WeekSummary(
            weekStart: start,
            totals: totals,
            sessionCount: totals.reduce(0) { $0 + (countByDay[$1.date] ?? 0) },
            totalSeconds: totals.reduce(0) { $0 + $1.seconds }
        )
    }
}
