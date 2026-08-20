import SwiftUI
import FocusCore

/// §4.0 — 시스템 페이지 점 대신 직접 그리는 미니멀 인디케이터.
struct PageIndicator: View {

    let pageCount: Int
    let currentIndex: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<pageCount, id: \.self) { index in
                Capsule()
                    .fill(index == currentIndex ? Palette.ink : Palette.inkSecondary)
                    .opacity(index == currentIndex ? 1 : 0.35)
                    .frame(
                        width: index == currentIndex ? 18 : 8,
                        height: Metrics.pageIndicatorHeight
                    )
            }
        }
        .animation(.easeInOut(duration: 0.2), value: currentIndex)
    }
}

#Preview {
    ZStack {
        Palette.background.ignoresSafeArea()
        PageIndicator(pageCount: 3, currentIndex: 1)
    }
}
