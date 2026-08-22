import Foundation
import Observation
import UIKit
import FocusCore

/// 타이머 화면의 상태 보유자.
///
/// 시간 계산은 전부 `FocusCore.TimerEngine` 이 한다. 여기가 맡는 것은 순수 로직이
/// 건드릴 수 없는 것들뿐이다 — 1초 화면 갱신, 햅틱, 화면 자동 잠금,
/// 그리고 진행 상태 보존과 알림 예약(M3).
@MainActor
@Observable
final class TimerViewModel {

    private(set) var engine = TimerEngine()

    /// 화면 갱신 기준 시각. 1초마다 그리고 포그라운드 복귀 때 갱신된다.
    private(set) var now: Date = .now

    @ObservationIgnored private var ticker: Timer?
    @ObservationIgnored private let recorder: SessionRecorder
    @ObservationIgnored private let notifications: NotificationService
    @ObservationIgnored private let liveActivity = LiveActivityService()

    init(recorder: SessionRecorder, notifications: NotificationService, defaultMinutes: Int) {
        self.recorder = recorder
        self.notifications = notifications
        // 복구할 세션이 있으면 아래에서 덮어쓴다. 없을 때만 이 값이 다이얼의 출발점이다.
        self.engine = TimerEngine(plannedMinutes: defaultMinutes)
        restoreRunningSession()
    }

    /// §4.3 설정에서 기본값을 바꿨을 때. **쉬고 있을 때만** 반영한다 —
    /// 돌아가는 세션의 시간을 설정 화면이 바꿔 버리면 안 된다.
    func applyDefaultMinutes(_ minutes: Int) {
        guard engine.phase == .idle else { return }
        engine = TimerEngine(plannedMinutes: minutes)
    }

    // MARK: - 화면이 읽는 값

    var phase: TimerPhase { engine.phase }

    var remainingSeconds: Int { engine.remainingSeconds(at: now) }

    /// 쉬고 있을 때는 분만, 돌아갈 때는 `M:SS`.
    ///
    /// 다이얼을 맞추는 중에 `25:00` 이 보이면 초 단위로 맞추는 것처럼 읽힌다.
    /// 스냅은 1분 단위이므로 그 자리에서 초는 의미가 없다.
    var countdownText: String {
        switch engine.phase {
        case .idle:
            return "\(engine.plannedMinutes)"
        case .running, .paused:
            return TimeDisplay.countdown(remainingSeconds)
        }
    }

    var dialFraction: Double { engine.dialFraction(at: now) }

    /// VoiceOver 가 읽는 현재 상태. 화면의 숫자만으로는 idle 인지 paused 인지 알 수 없다.
    var accessibilityStatus: String {
        switch engine.phase {
        case .idle:    "집중 \(engine.plannedMinutes)분, 대기 중"
        case .running: "남은 시간 \(TimeDisplay.countdown(remainingSeconds)), 진행 중"
        case .paused:  "남은 시간 \(TimeDisplay.countdown(remainingSeconds)), 일시정지"
        }
    }

    var accessibilityActionHint: String {
        switch engine.phase {
        case .idle:    "두 번 탭하여 시작"
        case .running: "두 번 탭하여 일시정지"
        case .paused:  "두 번 탭하여 계속"
        }
    }

    /// 숫자 아래 한 줄. 돌아가는 중에는 비운다 — 그때는 숫자가 스스로 상태를 말한다.
    var primaryHint: String {
        switch engine.phase {
        case .idle:   "탭하여 시작"
        case .paused: "탭하여 계속"
        case .running: ""
        }
    }

    // MARK: - 앱 강제 종료 복구 (§12)

