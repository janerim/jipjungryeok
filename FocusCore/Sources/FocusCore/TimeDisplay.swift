import Foundation

/// 시간 문자열 표기. 앱·위젯(·나중에 워치)이 같은 규칙을 써야 하므로 여기 한 곳에만 둔다.
public enum TimeDisplay {

    /// §4.1 타이머 하단 큰 숫자.
    ///
    /// 60초 이상이면 분 단위 정수(올림), 60초 미만이면 `MM:SS`.
    /// 올림이므로 25분 세션은 시작 후 60초 동안 `25` 로 보이다가 `24` 로 넘어간다.
    /// 단위(`분`)는 붙이지 않는다 — 화면 쪽에서 필요하면 덧붙인다.
    public static func countdown(_ seconds: Int) -> String {
        let value = max(0, seconds)
        if value >= 60 {
            let minutes = Int((Double(value) / 60).rounded(.up))
            return "\(minutes)"
        }
        return String(format: "%02d:%02d", value / 60, value % 60)
    }

    /// §4.2 통계 표기. 35분 → `00:35`, 3시간 5분 → `03:05`
    public static func hhmm(_ seconds: Int) -> String {
        let value = max(0, seconds)
        return String(format: "%02d:%02d", value / 3600, (value % 3600) / 60)
    }
}
