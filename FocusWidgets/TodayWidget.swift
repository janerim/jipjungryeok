import WidgetKit
import SwiftUI
import FocusCore

/// §8.1 홈화면 위젯.
///
/// M0 에서는 뼈대만 세운다. 목적은 두 가지다:
///  1. App Groups Capability 가 앱·위젯 **양쪽**에 붙은 상태로 시작하기 (§13-1)
///  2. `Shared/Colors.xcassets` 가 익스텐션 번들에서도 해석되는지 확인하기 (§13-4)
///
/// M5 에서 §5 의 `StatsSnapshot` 을 App Group UserDefaults 에서 읽어
/// 오늘 집중 시간과 최근 7일 미니 막대 차트를 채운다.
struct TodayWidget: Widget {

    /// 이 문자열은 `WidgetCenter.shared.reloadTimelines(ofKind:)` 의 키가 되므로 바꾸지 않는다.
    static let kind = "TodayWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: TodayProvider()) { entry in
            TodayWidgetView(entry: entry)
        }
        .configurationDisplayName("집중력")
        .description("오늘 집중한 시간을 보여줍니다.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct TodayEntry: TimelineEntry {
    let date: Date
    /// 오늘 집중한 초. M5 에서 `StatsSnapshot.todaySeconds` 로 채운다.
    let todaySeconds: Int
}

struct TodayProvider: TimelineProvider {

    func placeholder(in context: Context) -> TodayEntry {
        TodayEntry(date: .now, todaySeconds: 0)
    }

    func getSnapshot(in context: Context, completion: @escaping (TodayEntry) -> Void) {
        completion(TodayEntry(date: .now, todaySeconds: 0))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodayEntry>) -> Void) {
        // M5: `.after(다음 자정)` 엔트리 1개 + 세션 완료 시 reloadAllTimelines() (§8.1)
        completion(Timeline(entries: [TodayEntry(date: .now, todaySeconds: 0)], policy: .never))
    }
}

struct TodayWidgetView: View {

    let entry: TodayEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("🎯 집중")
                .font(Typography.statCaption)
                .foregroundStyle(Palette.inkSecondary)

            Text(hhmm(entry.todaySeconds))
                .font(Typography.statValue)
                .foregroundStyle(Palette.ink)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(Palette.background, for: .widget)
    }

    /// §4.2 표기 규칙: 35분 → `00:35`, 3시간 5분 → `03:05`
    /// M2 에서 FocusCore 의 공용 포매터로 옮긴다.
    private func hhmm(_ seconds: Int) -> String {
        String(format: "%02d:%02d", seconds / 3600, (seconds % 3600) / 60)
    }
}
