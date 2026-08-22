import WidgetKit
import SwiftUI

@main
struct FocusWidgetBundle: WidgetBundle {

    var body: some Widget {
        TodayWidget()
        AccessoryWidgets()
        FocusLiveActivity()
    }
}
