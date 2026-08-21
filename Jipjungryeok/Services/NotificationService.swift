import Foundation
import Observation
import UserNotifications
import FocusCore

/// §6-5 종료 로컬 알림.
///
/// **알림음을 쓰지 않는다** (§6-3). 앱을 켜둔 채 쓰는 전제라 포그라운드에서는 햅틱만
/// 울리고, 백그라운드에서는 무음 배너만 뜬다.
@MainActor
@Observable
final class NotificationService {

    /// 예약된 종료 알림은 언제나 한 개뿐이다. 같은 식별자로 덮어쓰면 재예약이 된다.
    private static let completionIdentifier = "focus.session.completion"

    /// §4.3 설정 화면의 안내 배너가 읽는 값 (M4 에서 연결).
    private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined

    @ObservationIgnored private let center = UNUserNotificationCenter.current()

    /// `UNUserNotificationCenter.delegate` 는 weak 참조라 여기서 붙잡고 있어야 한다.
    @ObservationIgnored private let presentationBlocker = ForegroundPresentationBlocker()

    init() {
        // 포그라운드 배너를 막으려면 델리게이트가 알림 도착 전에 붙어 있어야 한다.
        center.delegate = presentationBlocker
    }

    // MARK: - 권한

    /// 아직 물어본 적 없으면 물어본다. 이미 허용/거부된 상태면 조회만 한다.
    ///
    /// 앱 시작이 아니라 **첫 세션을 시작할 때** 불린다. 타이머를 맞춘 직후가
    /// "끝나면 알려드릴까요" 를 묻기 가장 자연스러운 지점이다.
    func refreshAuthorization() async {
        let settings = await center.notificationSettings()

        guard settings.authorizationStatus == .notDetermined else {
            authorizationStatus = settings.authorizationStatus
            return
        }

        // 소리는 쓰지 않으므로 권한도 요청하지 않는다 (§6-3).
        let granted = (try? await center.requestAuthorization(options: [.alert])) ?? false
        authorizationStatus = granted ? .authorized : .denied
    }

    // MARK: - 예약 / 취소

    /// 종료 예정 시각에 무음 알림을 예약한다.
    ///
    /// 권한이 없으면 조용히 실패한다. 알림이 안 뜰 뿐 타이머는 정상 동작하므로
    /// 사용자에게 모달을 띄우지 않는다.
    func scheduleCompletion(at endDate: Date, plannedMinutes: Int) async {
        cancelPending()

        let interval = endDate.timeIntervalSinceNow
        // UNTimeIntervalNotificationTrigger 는 0 이하를 받으면 예외를 던진다.
        // 이미 지난 시각이면 어차피 완료 처리가 먼저 돈다.
        guard interval > 0 else { return }

        let content = UNMutableNotificationContent()
        content.title = "🎯 집중 완료"
        content.body = "\(plannedMinutes)분 집중을 마쳤습니다."
        content.sound = nil   // §6-3 — 무음

        let request = UNNotificationRequest(
            identifier: Self.completionIdentifier,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        )
        try? await center.add(request)
    }

    /// §6-5 — 일시정지·중지·완료 시 반드시 취소한다.
    /// 안 하면 이미 끝낸 세션의 알림이 나중에 혼자 뜬다.
    func cancelPending() {
        center.removePendingNotificationRequests(withIdentifiers: [Self.completionIdentifier])
    }
}

/// 포그라운드에서 알림 배너가 뜨는 것을 막는다 (§6-3).
///
/// `NotificationService` 에 직접 델리게이트를 구현하지 않고 따로 뺀 이유는
/// `@Observable` 과 `NSObject` 상속을 한 타입에 겹치지 않기 위해서다.
private final class ForegroundPresentationBlocker: NSObject, UNUserNotificationCenterDelegate {

    /// 이 콜백은 앱이 **포그라운드일 때만** 불린다.
    /// 그 경우 이미 완료 햅틱이 울렸으므로 배너를 또 띄우지 않는다.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        []
    }
}
