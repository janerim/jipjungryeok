import Foundation

public enum TimerPhase: Equatable, Sendable {
    case idle
    case running
    case paused
}

/// 타이머의 모든 상태 전이와 시간 계산 (§6).
///
/// **순수 값 타입이다.** `Timer` 도, `Date()` 직접 호출도 없다. 현재 시각은 전부
/// 인자로 주입받는다. 그래서 시뮬레이터 없이, 실제로 25분을 기다리지 않고도
/// 일시정지·강제 종료·시간대 변경 시나리오를 단위 테스트로 검증할 수 있다.
///
/// 1초 `Timer` 는 화면을 다시 그리라는 신호일 뿐이며, 값은 언제나 `Date` 차이로
/// 재계산한다. 절대로 `remaining -= 1` 로 누적하지 않는다 (§6-1).
public struct TimerEngine: Equatable, Sendable {

    // MARK: - 상수

    /// §4.1 다이얼 최소값
    public static let minimumMinutes = 1

    /// §4.1 다이얼 최대값. 다이얼 한 바퀴가 곧 이 값이다.
    public static let maximumMinutes = 60

    /// §6-4 중도 중지 시, 이 시간 미만이면 기록하지 않고 버린다.
    public static let minimumRecordedSeconds = 60

    // MARK: - 상태

    /// 다이얼이 가리키는 시간. idle 에서 드래그로 바뀐다.
    public private(set) var plannedSeconds: Int

    /// 진행 중인 세션. `nil` 이면 idle.
    public private(set) var running: RunningState?

    public init(plannedMinutes: Int = 25) {
        self.plannedSeconds = Self.clamped(minutes: plannedMinutes) * 60
        self.running = nil
    }

    // MARK: - 파생 값

    public var phase: TimerPhase {
        guard let running else { return .idle }
        return running.pausedAt == nil ? .running : .paused
    }

    public var plannedMinutes: Int {
        plannedSeconds / 60
    }

    /// 지금 상태가 그대로 이어질 때 세션이 끝나는 절대시각. 일시정지 중이거나 idle 이면 `nil`.
    ///
    /// 완료 판정의 기준이자, M3 에서 로컬 알림을 예약할 시각이다 (§6-5).
    public var expectedEndDate: Date? {
        guard let running, running.pausedAt == nil else { return nil }
        let offset = Double(running.plannedSeconds + running.accumulatedPauseSeconds)
        return running.startAt.addingTimeInterval(offset)
    }

    /// 일시정지 구간을 제외하고 실제로 집중한 초.
    ///
    /// 일시정지 중이면 정지 시점에서 얼어붙는다. 기기 시계가 뒤로 점프해도
    /// 음수가 되지 않고, 설정 시간을 넘어가지도 않는다 (§12 수용 기준).
    public func actualSeconds(at now: Date) -> Int {
        guard let running else { return 0 }
        // 일시정지 중이면 흐르는 시간의 기준을 '지금' 이 아니라 '멈춘 순간' 으로 바꾼다.
        let reference = running.pausedAt ?? now
        let elapsed = reference.timeIntervalSince(running.startAt)
            - Double(running.accumulatedPauseSeconds)
        let floored = Int(elapsed.rounded(.down))
        return min(running.plannedSeconds, max(0, floored))
    }

    /// 남은 초. idle 이면 다이얼에 설정된 시간을 그대로 돌려준다.
    public func remainingSeconds(at now: Date) -> Int {
        guard let running else { return plannedSeconds }
        return max(0, running.plannedSeconds - actualSeconds(at: now))
    }

    /// 다이얼 부채꼴 채움 비율 (0...1). 한 바퀴가 60분이므로 남은 시간을 60분으로 나눈다.
    public func dialFraction(at now: Date) -> Double {
        let seconds = Double(remainingSeconds(at: now))
        let full = Double(Self.maximumMinutes * 60)
        return min(1, max(0, seconds / full))
    }

    // MARK: - 상태 전이

