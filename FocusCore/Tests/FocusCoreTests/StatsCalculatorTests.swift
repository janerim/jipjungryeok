import XCTest
@testable import FocusCore

/// §4.2 통계 집계와 §12 수용 기준의 통계 항목.
///
/// 기준 날짜는 **2026년 8월 20일 (목요일)**.
/// 월요일 시작이므로 이 주는 8/17(월) ~ 8/23(일) 이다.
/// 시간대를 고정하지 않으면 CI 나 다른 기기에서 하루씩 어긋나므로 서울로 못박는다.
final class StatsCalculatorTests: XCTestCase {

    private let calendar: Calendar = {
        var calendar = Calendar.focus
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return calendar
    }()

    private var subject: StatsCalculator { StatsCalculator(calendar: calendar) }

    /// 2026-08-20 14:00 (목)
    private var now: Date { date(2026, 8, 20, 14, 0) }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12, _ minute: Int = 0) -> Date {
        var parts = DateComponents()
        parts.year = year
        parts.month = month
        parts.day = day
        parts.hour = hour
        parts.minute = minute
        guard let result = calendar.date(from: parts) else {
            fatalError("테스트 날짜를 만들 수 없습니다: \(year)-\(month)-\(day)")
        }
        return result
    }

    private func record(
        startAt: Date,
        seconds: Int,
        completed: Bool = true
    ) -> SessionRecord {
        SessionRecord(
            id: UUID(),
            startAt: startAt,
            endAt: startAt.addingTimeInterval(Double(seconds)),
            plannedSeconds: seconds,
            actualSeconds: seconds,
            isCompleted: completed
        )
    }

    // MARK: - §12 35분 세션 1건

    /// 35분 세션 하나를 오늘 끝내면 다섯 칸이 전부 00:35 여야 한다.
    func testSingleSessionAppearsInEveryBucket() {
        let sessions = [record(startAt: date(2026, 8, 20, 10, 0), seconds: 35 * 60)]
        let summary = subject.summarize(sessions, now: now)

        XCTAssertEqual(summary.todaySeconds, 2100)
        XCTAssertEqual(summary.weekSeconds, 2100)
        XCTAssertEqual(summary.monthSeconds, 2100)
        XCTAssertEqual(summary.last7DaysSeconds, 2100)
        XCTAssertEqual(summary.last28DaysSeconds, 2100)

        XCTAssertEqual(TimeDisplay.hhmm(summary.todaySeconds), "00:35")
    }

    // MARK: - §12 자정을 넘는 세션은 시작일에만 귀속된다

    /// 23:50 에 시작해 00:15 에 끝난 세션은 **전날** 통계에만 25분으로 잡힌다.
    /// 두 날에 나눠 배분하지 않는다 (§4.2).
    func testSessionCrossingMidnightBelongsToStartDay() {
        let sessions = [record(startAt: date(2026, 8, 19, 23, 50), seconds: 25 * 60)]
        let summary = subject.summarize(sessions, now: now)

        XCTAssertEqual(summary.todaySeconds, 0, "종료가 오늘이어도 오늘로 잡히면 안 된다")
        XCTAssertEqual(summary.weekSeconds, 1500, "8/19 는 같은 주(8/17~8/23)")
        XCTAssertEqual(summary.monthSeconds, 1500)

        // 차트에서도 어제 칸에만 들어간다
        XCTAssertEqual(summary.dailyTotals[0].seconds, 0, "오늘 칸")
        XCTAssertEqual(summary.dailyTotals[1].seconds, 1500, "어제 칸")
    }

    // MARK: - §1-1 주는 월요일에 시작한다

    /// 일요일 세션은 지난주다. 롤링 7일에는 들어가지만 "이번 주" 에는 안 들어간다.
    func testWeekStartsOnMonday() {
        let sessions = [
            record(startAt: date(2026, 8, 16, 10, 0), seconds: 1200),  // 일요일 = 지난주
            record(startAt: date(2026, 8, 17, 10, 0), seconds: 600)    // 월요일 = 이번 주
        ]
        let summary = subject.summarize(sessions, now: now)

        XCTAssertEqual(summary.weekSeconds, 600, "일요일이 이번 주에 포함되면 안 된다")
        XCTAssertEqual(summary.last7DaysSeconds, 1800, "롤링 7일(8/14~8/20)에는 둘 다 들어간다")
    }

    // MARK: - 롤링 윈도우 경계

    /// 최근 7일은 오늘 포함이므로 8/14 까지다. 8/13 은 빠진다.
    func testLast7DaysBoundary() {
        let inside = subject.summarize(
            [record(startAt: date(2026, 8, 14, 10, 0), seconds: 600)], now: now
        )
        XCTAssertEqual(inside.last7DaysSeconds, 600, "8/14 는 경계 안")

        let outside = subject.summarize(
            [record(startAt: date(2026, 8, 13, 10, 0), seconds: 600)], now: now
        )
        XCTAssertEqual(outside.last7DaysSeconds, 0, "8/13 은 경계 밖")
        XCTAssertEqual(outside.last28DaysSeconds, 600, "다만 최근 28일에는 들어간다")
    }

    /// 최근 28일은 오늘 포함이므로 7/24 까지다. 7/23 은 빠진다.
    func testLast28DaysBoundary() {
        let inside = subject.summarize(
            [record(startAt: date(2026, 7, 24, 10, 0), seconds: 600)], now: now
        )
        XCTAssertEqual(inside.last28DaysSeconds, 600, "7/24 는 경계 안")

        let outside = subject.summarize(
            [record(startAt: date(2026, 7, 23, 10, 0), seconds: 600)], now: now
        )
        XCTAssertEqual(outside.last28DaysSeconds, 0, "7/23 은 경계 밖")
    }

    /// "이번 달" 은 롤링이 아니라 달력상 1일 기준이다.
    func testMonthIsCalendarMonthNotRolling() {
        let sessions = [record(startAt: date(2026, 7, 31, 10, 0), seconds: 900)]
        let summary = subject.summarize(sessions, now: now)

        XCTAssertEqual(summary.monthSeconds, 0, "7/31 은 지난달")
        XCTAssertEqual(summary.last28DaysSeconds, 900, "최근 28일에는 들어간다")
    }

    // MARK: - §12 차트

    /// 차트는 10일치이고, 배열 맨 앞이 오늘이다 (화면에서 최신이 왼쪽).
    func testChartHasTenDaysNewestFirst() {
        let sessions = [
            record(startAt: date(2026, 8, 20, 9, 0), seconds: 100),
            record(startAt: date(2026, 8, 19, 9, 0), seconds: 200),
            record(startAt: date(2026, 8, 11, 9, 0), seconds: 300)
        ]
        let summary = subject.summarize(sessions, now: now)

        XCTAssertEqual(summary.dailyTotals.count, StatsCalculator.chartDayCount)
        XCTAssertEqual(summary.dailyTotals[0].seconds, 100, "맨 앞이 오늘")
        XCTAssertEqual(summary.dailyTotals[1].seconds, 200)
        XCTAssertEqual(summary.dailyTotals[9].seconds, 300, "맨 뒤가 9일 전(8/11)")

        XCTAssertEqual(summary.dailyTotals[0].date, calendar.startOfDay(for: now))
        // 날짜가 하루씩 과거로 내려간다
        for index in 1..<summary.dailyTotals.count {
            XCTAssertLessThan(
                summary.dailyTotals[index].date,
                summary.dailyTotals[index - 1].date,
                "\(index)번째 칸이 앞 칸보다 과거여야 한다"
            )
        }
    }

    /// 같은 날 여러 세션은 한 칸에 합쳐진다.
    func testSameDaySessionsAreSummed() {
        let sessions = [
            record(startAt: date(2026, 8, 20, 9, 0), seconds: 600),
            record(startAt: date(2026, 8, 20, 15, 0), seconds: 900)
        ]
        let summary = subject.summarize(sessions, now: now)

        XCTAssertEqual(summary.todaySeconds, 1500)
        XCTAssertEqual(summary.dailyTotals[0].seconds, 1500)
        XCTAssertEqual(summary.monthSessionCount, 2)
    }

    // MARK: - Y축 확장 (§4.2)

    func testChartMaxHoursDefaultsToEight() {
        XCTAssertEqual(StatsCalculator.chartMaxHours(forMaxSeconds: 0), 8)
        XCTAssertEqual(StatsCalculator.chartMaxHours(forMaxSeconds: 3600), 8)
        XCTAssertEqual(StatsCalculator.chartMaxHours(forMaxSeconds: 8 * 3600), 8, "정확히 8시간은 확장 없음")
    }

    func testChartMaxHoursExpandsInTwoHourSteps() {
        XCTAssertEqual(StatsCalculator.chartMaxHours(forMaxSeconds: 8 * 3600 + 60), 10)
        XCTAssertEqual(StatsCalculator.chartMaxHours(forMaxSeconds: 9 * 3600), 10)
        XCTAssertEqual(StatsCalculator.chartMaxHours(forMaxSeconds: 10 * 3600), 10)
        XCTAssertEqual(StatsCalculator.chartMaxHours(forMaxSeconds: 11 * 3600), 12)
    }

    func testSummaryCarriesExpandedChartMax() {
        let sessions = [record(startAt: date(2026, 8, 20, 1, 0), seconds: 9 * 3600)]
        XCTAssertEqual(subject.summarize(sessions, now: now).chartMaxHours, 10)
    }

    // MARK: - §12 빈 상태

    /// 세션이 0건이어도 차트 칸은 10개가 그려지고 값은 전부 0이다.
    func testEmptyInputProducesZeroedSummary() {
        let summary = subject.summarize([], now: now)

        XCTAssertEqual(summary.todaySeconds, 0)
        XCTAssertEqual(summary.weekSeconds, 0)
        XCTAssertEqual(summary.monthSeconds, 0)
        XCTAssertEqual(summary.last7DaysSeconds, 0)
        XCTAssertEqual(summary.last28DaysSeconds, 0)
        XCTAssertEqual(summary.monthSessionCount, 0)
        XCTAssertEqual(summary.chartMaxHours, 8)
        XCTAssertEqual(summary.dailyTotals.count, StatsCalculator.chartDayCount)
        XCTAssertTrue(summary.dailyTotals.allSatisfy { $0.seconds == 0 })
    }

    // MARK: - 중도 중지 세션

    /// §6-4 로 저장된 미완료 세션도 집중한 시간이므로 집계에 들어간다.
    func testIncompleteSessionsCountTowardTotals() {
        let sessions = [record(startAt: date(2026, 8, 20, 10, 0), seconds: 300, completed: false)]
        let summary = subject.summarize(sessions, now: now)

        XCTAssertEqual(summary.todaySeconds, 300)
        XCTAssertEqual(summary.monthSessionCount, 1)
    }

    // MARK: - 미래 세션 방어

    /// 기기 시계가 앞으로 튀었다 돌아온 경우, 미래 날짜 세션이 합계를 부풀리면 안 된다.
    func testFutureSessionsAreNotCounted() {
        let sessions = [record(startAt: date(2026, 8, 25, 10, 0), seconds: 3600)]
        let summary = subject.summarize(sessions, now: now)

        XCTAssertEqual(summary.todaySeconds, 0)
        XCTAssertEqual(summary.weekSeconds, 0)
        XCTAssertEqual(summary.monthSeconds, 0)
        XCTAssertEqual(summary.monthSessionCount, 0)
    }

    // MARK: - 조회 윈도우

    /// 저장소에서 꺼내올 범위는 "이번 달 1일" 과 "27일 전" 중 이른 쪽이다.
    func testWindowStartTakesTheEarlierOfMonthStartAndRolling() {
        // 8/20 → 8/1 vs 7/24 → 7/24 가 이르다
        XCTAssertEqual(subject.windowStart(for: now), calendar.startOfDay(for: date(2026, 7, 24)))

        // 8/5 → 8/1 vs 7/9 → 7/9 가 이르다
        XCTAssertEqual(
            subject.windowStart(for: date(2026, 8, 5)),
            calendar.startOfDay(for: date(2026, 7, 9))
        )

        // 1/30 → 1/1 vs 1/3 → 1/1 이 이르다
        XCTAssertEqual(
            subject.windowStart(for: date(2026, 1, 30)),
            calendar.startOfDay(for: date(2026, 1, 1))
        )
    }

    // MARK: - 위젯 스냅샷 (§5)

    func testSnapshotTakesTheFirstSevenChartDays() {
        let sessions = [
            record(startAt: date(2026, 8, 20, 9, 0), seconds: 100),
            record(startAt: date(2026, 8, 19, 9, 0), seconds: 200),
            record(startAt: date(2026, 8, 11, 9, 0), seconds: 300)   // 7일 밖
        ]
        let snapshot = subject.summarize(sessions, now: now).snapshot(updatedAt: now)

        XCTAssertEqual(snapshot.last7Days.count, 7)
        XCTAssertEqual(snapshot.last7Days[0], 100, "맨 앞이 오늘")
        XCTAssertEqual(snapshot.last7Days[1], 200)
        XCTAssertEqual(snapshot.todaySeconds, 100)
        XCTAssertEqual(snapshot.updatedAt, now)
    }

    func testSnapshotRoundTripsThroughCodable() throws {
        let snapshot = subject.summarize([], now: now).snapshot(updatedAt: now)
        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(StatsSnapshot.self, from: data)
        XCTAssertEqual(decoded, snapshot)
    }
}
