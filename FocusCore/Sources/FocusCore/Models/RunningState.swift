import Foundation

/// 진행 중인 세션의 상태 (§5).
///
/// 앱이 강제 종료돼도 이어서 표시할 수 있도록, M3 에서 이 값을 그대로
/// App Group `UserDefaults` 에 `Codable` 로 저장한다. 그래서 필드를 최소한으로 유지한다.
///
/// **남은 시간을 필드로 들고 있지 않는다는 점이 핵심이다.** 남은 시간은 항상
/// `startAt` 과 현재 절대시각의 차이로 다시 계산한다 (§6-1).
public struct RunningState: Codable, Equatable, Sendable {

    public var sessionID: UUID

    /// 세션 시작 절대시각
    public var startAt: Date

    /// 사용자가 다이얼로 설정한 시간
    public var plannedSeconds: Int

    /// **끝난** 일시정지 구간들의 합. 지금 일시정지 중인 시간은 여기 포함되지 않는다.
    public var accumulatedPauseSeconds: Int

    /// 일시정지가 시작된 시각. `nil` 이면 running.
    public var pausedAt: Date?

    public init(
        sessionID: UUID,
        startAt: Date,
        plannedSeconds: Int,
        accumulatedPauseSeconds: Int = 0,
        pausedAt: Date? = nil
    ) {
        self.sessionID = sessionID
        self.startAt = startAt
        self.plannedSeconds = plannedSeconds
        self.accumulatedPauseSeconds = accumulatedPauseSeconds
        self.pausedAt = pausedAt
    }
}
