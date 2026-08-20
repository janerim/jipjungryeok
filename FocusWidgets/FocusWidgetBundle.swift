import WidgetKit
import SwiftUI

@main
struct FocusWidgetBundle: WidgetBundle {

    var body: some Widget {
        TodayWidget()
        // M5 에서 추가: AccessoryWidgets (§8.2), FocusLiveActivity (§8.3)
    }
}
