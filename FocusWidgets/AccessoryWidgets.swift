import WidgetKit
import SwiftUI
import FocusCore

/// §8.2 잠금화면 위젯.
///
/// 홈 위젯과 같은 `StatsSnapshot` 을 읽고 같은 타임라인 정책을 쓴다.
/// `TodayProvider` 를 그대로 재사용하는 이유는, 두 위젯이 자정에 서로 다른 시각에
/// 갱신되면 잠금화면과 홈화면의 "오늘" 이 한동안 달라 보이기 때문이다.
///
/// **잠금화면은 색을 우리가 정하지 않는다.** 시스템이 벽지 위에서 읽히도록
/// 단색으로 렌더링하고(`.widgetAccentable` 등), 여기서 팔레트 색을 지정하면
/// 벽지에 따라 안 보이는 경우가 생긴다. 그래서 이 파일만 `Palette` 를 쓰지 않는다.
struct AccessoryWidgets: Widget {

    static let kind = "FocusAccessoryWidgets"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: TodayProvider()) { entry in
            AccessoryWidgetView(entry: entry)
        }
        .configurationDisplayName("집중력")
        .description("오늘 집중한 시간을 잠금화면에서 봅니다.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular])
    }
}

struct AccessoryWidgetView: View {

    @Environment(\.widgetFamily) private var family

    let entry: TodayEntry

    var body: some View {
        content
            .containerBackground(for: .widget) { Color.clear }
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        case .accessoryRectangular:
            rectangular
        default:
            circular
        }
    }

    /// 기준값 없이 시간 숫자 + 링 (§8.2).
    ///
    /// 링은 앱의 5시간 기준을 그대로 쓴다. 잠금화면만 다른 기준으로 차오르면
    /// 앱을 열었을 때 "왜 다르지" 가 된다.
    private var circular: some View {
        Gauge(value: StatsSummary.fillFraction(forSeconds: entry.snapshot.todaySeconds)) {
            Text("집중")
        } currentValueLabel: {
            Text(TimeDisplay.hhmm(entry.snapshot.todaySeconds))
                .monospacedDigit()
        }
        .gaugeStyle(.accessoryCircularCapacity)
    }

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("🎯 집중")
                .font(.headline)

            Text("오늘 \(TimeDisplay.hhmm(entry.snapshot.todaySeconds)) · 이번 주 \(TimeDisplay.hhmm(entry.snapshot.weekSeconds))")
                .font(.caption)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
