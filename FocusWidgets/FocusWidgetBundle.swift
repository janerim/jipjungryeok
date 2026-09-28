import WidgetKit
import SwiftUI

@main
struct FocusWidgetBundle: WidgetBundle {

    var body: some Widget {
        // 잠금화면 위젯(iOS 16)과 Live Activity(iOS 16.1)는 `ios15` 브랜치에 없다.
        TodayWidget()
    }
}