    /// 저장해 둔 진행 상태가 있으면 되살린다.
    ///
    /// 남은 시간은 저장돼 있지 않고 `startAt` 에서 다시 계산되므로(§6-1), 앱이 죽어
    /// 있던 시간도 정확히 반영된다. 그 사이에 이미 끝났다면 여기서 완료 처리된다.
    private func restoreRunningSession() {
        guard let state = RunningStateStore.load() else { return }

        engine.restore(state)
        now = .now

        if let record = engine.completeIfElapsed(at: now) {
            // 앱이 꺼져 있는 동안 끝난 세션. 종료 시각은 지금이 아니라 실제로 끝난 시점이다.
            //
            // 햅틱은 울리지 않는다. 그 세션이 끝날 때 이미 무음 배너가 떴고(§6-3),
            // 몇 시간 뒤에 앱을 여는 순간 진동하는 것은 아무 의미가 없다.
            finishCompleted(record)
            return
        }

        switch engine.phase {
        case .running:
            startTicking()
            setScreenAwake(true)
            // 강제 종료돼도 예약된 알림은 남아 있지만, 같은 식별자로 덮어써 두면
            // 어느 경우든 정확히 한 개만 남는다.
            scheduleCompletionNotification()
            // §8.3 — Live Activity 도 마찬가지다. 앱이 죽어 있는 동안 시스템이
            // 정리했을 수도, 남아 있을 수도 있다. 다시 걸면 남은 것을 먼저 끝내고
            // 새로 만들므로 어느 경우든 정확히 한 개가 된다.
            startLiveActivity()
        case .paused, .idle:
            break
        }
    }

    // MARK: - 다이얼 입력 (§4.1)

    /// 드래그로 시간이 바뀌었다. 1분 스냅 단위로 들어온다.
    func dialDragged(toMinutes minutes: Int) {
        let previousMinutes = engine.plannedMinutes
        let wasIdle = engine.phase == .idle

        // 진행 중/일시정지 상태였다면 여기서 기존 세션이 정리된다 (§4.1, §6-4)
        if let finished = engine.setPlannedMinutes(minutes, at: .now) {
            recorder.finish(finished)
        }

        if !wasIdle {
            stopTicking()
            setScreenAwake(false)
            notifications.cancelPending()
            persistRunningState()
        }

        if engine.plannedMinutes != previousMinutes {
            Haptics.selection()
        }
        refresh()
    }

    /// §4.1 — idle 에서 손을 떼면 즉시 카운트다운이 시작된다.
    /// 손을 떼도 시작하지 않는다.
    ///
    /// 예전에는 여기서 바로 `start()` 했다(§4.1 옛 규칙). 시간을 맞추다 손이 미끄러지면
    /// 원하지 않은 세션이 시작되고, 그걸 되돌리려면 길게 눌러 중지해야 했다.
    /// 시작은 `primaryTapped()` 이 맡는다 — 의도한 행동이어야 시작된다.
    func dialDragEnded() {
        guard engine.phase == .idle else { return }
        persistRunningState()
    }

    /// §4.1 하단 숫자 탭 — 이 앱의 시작·정지 버튼이다.
    ///
    /// idle 이면 시작, running 이면 일시정지, paused 면 재개.
    /// 완전히 끝내는 것은 다이얼 길게 누르기가 맡는다(§4.1).
    func primaryTapped() {
        switch engine.phase {
        case .idle:
            start()
        case .running:
            pause()
        case .paused:
            resume()
        }
    }

    /// running 이면 일시정지, paused 면 재개. idle 에서는 아무 일도 없다.
    func dialTapped() {
        switch engine.phase {
        case .idle:
            break
        case .running:
            pause()
        case .paused:
            resume()
        }
    }

    /// 길게 누르기 = 세션 중지 (§4.1)
    func dialLongPressed() {
        guard engine.phase != .idle else { return }

        if let finished = engine.stop(at: .now) {
            recorder.finish(finished)
        }
        stopTicking()
        setScreenAwake(false)
        notifications.cancelPending()
        liveActivity.end()
        persistRunningState()
        refresh()
    }

    func dialDragBegan() {
        Haptics.prepareSelection()
    }

    // MARK: - 상태 전이

    func start() {
        engine.start(at: .now)
        startTicking()
        setScreenAwake(true)
        persistRunningState()
        scheduleCompletionNotification()
        startLiveActivity()
        refresh()
    }

