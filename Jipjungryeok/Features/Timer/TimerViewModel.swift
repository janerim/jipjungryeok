import Foundation
import Observation
import UIKit
import FocusCore

/// 타이머 화면의 상태 보유자.
///
/// 시간 계산은 전부 `FocusCore.TimerEngine` 이 한다. 여기가 맡는 것은 순수 로직이
/// 건드릴 수 없는 것들뿐이다 — 1초 화면 갱신, 햅틱, 화면 자동 잠금.
@MainActor
@Observable
final class TimerViewModel {

    private(set) var engine = TimerEngine()

    /// 화면 갱신 기준 시각. 1초마다 그리고 포그라운드 복귀 때 갱신된다.
    private(set) var now: Date = .now

    /// 방금 끝난 세션. M2 에서 SessionStore 가 여기서 받아 저장한다.
    /// 지금은 저장 경로가 없어 마지막 1건만 들고 있다.
    private(set) var lastFinished: SessionRecord?

    @ObservationIgnored private var ticker: Timer?

    // MARK: - 화면이 읽는 값

    var phase: TimerPhase { engine.phase }

    var remainingSeconds: Int { engine.remainingSeconds(at: now) }

    var countdownText: String { TimeDisplay.countdown(remainingSeconds) }

    var dialFraction: Double { engine.dialFraction(at: now) }

    // MARK: - 다이얼 입력 (§4.1)

    /// 드래그로 시간이 바뀌었다. 1분 스냅 단위로 들어온다.
    func dialDragged(toMinutes minutes: Int) {
        let previousMinutes = engine.plannedMinutes
        let wasIdle = engine.phase == .idle

        // 진행 중/일시정지 상태였다면 여기서 기존 세션이 정리된다 (§4.1, §6-4)
        if let finished = engine.setPlannedMinutes(minutes, at: .now) {
            lastFinished = finished
        }

        if !wasIdle {
            stopTicking()
            setScreenAwake(false)
        }

        if engine.plannedMinutes != previousMinutes {
            Haptics.selection()
        }
        refresh()
    }

    /// §4.1 — idle 에서 손을 떼면 즉시 카운트다운이 시작된다.
    func dialDragEnded() {
        guard engine.phase == .idle else { return }
        start()
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
            lastFinished = finished
        }
        Haptics.warning()
        stopTicking()
        setScreenAwake(false)
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
        refresh()
    }

    func pause() {
        engine.pause(at: .now)
        // 멈춰 있는 동안은 1초마다 다시 그릴 이유가 없다
        stopTicking()
        setScreenAwake(false)
        refresh()
    }

    func resume() {
        engine.resume(at: .now)
        startTicking()
        setScreenAwake(true)
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
        lastFinished = record
        stopTicking()
        setScreenAwake(false)

        // §6-3 — 알림음 없이 햅틱만
        Haptics.success()

        // M2: SessionStore 에 저장
        // M4: 캘린더 이벤트 생성
        // M5: 통계 스냅샷 갱신 + 위젯 리로드 + Live Activity 종료
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