    /// 다이얼로 시간을 설정한다.
    ///
    /// 진행 중이거나 일시정지 상태에서 다이얼을 돌리면 §4.1 규칙대로 기존 세션을 먼저
    /// 끝낸다. 그 세션이 §6-4 기준(60초 이상)을 넘겼다면 기록으로 돌려주고,
    /// 아니면 `nil` 을 돌려주며 조용히 버린다.
    @discardableResult
    public mutating func setPlannedMinutes(_ minutes: Int, at now: Date) -> SessionRecord? {
        // idle 이면 stop 이 아무 일도 하지 않고 nil 을 돌려준다.
        let ended = stop(at: now)
        plannedSeconds = Self.clamped(minutes: minutes) * 60
        return ended
    }

    /// 세션을 시작한다. 이미 진행 중이면 아무 일도 하지 않는다.
    public mutating func start(at now: Date, sessionID: UUID = UUID()) {
        guard running == nil else { return }
        running = RunningState(
            sessionID: sessionID,
            startAt: now,
            plannedSeconds: plannedSeconds
        )
    }

    /// 일시정지. running 이 아니면 아무 일도 하지 않는다.
    public mutating func pause(at now: Date) {
        guard var state = running, state.pausedAt == nil else { return }
        state.pausedAt = now
        running = state
    }

    /// 재개. 멈춰 있던 만큼을 누적 정지 시간에 더하므로, 종료 시각이 정확히 그만큼만 밀린다.
    public mutating func resume(at now: Date) {
        guard var state = running, let pausedAt = state.pausedAt else { return }
        // 시계가 뒤로 점프한 경우 음수가 누적되지 않도록 막는다.
        let pausedFor = max(0, now.timeIntervalSince(pausedAt))
        state.accumulatedPauseSeconds += Int(pausedFor.rounded())
        state.pausedAt = nil
        running = state
    }

    /// 중도 중지 (§6-4).
    ///
    /// 실제 집중 시간이 60초 이상이면 `isCompleted = false` 인 기록을 돌려주고,
    /// 미만이면 `nil` 을 돌려주며 버린다. 어느 쪽이든 상태는 idle 로 돌아간다.
    @discardableResult
    public mutating func stop(at now: Date) -> SessionRecord? {
        guard let state = running else { return nil }
        let actual = actualSeconds(at: now)
        // 일시정지한 채로 오래 방치했다가 중지한 경우, 캘린더 이벤트(§7)가 몇 시간짜리로
        // 남지 않도록 종료 시각을 '멈춘 순간' 으로 잡는다.
        let endAt = state.pausedAt ?? now
        running = nil

        guard actual >= Self.minimumRecordedSeconds else { return nil }

        return SessionRecord(
            id: state.sessionID,
            startAt: state.startAt,
            endAt: endAt,
            plannedSeconds: state.plannedSeconds,
            actualSeconds: actual,
            isCompleted: false
        )
    }

    /// 종료 시각이 지났으면 완료 처리한다 (§6-2, §6-3).
    ///
    /// 종료 시각은 `now` 가 아니라 `expectedEndDate` 로 기록한다. 앱이 백그라운드에 있는
    /// 동안 세션이 끝났다가 한참 뒤에 복귀해도, 세션이 실제로 끝난 시각이 남아야
    /// 캘린더 이벤트(§7)와 통계가 어긋나지 않는다.
    @discardableResult
    public mutating func completeIfElapsed(at now: Date) -> SessionRecord? {
        guard let state = running,
              state.pausedAt == nil,
              let endAt = expectedEndDate,
              now >= endAt else { return nil }

        running = nil

        return SessionRecord(
            id: state.sessionID,
            startAt: state.startAt,
            endAt: endAt,
            plannedSeconds: state.plannedSeconds,
            actualSeconds: state.plannedSeconds,
            isCompleted: true
        )
    }

    /// 저장해 둔 진행 상태를 되살린다 (M3 에서 앱 강제 종료 복구에 사용).
    public mutating func restore(_ state: RunningState) {
        running = state
        plannedSeconds = state.plannedSeconds
    }

    // MARK: -

    private static func clamped(minutes: Int) -> Int {
        min(maximumMinutes, max(minimumMinutes, minutes))
    }
}
