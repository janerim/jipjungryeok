import Foundation

/// §4.2 기록 화면이 쓰는 하루치 묶음.
///
/// 추세 그리드가 "얼마나 했나" 에 답한다면 이쪽은 "무엇을 했나" 에 답한다.
/// 그래서 합계뿐 아니라 세션 목록을 통째로 들고 있고, 메모가 여기에 실려 온다.
public struct HistoryDay: Equatable, Identifiable, Sendable {

    /// 그 날의 자정. 묶음의 신원이자 정렬 기준이다.
    public let date: Date

    /// 그 날 세션들. 늦게 시작한 것이 먼저 온다.
    public let sessions: [SessionRecord]

    public var id: Date { date }

    public var sessionCount: Int { sessions.count }

    /// 그 날 실제로 집중한 시간의 합. 계획한 시간이 아니다.
    public var totalSeconds: Int {
        sessions.reduce(0) { $0 + $1.actualSeconds }
    }

    public init(date: Date, sessions: [SessionRecord]) {
        self.date = date
        self.sessions = sessions
    }
}

/// §4.2 세션 이력을 날짜별로 묶는다.
///
/// `StatsCalculator` 와 분리한 이유는 답하는 질문이 다르기 때문이다. 저쪽은 창(window)
/// 단위 합계를 내고, 이쪽은 개별 세션을 시간순으로 늘어놓는다. 한 타입에 넣으면
/// "합계만 필요한데 세션 배열까지 들고 오는" 상황이 생긴다.
public enum SessionHistory {

    /// 날짜별로 묶어 **최신 날짜가 먼저** 오도록 돌려준다.
    ///
    /// 날짜 판정은 §4.2 대로 `startAt` 기준이다. 23:50 에 시작해 00:15 에 끝난 세션은
    /// 전부 시작일에 들어가며 두 날로 쪼개지 않는다. 여기서 `endAt` 을 쓰면 추세 그리드·
    /// 차트와 같은 세션이 다른 날에 잡혀 화면끼리 숫자가 어긋난다.
    ///
    /// 중도 중지한 세션도 포함한다. 회고 카드(§4.2-2)는 완료된 것만 보여주지만
    /// 이력은 "그 날 무엇을 했나" 의 기록이라 중간에 접은 것도 사실의 일부다.
    public static func byDay(
        _ sessions: [SessionRecord],
        calendar: Calendar = .focus
    ) -> [HistoryDay] {
        let grouped = Dictionary(grouping: sessions) { session in
            calendar.startOfDay(for: session.startAt)
        }

        return grouped
            .map { date, sessions in
                HistoryDay(
                    date: date,
                    sessions: sessions.sorted { $0.startAt > $1.startAt }
                )
            }
            .sorted { $0.date > $1.date }
    }
}