    func pause() {
        engine.pause(at: .now)
        // 멈춰 있는 동안은 1초마다 다시 그릴 이유가 없다
        stopTicking()
        setScreenAwake(false)
        // §6-5 — 일시정지하면 예약을 반드시 지운다. 안 그러면 멈춰 있는데 알림이 뜬다.
        notifications.cancelPending()
        persistRunningState()
        // §8.3 — 멈춘 채로 카운트다운이 계속 도는 것처럼 보이면 안 된다.
        updateLiveActivity(pausedRemainingSeconds: engine.remainingSeconds(at: .now))
        refresh()
    }

    func resume() {
        engine.resume(at: .now)
        startTicking()
        setScreenAwake(true)
        persistRunningState()
        // §6-5 — 재개 시 남은 시간으로 재예약
        scheduleCompletionNotification()
        updateLiveActivity(pausedRemainingSeconds: nil)
        refresh()
    }

    /// 현재 시각으로 다시 계산하고, 종료 시각이 지났으면 완료 처리한다.
    ///
    /// 1초 타이머와 포그라운드 복귀(§6-2) 양쪽에서 불린다. 백그라운드에 있는 동안
    /// 세션이 끝났어도 여기서 잡힌다.
    func refresh() {
        now = .now
        if let record = engine.completeIfElapsed(at: now) {
            finishCompleted(record)
        }
    }

    // MARK: -

    private func finishCompleted(_ record: SessionRecord) {
        stopTicking()
        setScreenAwake(false)

        // 이미 떴거나 곧 뜰 알림을 정리한다. 포그라운드에서 끝났다면 예약이 아직 남아 있다.
        notifications.cancelPending()
        RunningStateStore.clear()

        // 저장이 곧 통계 갱신이다. SessionStore 가 save 안에서 reload 까지 한다.
        // 설정이 켜져 있으면 여기서 캘린더 기록(§7)까지 이어진다.
        recorder.finish(record)

        // §8.3 — 끝난 세션이 잠금화면에서 계속 도는 것처럼 보이면 안 된다.
        liveActivity.end()

        // 통계 스냅샷 갱신과 위젯 리로드는 recorder.finish → SessionStore.reload 가 한다.
    }

    // MARK: - §8.3 Live Activity

    private func startLiveActivity() {
        guard let running = engine.running, let endDate = engine.expectedEndDate else { return }
        liveActivity.start(
            plannedMinutes: engine.plannedMinutes,
            startDate: running.startAt,
            endDate: endDate
        )
    }

    /// 일시정지·재개로 종료 시각이 바뀌면 갱신한다.
    private func updateLiveActivity(pausedRemainingSeconds: Int?) {
        guard let running = engine.running else { return }
        // 멈춰 있을 때는 expectedEndDate 가 없을 수 있다. 그 경우 시작 시각만으로
        // 범위를 만들 수 없으므로 얼어붙은 값만 넘기고 링은 정지 상태로 그린다.
        let endDate = engine.expectedEndDate ?? running.startAt
        liveActivity.update(
            startDate: running.startAt,
            endDate: endDate,
            pausedRemainingSeconds: pausedRemainingSeconds
        )
    }

    /// §5 — 상태가 바뀔 때마다 저장한다. 전이 사이에는 값이 변하지 않으므로 이걸로 충분하다.
    private func persistRunningState() {
        RunningStateStore.save(engine.running)
    }

    private func scheduleCompletionNotification() {
        guard let endDate = engine.expectedEndDate else { return }
        let minutes = engine.plannedMinutes
        Task {
            await notifications.refreshAuthorization()
            await notifications.scheduleCompletion(at: endDate, plannedMinutes: minutes)
        }
    }

    private func startTicking() {
        stopTicking()
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
            }
        }
        // 기본 런루프 모드로는 스크롤·페이지 전환 중에 타이머가 멈춘다.
        // 통계 화면을 스크롤하다 돌아왔을 때 숫자가 굳어 있으면 안 되므로 common 모드에 넣는다.
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer
    }

    private func stopTicking() {
        ticker?.invalidate()
        ticker = nil
    }

    /// §12 — 실행 중에는 화면이 자동으로 꺼지지 않고, 끝나면 다시 꺼진다.
    private func setScreenAwake(_ awake: Bool) {
        UIApplication.shared.isIdleTimerDisabled = awake
    }
}
