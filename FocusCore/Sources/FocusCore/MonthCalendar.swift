import Foundation

/// §4.2-3 달력 한 칸.
public struct CalendarDay: Equatable, Sendable, Identifiable {

    /// 그 날의 자정
    public let date: Date

    /// 그 날 집중한 초. 날짜 판정은 `startAt` 기준이다 (§4.2).
    public let seconds: Int

    /// 보고 있는 달에 속하는가. 격자를 주 단위로 채우느라 들어온 앞뒤 달의 날짜는 `false`.
    public let isInMonth: Bool

    public var id: Date { date }

    public init(date: Date, seconds: Int, isInMonth: Bool) {
        self.date = date
        self.seconds = seconds
        self.isInMonth = isInMonth
    }
}

/// §4.2-3 달력 한 달치.
public struct MonthGrid: Equatable, Sendable {

    /// 그 달 1일 자정
    public let month: Date

    /// 주 단위로 끊은 날짜. 각 줄은 **월요일부터 일요일까지** 7칸이다 (§1-1).
    public let weeks: [[CalendarDay]]

    /// 그 달 합계. 앞뒤 달에서 들어온 칸은 빼고 센다.
    public let totalSeconds: Int

    /// 그 달에 **나온 날 수**. 합계보다 이 숫자가 행동을 바꾼다 (§4.2).
    public let activeDayCount: Int
}

/// §4.2-3 통계 화면의 달력.
///
/// 책력과 **같은 틀**을 쓴다 — 월요일 시작, 앞뒤 달 날짜로 주를 채움, 달 단위로 넘김.
/// 두 앱이 한 벌로 보이는 것은 아이콘과 이 격자에서 난다. 칸 **안**은 각자 다르다:
/// 책력은 그날 끝낸 책(사건)을 그리고, 집중력은 그날 집중한 양(분량)을 농담으로 그린다.
/// 집중력에는 칸에 넣을 "물건" 이 없어서 표지 자리를 그대로 가져올 수 없다.
///
/// 순수 날짜 계산이라 여기 둔다. 달 경계와 주 경계는 시간대·서머타임에서 조용히
/// 어긋나는 대표적인 자리이고, 어긋나면 화면을 띄워야만 드러난다.
public enum MonthCalendar {

    // MARK: - 격자

    /// - Parameter month: 보고 싶은 달. 그 달 안이면 며칟날이든 상관없다.
    /// - Parameter sessions: 날짜 판정에 쓸 세션. 그 달 바깥의 것이 섞여 있어도 된다.
    public static func grid(
        for month: Date,
        sessions: [SessionRecord],
        calendar: Calendar = .focus
    ) -> MonthGrid {
        let monthStart = startOfMonth(month, calendar)
        let monthEnd = endOfMonth(monthStart, calendar)

        // 세션을 하루 단위로 먼저 뭉친다. 칸마다 전체를 훑으면 한 달에 42번 훑게 된다.
        var secondsByDay: [Date: Int] = [:]
        for session in sessions {
            let day = calendar.startOfDay(for: session.startAt)
            secondsByDay[day, default: 0] += session.actualSeconds
        }

        var weeks: [[CalendarDay]] = []
        var current: [CalendarDay] = []
        var cursor = startOfWeek(monthStart, calendar)
        let gridEnd = endOfWeek(monthEnd, calendar)

        // `byAdding:` 로 하루씩 민다. 86400 을 더하면 서머타임이 있는 지역에서 밀린다.
        while cursor <= gridEnd {
            let inMonth = calendar.isDate(cursor, equalTo: monthStart, toGranularity: .month)
            current.append(
                CalendarDay(
                    date: cursor,
                    seconds: secondsByDay[cursor] ?? 0,
                    isInMonth: inMonth
                )
            )
            if current.count == 7 {
                weeks.append(current)
                current = []
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        // 격자가 주 경계에서 끝나므로 보통 비어 있다. 날짜 계산이 어긋났을 때만 남는다.
        if !current.isEmpty { weeks.append(current) }

        let inMonthDays = weeks.flatMap { $0 }.filter(\.isInMonth)

        return MonthGrid(
            month: monthStart,
            weeks: weeks,
            totalSeconds: inMonthDays.reduce(0) { $0 + $1.seconds },
            activeDayCount: inMonthDays.filter { $0.seconds > 0 }.count
        )
    }

    // MARK: - 달 넘기기

    public static func month(containing date: Date, calendar: Calendar = .focus) -> Date {
        startOfMonth(date, calendar)
    }

    public static func shift(_ month: Date, by delta: Int, calendar: Calendar = .focus) -> Date {
        let base = startOfMonth(month, calendar)
        return calendar.date(byAdding: .month, value: delta, to: base) ?? base
    }

    /// 기록이 있는 가장 이른 달. 세션이 없으면 `nil`.
    ///
    /// 뒤로 넘기는 한계가 된다. 기록이 시작되기 전으로 끝없이 넘어가면,
    /// 빈 격자만 나오는 곳에서 "더 있나" 를 확인할 방법이 없다.
    public static func earliestMonth(
        in sessions: [SessionRecord],
        calendar: Calendar = .focus
    ) -> Date? {
        guard let earliest = sessions.map(\.startAt).min() else { return nil }
        return startOfMonth(earliest, calendar)
    }

    // MARK: -

    private static func startOfMonth(_ date: Date, _ calendar: Calendar) -> Date {
        calendar.dateInterval(of: .month, for: date)?.start ?? calendar.startOfDay(for: date)
    }

    /// 그 달 **말일의 자정**. `dateInterval` 의 `end` 는 다음 달 1일이라 하루를 뺀다.
    private static func endOfMonth(_ monthStart: Date, _ calendar: Calendar) -> Date {
        guard let next = calendar.date(byAdding: .month, value: 1, to: monthStart),
              let last = calendar.date(byAdding: .day, value: -1, to: next) else { return monthStart }
        return calendar.startOfDay(for: last)
    }

    /// `Calendar.focus` 는 `firstWeekday = 2` 라 월요일이 나온다 (§1-1).
    private static func startOfWeek(_ date: Date, _ calendar: Calendar) -> Date {
        calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? calendar.startOfDay(for: date)
    }

    private static func endOfWeek(_ date: Date, _ calendar: Calendar) -> Date {
        let start = startOfWeek(date, calendar)
        return calendar.date(byAdding: .day, value: 6, to: start) ?? start
    }
}
