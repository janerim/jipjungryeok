import Foundation

/// §4.4 업데이트 안내를 언제 띄울지 판단한다.
///
/// 마지막으로 안내를 본 버전을 App Group 에 남기고, 지금 버전과 다를 때만 띄운다.
///
/// **처음 설치한 사람에게는 띄우지 않는다.** 방금 받은 앱에 "무엇이 바뀌었습니다" 는
/// 뜻이 없고, 첫 화면이 팝업인 앱이 된다. 그래서 저장된 값이 없으면 안내 없이
/// 현재 버전만 기록해 둔다.
enum WhatsNewStore {

    private static let key = "whatsNew.lastSeenVersion"

    static var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }

    /// 지금 띄워야 할 변경 사항. 띄울 것이 없으면 빈 배열.
    ///
    /// 호출만으로는 아무것도 기록하지 않는다 — 사용자가 실제로 보고 닫았을 때
    /// `markSeen()` 을 부른다. 그래야 안내가 뜬 순간 앱이 죽어도 다음에 다시 보인다.
    static func pendingNotes() -> [String] {
        let version = currentVersion
        guard !version.isEmpty else { return [] }

        guard let lastSeen = AppGroup.defaults.string(forKey: key) else {
            // 첫 설치. 안내 없이 기준점만 잡아 둔다.
            markSeen()
            return []
        }

        guard lastSeen != version else { return [] }
        return ReleaseNotes.notes(for: version)
    }

    static func markSeen() {
        AppGroup.defaults.set(currentVersion, forKey: key)
    }
}
