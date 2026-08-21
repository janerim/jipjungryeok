import XCTest
@testable import FocusCore

/// §6 타이머 동작 규칙과 §12 수용 기준의 타이머 항목을 검증한다.
///
/// `TimerEngine` 이 현재 시각을 인자로 받기 때문에, 실제로 25분을 기다리지 않고
/// 시간을 앞뒤로 밀어 가며 전부 확인할 수 있다.
///
/// 메서드명을 영문으로 두는 이유: XCTest 는 ObjC 런타임으로 테스트를 찾고,
/// 비ASCII 셀렉터는 문제가 될 수 있다. 설명은 각 메서드의 주석에 남긴다.
final class TimerEngineTests: XCTestCase {

    /// 기준 시각. 어떤 값이든 상관없지만 고정해 두어야 실패를 재현할 수 있다.
    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)

    private func at(_ seconds: TimeInterval) -> Date {
        t0.addingTimeInterval(seconds)
    }

    // MARK: - 시작

    /// 시작하면 즉시 카운트다운이 흐른다.
    func testStartBeginsCountdownImmediately() {
        var engine = TimerEngine(plannedMinutes: 25)
        XCTAssertEqual(engine.phase, .idle)
        XCTAssertEqual(engine.remainingSeconds(at: t0), 25 * 60)

        engine.start(at: t0)

        XCTAssertEqual(engine.phase, .running)
        XCTAssertEqual(engine.remainingSeconds(at: at(0)), 1500)
        XCTAssertEqual(engine.remainingSeconds(at: at(1)), 1499)
        XCTAssertEqual(engine.remainingSeconds(at: at(60)), 1440)
    }

    /// 이미 진행 중이면 다시 시작해도 세션이 바뀌지 않는다.
    func testStartIsIgnoredWhileAlreadyRunning() {
        var engine = TimerEngine(plannedMinutes: 10)
        engine.start(at: t0)
        let firstID = engine.running?.sessionID

        engine.start(at: at(30))

        XCTAssertEqual(engine.running?.sessionID, firstID)
        XCTAssertEqual(engine.running?.startAt, t0)
    }

    // MARK: - §12 앱을 종료했다가 다시 켜도 남은 시간이 정확하다

    /// 남은 시간은 1초씩 누적하는 값이 아니라 절대시각으로 매번 다시 계산된다.
    /// 1초 Timer 가 한 번도 돌지 않은 채 10분이 지나도 값이 정확해야 한다.
    func testRemainingIsRecomputedFromAbsoluteTime() {
        var engine = TimerEngine(plannedMinutes: 25)
        engine.start(at: t0)

        XCTAssertEqual(engine.remainingSeconds(at: at(600)), 900)
        XCTAssertEqual(engine.actualSeconds(at: at(600)), 600)
    }

    // MARK: - 일시정지 / 재개

    /// 일시정지하면 남은 시간이 얼어붙는다.
    func testPauseFreezesRemaining() {
        var engine = TimerEngine(plannedMinutes: 25)
        engine.start(at: t0)
        engine.pause(at: at(300))

        XCTAssertEqual(engine.phase, .paused)
        XCTAssertEqual(engine.remainingSeconds(at: at(300)), 1200)
        // 10분을 더 방치해도 그대로여야 한다
        XCTAssertEqual(engine.remainingSeconds(at: at(900)), 1200)
        XCTAssertNil(engine.expectedEndDate, "일시정지 중에는 종료 예정 시각이 없다")
    }

    /// §12 — 재개하면 일시정지한 만큼만 종료 시각이 밀린다.
    func testResumeShiftsEndByExactlyThePausedDuration() {
        var engine = TimerEngine(plannedMinutes: 25)
        engine.start(at: t0)
        XCTAssertEqual(engine.expectedEndDate, at(1500))

        engine.pause(at: at(300))     // 5분 시점에 정지
        engine.resume(at: at(500))    // 200초 쉬고 재개

        XCTAssertEqual(engine.phase, .running)
        XCTAssertEqual(engine.expectedEndDate, at(1700), "정확히 200초만 밀려야 한다")
        XCTAssertEqual(engine.remainingSeconds(at: at(500)), 1200)
    }

    /// 여러 번 일시정지해도 누적된다.
    func testMultiplePausesAccumulate() {
        var engine = TimerEngine(plannedMinutes: 25)
        engine.start(at: t0)

        engine.pause(at: at(100))
        engine.resume(at: at(160))    // 60초
        engine.pause(at: at(200))
        engine.resume(at: at(290))    // 90초

        XCTAssertEqual(engine.running?.accumulatedPauseSeconds, 150)
        XCTAssertEqual(engine.expectedEndDate, at(1650))
    }

    /// 일시정지한 시간은 실제 집중 시간에서 빠진다.
    func testPausedTimeIsExcludedFromActualSeconds() {
        var engine = TimerEngine(plannedMinutes: 25)
        engine.start(at: t0)
        engine.pause(at: at(300))
        engine.resume(at: at(900))    // 10분 쉬었다

        // 벽시계로는 900초가 지났지만 집중한 건 300초뿐이다
        XCTAssertEqual(engine.actualSeconds(at: at(900)), 300)
    }

    /// running 이 아닐 때의 일시정지·재개 호출은 무시된다.
    func testPauseAndResumeAreIgnoredWhenNotApplicable() {
        var engine = TimerEngine(plannedMinutes: 25)

        engine.pause(at: t0)
        XCTAssertEqual(engine.phase, .idle)

        engine.resume(at: t0)
        XCTAssertEqual(engine.phase, .idle)

        engine.start(at: t0)
        engine.resume(at: at(10))     // 정지한 적이 없다
        XCTAssertEqual(engine.running?.accumulatedPauseSeconds, 0)
    }

    // MARK: - 완료 (§6-2, §6-3)

    /// 종료 시각 전에는 완료되지 않는다.
    func testDoesNotCompleteBeforeEndDate() {
        var engine = TimerEngine(plannedMinutes: 25)
        engine.start(at: t0)

        XCTAssertNil(engine.completeIfElapsed(at: at(1499)))
        XCTAssertEqual(engine.phase, .running)
    }

    /// 종료 시각에 도달하면 완료 기록을 내놓고 idle 로 돌아간다.
    func testCompletesAtEndDate() throws {
        var engine = TimerEngine(plannedMinutes: 25)
        engine.start(at: t0)

        let record = try XCTUnwrap(engine.completeIfElapsed(at: at(1500)))

        XCTAssertTrue(record.isCompleted)
        XCTAssertEqual(record.startAt, t0)
        XCTAssertEqual(record.endAt, at(1500))
        XCTAssertEqual(record.plannedSeconds, 1500)
        XCTAssertEqual(record.actualSeconds, 1500)
        XCTAssertEqual(engine.phase, .idle, "완료 후에는 idle 로 돌아간다")
    }

    /// §6-2 — 백그라운드에 있는 동안 끝난 세션은 '복귀한 시각' 이 아니라
    /// '실제로 끝난 시각' 으로 기록돼야 한다. 안 그러면 캘린더 이벤트(§7)가 늘어나고
    /// 통계에 3시간을 집중한 것으로 잡힌다.
    func testCompletionUsesExpectedEndNotReturnTime() throws {
        var engine = TimerEngine(plannedMinutes: 25)
        engine.start(at: t0)

        // 3시간 뒤에야 앱이 포그라운드로 돌아왔다
        let record = try XCTUnwrap(engine.completeIfElapsed(at: at(10_800)))

        XCTAssertEqual(record.endAt, at(1500), "복귀 시각이 아니라 종료 예정 시각이어야 한다")
        XCTAssertEqual(record.actualSeconds, 1500, "3시간을 집중한 것으로 기록되면 안 된다")
    }

    /// 일시정지 중에는 아무리 시간이 지나도 완료되지 않는다.
    func testDoesNotCompleteWhilePaused() {
        var engine = TimerEngine(plannedMinutes: 25)
        engine.start(at: t0)
        engine.pause(at: at(60))

        XCTAssertNil(engine.completeIfElapsed(at: at(100_000)))
        XCTAssertEqual(engine.phase, .paused)
    }

    // MARK: - §12 시계가 튀어도 남은 시간이 깨지지 않는다

    /// 시계가 뒤로 점프해도 남은 시간이 설정값을 넘지 않는다.
    func testBackwardClockJumpDoesNotExceedPlanned() {
        var engine = TimerEngine(plannedMinutes: 25)
        engine.start(at: t0)

        // 시간대 변경 등으로 now 가 시작 시각보다 앞서 버린 경우
        XCTAssertEqual(engine.remainingSeconds(at: at(-3600)), 1500)
        XCTAssertEqual(engine.actualSeconds(at: at(-3600)), 0)
    }

    /// 시계가 앞으로 점프해도 남은 시간이 음수가 되지 않는다.
    func testForwardClockJumpDoesNotGoNegative() {
        var engine = TimerEngine(plannedMinutes: 25)
        engine.start(at: t0)

        XCTAssertEqual(engine.remainingSeconds(at: at(999_999)), 0)
        XCTAssertEqual(engine.actualSeconds(at: at(999_999)), 1500)
    }

    /// 재개 시각이 정지 시각보다 앞서더라도 정지 시간이 음수로 누적되지 않는다.
    func testResumeDoesNotAccumulateNegativePause() {
        var engine = TimerEngine(plannedMinutes: 25)
        engine.start(at: t0)
        engine.pause(at: at(300))
        engine.resume(at: at(200))

        XCTAssertEqual(engine.running?.accumulatedPauseSeconds, 0)
    }

    // MARK: - 중도 중지 (§6-4)

    /// 60초 미만 중지는 기록하지 않고 버린다.
    func testStopBelowThresholdIsDiscarded() {
        var engine = TimerEngine(plannedMinutes: 25)
        engine.start(at: t0)

        XCTAssertNil(engine.stop(at: at(59)))
        XCTAssertEqual(engine.phase, .idle, "기록은 안 해도 상태는 idle 로 돌아간다")
    }

    /// 60초 이상 중지는 미완료(`isCompleted = false`)로 기록한다.
    func testStopAtThresholdIsRecordedAsIncomplete() throws {
        var engine = TimerEngine(plannedMinutes: 25)
        engine.start(at: t0)

        let record = try XCTUnwrap(engine.stop(at: at(60)))

        XCTAssertFalse(record.isCompleted)
        XCTAssertEqual(record.actualSeconds, 60)
        XCTAssertEqual(record.plannedSeconds, 1500)
        XCTAssertEqual(record.endAt, at(60))
    }

    /// 일시정지한 채로 오래 방치했다가 중지하면, 종료 시각은 '멈춘 순간' 이어야 한다.
    /// 그러지 않으면 §7 캘린더에 몇 시간짜리 이벤트가 남는다.
    func testStopWhilePausedEndsAtPauseInstant() throws {
        var engine = TimerEngine(plannedMinutes: 25)
        engine.start(at: t0)
        engine.pause(at: at(300))

        let record = try XCTUnwrap(engine.stop(at: at(7500)))   // 2시간 뒤 중지

        XCTAssertEqual(record.actualSeconds, 300)
        XCTAssertEqual(record.endAt, at(300), "2시간짜리 캘린더 이벤트가 되면 안 된다")
    }

    /// idle 에서 중지하면 아무 일도 일어나지 않는다.
    func testStopWhileIdleDoesNothing() {
        var engine = TimerEngine(plannedMinutes: 25)
        XCTAssertNil(engine.stop(at: t0))
        XCTAssertEqual(engine.phase, .idle)
    }

    // MARK: - 다이얼 설정 (§4.1)

    /// 설정 시간은 1분에서 60분 사이로 잘린다.
    func testPlannedMinutesAreClamped() {
        var engine = TimerEngine(plannedMinutes: 25)

        engine.setPlannedMinutes(0, at: t0)
        XCTAssertEqual(engine.plannedMinutes, 1)

        engine.setPlannedMinutes(-5, at: t0)
        XCTAssertEqual(engine.plannedMinutes, 1)

        engine.setPlannedMinutes(61, at: t0)
        XCTAssertEqual(engine.plannedMinutes, 60)

        engine.setPlannedMinutes(37, at: t0)
        XCTAssertEqual(engine.plannedMinutes, 37)
    }

    /// 생성자도 같은 범위로 잘린다.
    func testInitializerClampsMinutes() {
        XCTAssertEqual(TimerEngine(plannedMinutes: 0).plannedMinutes, 1)
        XCTAssertEqual(TimerEngine(plannedMinutes: 900).plannedMinutes, 60)
    }

    /// §4.1 — 일시정지 중 다이얼을 돌리면 기존 세션이 §6-4 규칙대로 정리되고
    /// 새 시간이 설정된다.
    func testAdjustingWhilePausedEndsPreviousSession() throws {
        var engine = TimerEngine(plannedMinutes: 25)
        engine.start(at: t0)
        engine.pause(at: at(300))

        let ended = try XCTUnwrap(engine.setPlannedMinutes(10, at: at(310)))

        XCTAssertFalse(ended.isCompleted)
        XCTAssertEqual(ended.actualSeconds, 300)
        XCTAssertEqual(engine.phase, .idle)
        XCTAssertEqual(engine.plannedMinutes, 10)
        XCTAssertEqual(engine.remainingSeconds(at: at(310)), 600)
    }

    /// 진행 중 다이얼을 돌렸는데 60초 미만이었다면 기록이 남지 않는다.
    func testAdjustingWhileRunningBelowThresholdLeavesNoRecord() {
        var engine = TimerEngine(plannedMinutes: 25)
        engine.start(at: t0)

        XCTAssertNil(engine.setPlannedMinutes(40, at: at(30)))
        XCTAssertEqual(engine.plannedMinutes, 40)
        XCTAssertEqual(engine.phase, .idle)
    }

    // MARK: - 다이얼 렌더링 값

    /// 부채꼴 비율은 언제나 60분 한 바퀴 기준이다.
    func testDialFractionIsRelativeToFullHour() {
        var engine = TimerEngine(plannedMinutes: 60)
        XCTAssertEqual(engine.dialFraction(at: t0), 1.0, accuracy: 0.0001)

        engine = TimerEngine(plannedMinutes: 30)
        XCTAssertEqual(engine.dialFraction(at: t0), 0.5, accuracy: 0.0001)

        engine = TimerEngine(plannedMinutes: 15)
        engine.start(at: t0)
        // 900초 중 450초 지남 → 남은 450초 = 60분의 1/8
        XCTAssertEqual(engine.dialFraction(at: at(450)), 0.125, accuracy: 0.0001)
        XCTAssertEqual(engine.dialFraction(at: at(900)), 0.0, accuracy: 0.0001)
    }

    // MARK: - 복구 (M3 준비)

    /// 저장된 진행 상태를 되살릴 수 있다.
    func testRestoreRebuildsRunningSession() {
        var engine = TimerEngine(plannedMinutes: 5)
        let state = RunningState(
            sessionID: UUID(),
            startAt: t0,
            plannedSeconds: 1500,
            accumulatedPauseSeconds: 120
        )

        engine.restore(state)

        XCTAssertEqual(engine.phase, .running)
        XCTAssertEqual(engine.plannedMinutes, 25)
        XCTAssertEqual(engine.expectedEndDate, at(1620))
        XCTAssertEqual(engine.remainingSeconds(at: at(600)), 1020)
    }

    /// 일시정지 상태로 저장돼 있었다면 되살린 뒤에도 멈춰 있어야 한다.
    /// 앱을 강제 종료했다 켰다는 이유로 타이머가 혼자 다시 흐르면 안 된다.
    func testRestoreKeepsPausedSessionPaused() {
        var engine = TimerEngine(plannedMinutes: 5)
        let state = RunningState(
            sessionID: UUID(),
            startAt: t0,
            plannedSeconds: 1500,
            accumulatedPauseSeconds: 0,
            pausedAt: at(300)
        )

        engine.restore(state)

        XCTAssertEqual(engine.phase, .paused)
        XCTAssertNil(engine.expectedEndDate)
        // 복원 시각이 한참 뒤여도 300초 시점에서 얼어붙어 있어야 한다
        XCTAssertEqual(engine.remainingSeconds(at: at(100_000)), 1200)
    }

    /// §12 앱 강제 종료 복구 — 꺼져 있는 동안 세션이 끝났다면, 되살리자마자
    /// **실제로 끝난 시각**으로 완료 처리돼야 한다. 앱을 다시 연 시각이 아니다.
    func testRestoredSessionThatAlreadyEndedCompletesAtItsRealEnd() throws {
        var engine = TimerEngine(plannedMinutes: 5)
        let state = RunningState(
            sessionID: UUID(),
            startAt: t0,
            plannedSeconds: 1500,
            accumulatedPauseSeconds: 120
        )

        engine.restore(state)
        // 앱을 하루 뒤에 열었다
        let record = try XCTUnwrap(engine.completeIfElapsed(at: at(86_400)))

        XCTAssertTrue(record.isCompleted)
        XCTAssertEqual(record.endAt, at(1620), "정지 시간 120초를 더한 종료 예정 시각")
        XCTAssertEqual(record.actualSeconds, 1500, "하루를 집중한 것으로 기록되면 안 된다")
        XCTAssertEqual(record.id, state.sessionID, "복원 전과 같은 세션이어야 중복 저장되지 않는다")
        XCTAssertEqual(engine.phase, .idle)
    }

    /// 복원 직후에도 다이얼은 그 세션의 설정 시간을 가리킨다 (§6-3 idle 복귀 규칙).
    func testRestoreAdoptsPlannedMinutesFromSavedState() {
        var engine = TimerEngine(plannedMinutes: 5)
        engine.restore(
            RunningState(sessionID: UUID(), startAt: t0, plannedSeconds: 40 * 60)
        )
        XCTAssertEqual(engine.plannedMinutes, 40)
    }

    /// 진행 상태는 Codable 로 왕복한다 (M3 에서 App Group UserDefaults 에 저장).
    func testRunningStateRoundTripsThroughCodable() throws {
        let state = RunningState(
            sessionID: UUID(),
            startAt: t0,
            plannedSeconds: 1500,
            accumulatedPauseSeconds: 90,
            pausedAt: at(400)
        )

        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(RunningState.self, from: data)

        XCTAssertEqual(decoded, state)
    }
}
