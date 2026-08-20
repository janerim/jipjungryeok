import SwiftUI
import FocusCore

/// 아직 구현되지 않은 페이지 자리. M2·M4 에서 실제 화면으로 교체된다.
struct PlaceholderPage: View {

    let title: String
    let milestone: String

    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(Typography.statusLabel)
                .foregroundStyle(Palette.ink)
            Text(milestone)
                .font(Typography.statCaption)
                .foregroundStyle(Palette.inkSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
