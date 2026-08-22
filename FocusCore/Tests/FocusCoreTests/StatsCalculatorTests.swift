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

    /// 35분 세션 하나를 오늘 끝내면 오늘·이번 주·이번 달이 전부 00:35 여야 한다.
    func testSingleSessionAppearsInEveryBucket() {
        let sessions = [record(startAt: date(2026, 8, 20, 10, 0), seconds: 35 * 60)]
        let summary = subject.summarize(sessions, now: now)

        XCTAssertEqual(summary.todaySeconds, 2100)
        XCTAssertEqual(summary.weekSeconds, 2100)
        XCTAssertEqual(summary.monthSeconds, 2100)
        XCTAssertEqual(summary.weekSessionCount, 1)

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

        // 주간 스트립에서도 수요일(8/19) 칸에만 들어간다. 월요일이 0번이다.
        XCTAssertEqual(summary.weekdayTotals[2].seconds, 1500, "수요일 칸")
        XCTAssertEqual(summary.weekdayTotals[3].seconds, 0, "목요일(오늘) 칸")
    }

    // MARK: - §1-1 주는 월요일에 시작한다

    func testWeekStartsOnMonday() {
        let sessions = [
            record(startAt: date(2026, 8, 16, 10, 0), seconds: 1200),  // 일요일 = 지난주
            record(startAt: date(2026, 8, 17, 10, 0), seconds: 600)    // 월요일 = 이번 주
        ]
        let summary = subject.summarize(sessions, now: now)

        XCTAssertEqual(summary.weekSeconds, 600, "일요일이 이번 주에 포함되면 안 된다")
        XCTAssertEqual(summary.weekSessionCount, 1)
    }

    /// "이번 달" 은 롤링이 아니라 달력상 1일 기준이다.
    func testMonthIsCalendarMonthNotRolling() {
        let sessions = [record(startAt: date(2026, 7, 31, 10, 0), seconds: 900)]
        let summary = subject.summarize(sessions, now: now)

        XCTAssertEqual(summary.monthSeconds, 0, "7/31 은 지난달")
    }

    // MARK: - §4.2 주간 스트립

    /// 7칸이고 **월요일이 맨 앞**이다. 화면에서 왼쪽이 월요일이 된다.
    func testWeekdayTotalsStartOnMondayAndRunForward() {
        let summary = subject.summarize([], now: now)

        XCTAssertEqual(summary.weekdayTotals.count, StatsCalculator.weekdayCount)
        XCTAssertEqual(
            summary.weekdayTotals[0].date,
            calendar.startOfDay(for: date(2026, 8, 17)),
            "8/17 월요일이 맨 앞"
        )
        XCTAssertEqual(
            summary.weekdayTotals[6].date,
            calendar.startOfDay(for: date(2026, 8, 23)),
            "8/23 일요일이 맨 뒤"
        )

        // 날짜가 하루씩 미래로 올라간다 — 시간이 왼쪽에서 오른쪽으로 흐른다.
        for index in 1..<summary.weekdayTotals.count {
            XCTAssertGreaterThan(
                summary.weekdayTotals[index].date,
                summary.weekdayTotals[index - 1].date
            )
        }
    }

    /// 아직 오지 않은 요일도 0 으로 자리를 채운다. 주가 진행되며 칸 수가
    /// 달라지면 한 주의 모양을 비교할 수 없다.
    func testFutureWeekdaysKeepTheirSlotsAtZero() {
        let sessions = [record(startAt: date(2026, 8, 17, 10, 0), seconds: 600)]
        let summary = subject.summarize(sessions, now: now)

        XCTAssertEqual(summary.weekdayTotals.count, 7)
        XCTAssertEqual(summary.weekdayTotals[0].seconds, 600, "월요일")
        // 오늘은 목요일(index 3). 금·토·일은 아직 오지 않았다.
        XCTAssertEqual(summary.weekdayTotals[4].seconds, 0)
        XCTAssertEqual(summary.weekdayTotals[6].seconds, 0)
    }

    /// 같은 날 여러 세션은 한 칸에 합쳐진다.
    func testSameDaySessionsAreSummed() {
        let sessions = [
            record(startAt: date(2026, 8, 20, 9, 0), seconds: 600),
            record(startAt: date(2026, 8, 20, 15, 0), seconds: 900)
        ]
        let summary = subject.summarize(sessions, now: now)

        XCTAssertEqual(summary.todaySeconds, 1500)
        XCTAssertEqual(summary.weekdayTotals[3].seconds, 1500, "목요일 칸")
        XCTAssertEqual(summary.weekSessionCount, 2)
    }

    // MARK: - §4.2 링 기준값

    /// 목표 설정 기능이 없으므로 링 분모는 고정값이다. 값이 흔들리면
    /// 어제와 오늘의 링을 눈으로 비교할 수 없다.
    func testFullRingIsAFixedFiveHours() {
        XCTAssertEqual(StatsSummary.fullRingSeconds, 5 * 3600)
    }

    func testFillFractionRunsFromZeroToOne() {
        XCTAssertEqual(StatsSummary.fillFraction(forSeconds: 0), 0)
        XCTAssertEqual(StatsSummary.fillFraction(forSeconds: -60), 0, "음수도 0")
        XCTAssertEqual(StatsSummary.fillFraction(forSeconds: 150 * 60), 0.5, accuracy: 0.001)
        XCTAssertEqual(StatsSummary.fillFraction(forSeconds: 5 * 3600), 1)
        XCTAssertEqual(StatsSummary.fillFraction(forSeconds: 9 * 3600), 1, "첫 바퀴는 넘지 않는다")
    }

    /// 기준 이하에서는 두 번째 바퀴가 없어야 한다. 있으면 평범한 날에도
    /// 안쪽 호가 그려져 무슨 뜻인지 알 수 없다.
    func testOverflowIsZeroUpToTheReference() {
        XCTAssertEqual(StatsSummary.overflowFraction(forSeconds: 0), 0)
        XCTAssertEqual(StatsSummary.overflowFraction(forSeconds: 3 * 3600), 0)
        XCTAssertEqual(StatsSummary.overflowFraction(forSeconds: 5 * 3600), 0, "정확히 기준이면 초과 없음")
    }

    /// 5시간·7시간·10시간이 서로 다르게 보여야 한다 — 이 함수가 없으면 전부 같아진다.
    func testOverflowGrowsPastTheReferenceAndCapsAtOne() {
        XCTAssertEqual(StatsSummary.overflowFraction(forSeconds: 7 * 3600), 0.4, accuracy: 0.001)
        XCTAssertEqual(StatsSummary.overflowFraction(forSeconds: 10 * 3600), 1)
        XCTAssertEqual(StatsSummary.overflowFraction(forSeconds: 14 * 3600), 1, "두 바퀴에서 멈춘다")
    }

    // MARK: - §12 빈 상태

    func testEmptyInputProducesZeroedSummary() {
        let summary = subject.summarize([], now: now)

        XCTAssertEqual(summary.todaySeconds, 0)
        XCTAssertEqual(summary.weekSeconds, 0)
        XCTAssertEqual(summary.monthSeconds, 0)
        XCTAssertEqual(summary.weekSessionCount, 0)
        XCTAssertEqual(summary.weekdayTotals.count, StatsCalculator.weekdayCount)
        XCTAssertTrue(summary.weekdayTotals.allSatisfy { $0.seconds == 0 })
        XCTAssertEqual(summary.dailyTotals.count, StatsCalculator.dailySeriesDayCount)
        XCTAssertTrue(summary.dailyTotals.allSatisfy { $0.seconds == 0 })
    }

    // MARK: - 중도 중지 세션

    /// §6-4 로 저장된 미완료 세션도 집중한 시간이므로 집계에 들어간다.
    func testIncompleteSessionsCountTowardTotals() {
        let sessions = [record(startAt: date(2026, 8, 20, 10, 0), seconds: 300, completed: false)]
        let summary = subject.summarize(sessions, now: now)

        XCTAssertEqual(summary.todaySeconds, 300)
        XCTAssertEqual(summary.weekSessionCount, 1)
    }

    // MARK: - 미래 세션 방어

    /// 기기 시계가 앞으로 튀었다 돌아온 경우, 미래 날짜 세션이 합계를 부풀리면 안 된다.
    func testFutureSessionsAreNotCounted() {
        let sessions = [record(startAt: date(2026, 8, 25, 10, 0), seconds: 3600)]
        let summary = subject.summarize(sessions, now: now)

        XCTAssertEqual(summary.todaySeconds, 0)
        XCTAssertEqual(summary.weekSeconds, 0)
        XCTAssertEqual(summary.monthSeconds, 0)
        XCTAssertEqual(summary.weekSessionCount, 0)
    }

    // MARK: - 조회 윈도우

    /// 저장소에서 꺼내올 범위는 이번 달 1일 / 9일 전 / 이번 주 월요일 중 가장 이른 쪽이다.
    func testWindowStartTakesTheEarliestBoundary() {
        // 8/20 → 8/1 vs 8/11 vs 8/17 → 8/1 이 이르다
        XCTAssertEqual(subject.windowStart(for: now), calendar.startOfDay(for: date(2026, 8, 1)))

        // 8/5 → 8/1 vs 7/27 vs 8/3 → 7/27 이 이르다
        XCTAssertEqual(
            subject.windowStart(for: date(2026, 8, 5)),
            calendar.startOfDay(for: date(2026, 7, 27))
        )

        // 월 초에 주가 지난달에 걸치는 경우 그 월요일까지 내려가야 한다.
        // 2026-03-01 은 일요일이므로 이번 주 월요일은 2/23 이다.
        XCTAssertEqual(
            subject.windowStart(for: date(2026, 3, 1)),
            calendar.startOfDay(for: date(2026, 2, 20)),
            "9일 전(2/20)이 주 시작(2/23)보다 이르다"
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
