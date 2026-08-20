import Foundation

public extension Calendar {

    /// §1-1 — 주는 **월요일**에 시작한다.
    ///
    /// `Calendar.current` 를 그냥 쓰면 기기 지역 설정에 따라 일요일 시작으로 바뀌어
    /// "이번 주" 집계가 사용자마다 달라진다. 그래서 `firstWeekday` 를 고정한다.
    /// 시간대는 기기 설정을 따른다 — 사용자가 보는 "오늘" 과 어긋나면 안 된다.
    static var focus: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2   // 1 = 일요일, 2 = 월요일
        return calendar
    }
}
