import Foundation

/// 시간 문자열 표기. 앱·위젯(·나중에 워치)이 같은 규칙을 써야 하므로 여기 한 곳에만 둔다.
///
/// 날짜 표기는 `DateFormatter` 대신 `Calendar` 로 구성 요소를 뽑아 직접 조립한다.
/// 포맷 문자열은 기기 지역 설정에 따라 결과가 달라져서 단위 테스트로 못박기 어렵다.
public enum TimeDisplay {

    // MARK: - 길이

    /// §4.1 실행 중 남은 시간. 항상 `M:SS` 로 **매초 움직인다**.
    ///
    /// 예전에는 1분 이상일 때 올림한 분만 보여줬다(25분 세션이 60초 동안 `25`).
    /// 화면의 주인공 숫자가 1분씩 멈춰 있으니 타이머가 고장난 것처럼 보였다 —
    /// 실제로 그렇게 신고가 들어왔다. 부채꼴은 계속 줄어드는데 숫자만 굳어 있었다.
    ///
    /// 분은 0 을 채우지 않는다(`3:07`). 앞자리 0 은 큰 숫자에서 눈에 거슬리고,
    /// 자릿수가 흔들리는 것은 `monospacedDigit()` 이 잡아 준다.
    public static func countdown(_ seconds: Int) -> String {
        let value = max(0, seconds)
        return String(format: "%d:%02d", value / 60, value % 60)
    }

    /// §4.2 통계 표기. 35분 → `00:35`, 3시간 5분 → `03:05`
    public static func hhmm(_ seconds: Int) -> String {
        let value = max(0, seconds)
        return String(format: "%02d:%02d", value / 3600, (value % 3600) / 60)
    }

    /// §4.2 회고의 집중 분. 반올림한 정수만 돌려준다.
    public static func minutes(_ seconds: Int) -> Int {
        Int((Double(max(0, seconds)) / 60).rounded())
    }

    /// §4.2 시간 요약의 합계. `3시간 5분`.
    /// 한 시간이 안 되면 `35분` 으로만 적는다 — `0시간 35분` 은 읽기 나쁘다.
    public static func hourMinuteText(_ seconds: Int) -> String {
        let value = max(0, seconds)
        let hours = value / 3600
        let minutes = (value % 3600) / 60
        return hours == 0 ? "\(minutes)분" : "\(hours)시간 \(minutes)분"
    }

    // MARK: - 날짜

    /// §4.2 회고 상단. `8월 20일`
    public static func monthDay(_ date: Date, calendar: Calendar = .focus) -> String {
        let parts = calendar.dateComponents([.month, .day], from: date)
        return "\(parts.month ?? 0)월 \(parts.day ?? 0)일"
    }

    /// §4.2 회고 하단 종료 시각. `14:05`
    public static func clockTime(_ date: Date, calendar: Calendar = .focus) -> String {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", parts.hour ?? 0, parts.minute ?? 0)
    }

    /// §4.2 차트 축 아래 라벨. `2026년 8월`
    /// 목록의 날짜 구분 라벨. 오늘·어제는 이름으로, 그 이전은 `M월 d일`.
    ///
    /// 날짜 없이 시각만 늘어놓으면 14:05 다음에 16:22 가 오는 것처럼 보여
    /// 순서가 틀린 줄 안다. 그렇다고 매 줄에 날짜를 박으면 대부분이 오늘이라 잡음이 된다.
    public static func relativeDay(
        _ date: Date,
        now: Date = .now,
        calendar: Calendar = .focus
    ) -> String {
        let target = calendar.startOfDay(for: date)
        let today = calendar.startOfDay(for: now)

        if target == today { return "오늘" }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: today),
           target == yesterday {
            return "어제"
        }
        return monthDay(date, calendar: calendar)
    }

    public static func yearMonth(_ date: Date, calendar: Calendar = .focus) -> String {
        let parts = calendar.dateComponents([.year, .month], from: date)
        return "\(parts.year ?? 0)년 \(parts.month ?? 0)월"
    }
}
