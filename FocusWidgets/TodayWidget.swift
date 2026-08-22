import WidgetKit
import SwiftUI
import FocusCore

/// §8.1 홈화면 위젯.
///
/// SwiftData 를 열지 않는다. 앱이 `reload()` 때마다 App Group 에 써 둔
/// `StatsSnapshot` 만 읽는다 (§5). 익스텐션에서 스토어를 여는 것보다 실패 위험이
/// 훨씬 낮고, 모델이 바뀌어도 위젯이 끌려다니지 않는다.
///
/// 그림은 통계 화면과 같은 것을 쓴다(`TodayRing`, `WeekStrip`). 위젯을 보고 앱을
/// 열었을 때 같은 것을 보고 있다고 느껴야 한다.
struct TodayWidget: Widget {

    /// 이 문자열은 `WidgetCenter.shared.reloadTimelines(ofKind:)` 의 키가 되므로 바꾸지 않는다.
    static let kind = "TodayWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: TodayProvider()) { entry in
            TodayWidgetView(entry: entry)
        }
        .configurationDisplayName("집중력")
        .description("오늘 집중한 시간과 이번 주를 보여줍니다.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct TodayEntry: TimelineEntry {
    let date: Date
    let snapshot: StatsSnapshot
}

struct TodayProvider: TimelineProvider {

    func placeholder(in context: Context) -> TodayEntry {
        TodayEntry(date: .now, snapshot: .zero)
    }

    func getSnapshot(in context: Context, completion: @escaping (TodayEntry) -> Void) {
        completion(TodayEntry(date: .now, snapshot: SnapshotStore.load()))
    }

    /// §8.1 — 엔트리 하나 + `.after(다음 자정)`.
    ///
    /// 위젯이 스스로 갱신해야 하는 유일한 순간이 자정이다. 그때 "오늘" 이 0 으로
    /// 바뀌고 주간 스트립의 오늘 칸이 옆으로 옮겨간다. 세션이 끝나서 생기는 갱신은
    /// 앱이 `reloadAllTimelines()` 로 밀어 준다.
    func getTimeline(in context: Context, completion: @escaping (Timeline<TodayEntry>) -> Void) {
        let now = Date()
        let entry = TodayEntry(date: now, snapshot: SnapshotStore.load())

        let calendar = Calendar.focus
        let nextMidnight = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))
            ?? now.addingTimeInterval(3600)

        completion(Timeline(entries: [entry], policy: .after(nextMidnight)))
    }
}

struct TodayWidgetView: View {

    @Environment(\.widgetFamily) private var family

    let entry: TodayEntry

    var body: some View {
        content
            .containerBackground(Palette.background, for: .widget)
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        case .systemMedium:
            medium
        default:
            small
        }
    }

    /// 작은 칸은 링 하나로 충분하다. 여기에 주간 스트립까지 넣으면 둘 다 못 읽는다.
    private var small: some View {
        TodayRing(seconds: entry.snapshot.todaySeconds, diameter: 112)
    }

    private var medium: some View {
        HStack(spacing: 18) {
            TodayRing(seconds: entry.snapshot.todaySeconds, diameter: 104)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 0) {
                    Text("이번 주")
                        .font(Typography.statCaption)
                        .foregroundStyle(Palette.inkSecondary)
                    Spacer(minLength: 8)
                    Text(TimeDisplay.hhmm(entry.snapshot.weekSeconds))
                        .font(Typography.statCaption)
                        .foregroundStyle(Palette.inkSecondary)
                        .monospacedDigit()
                }

                WeekStrip(totals: entry.weekTotals, barHeight: 44)
            }
        }
    }
}

extension TodayEntry {

    /// 스냅샷은 초 배열만 들고 온다. 날짜는 그릴 때 이번 주 월요일부터 다시 붙인다.
    ///
    /// 날짜까지 저장하지 않는 이유는, 저장 시점과 표시 시점이 자정을 사이에 두고
    /// 갈릴 수 있기 때문이다. 그 경우 날짜를 저장해 두면 "오늘" 칸이 어제에 남는다.
    var weekTotals: [DailyTotal] {
        let calendar = Calendar.focus
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: date)?.start
            ?? calendar.startOfDay(for: date)

        return snapshot.weekdaySeconds.enumerated().map { offset, seconds in
            DailyTotal(
                date: calendar.date(byAdding: .day, value: offset, to: weekStart) ?? weekStart,
                seconds: seconds
            )
        }
    }
}
