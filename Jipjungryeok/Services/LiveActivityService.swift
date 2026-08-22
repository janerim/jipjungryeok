import ActivityKit
import Foundation
import FocusCore

/// §8.3 실행 중 세션을 잠금화면·Dynamic Island 에 띄운다.
///
/// 이 앱의 무음 정책(§6-3) 때문에 백그라운드에서 남는 단서가 배너 하나뿐인데,
/// Live Activity 가 있으면 잠금화면만 켜도 남은 시간이 보인다.
///
/// **실패해도 조용히 넘어간다.** 사용자가 시스템 설정에서 실시간 현황을 껐거나
/// 예산이 다 찼을 수 있다. 그건 타이머의 문제가 아니다 — 여기서 던지거나 모달을
/// 띄우면 멀쩡한 세션이 방해받는다.
@MainActor
final class LiveActivityService {

    private var activity: Activity<FocusActivityAttributes>?

    /// 시스템 설정에서 껐으면 시작 자체를 시도하지 않는다.
    private var isAvailable: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    // MARK: -

    func start(plannedMinutes: Int, startDate: Date, endDate: Date) {
        guard isAvailable else { return }

        // 앱이 강제 종료됐다 살아나면 지난 세션의 Activity 가 떠 있을 수 있다.
        // 새로 만들기 전에 남은 것을 정리하지 않으면 잠금화면에 두 개가 겹친다.
        endAll()

        let state = FocusActivityAttributes.ContentState(
            endDate: endDate,
            startDate: startDate,
            pausedRemainingSeconds: nil
        )

        activity = try? Activity.request(
            attributes: FocusActivityAttributes(plannedMinutes: plannedMinutes),
            content: ActivityContent(state: state, staleDate: endDate),
            pushType: nil
        )
    }

    /// 일시정지·재개로 종료 시각이 바뀌었을 때.
    func update(startDate: Date, endDate: Date, pausedRemainingSeconds: Int?) {
        guard let activity else { return }

        let state = FocusActivityAttributes.ContentState(
            endDate: endDate,
            startDate: startDate,
            pausedRemainingSeconds: pausedRemainingSeconds
        )

        Task {
            await activity.update(ActivityContent(state: state, staleDate: endDate))
        }
    }

    /// 완료·중지 시. 잠금화면에 남아 있으면 끝난 세션이 계속 도는 것처럼 보인다.
    func end() {
        let running = activity
        activity = nil

        Task {
            await running?.end(nil, dismissalPolicy: .immediate)
            // 참조를 잃은 Activity 가 남아 있을 수 있다(앱 재실행 등).
            await endOrphans()
        }
    }

    // MARK: -

    private func endAll() {
        activity = nil
        Task { await endOrphans() }
    }

    private func endOrphans() async {
        for activity in Activity<FocusActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
}
