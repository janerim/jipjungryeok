import SwiftUI
import FocusCore

/// M0 확인용 임시 루트 화면.
///
/// M1 에서 §4.0 의 `TabView(selection:) + .tabViewStyle(.page)` 구조
/// (통계 ↔ 타이머 ↔ 설정)로 교체된다.
///
/// 지금 이 화면의 목적은 하나다: 6개 디자인 토큰이 라이트/다크에서 각각
/// 제대로 해석되는지 눈으로 확인하는 것 (M0 완료 조건).
struct RootView: View {

    private let tokens: [(name: String, color: Color)] = [
        ("background", Palette.background),
        ("ink", Palette.ink),
        ("inkSecondary", Palette.inkSecondary),
        ("stroke", Palette.stroke),
        ("handle", Palette.handle),
        ("accent", Palette.accent)
    ]

    var body: some View {
        ZStack {
            Palette.background
                .ignoresSafeArea()

            VStack(spacing: 24) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Palette.accent)
                        .frame(width: 8, height: 8)
                    Text("🎯 집중")
                        .font(Typography.statusLabel)
                        .foregroundStyle(Palette.ink)
                }

                Text("M0 · 프로젝트 골격")
                    .font(Typography.statCaption)
                    .foregroundStyle(Palette.inkSecondary)

                VStack(spacing: 0) {
                    ForEach(Array(tokens.enumerated()), id: \.offset) { index, token in
                        if index > 0 {
                            Divider().overlay(Palette.stroke)
                        }
                        HStack {
                            Text(token.name)
                                .font(Typography.statCaption)
                                .foregroundStyle(Palette.inkSecondary)
                            Spacer()
                            RoundedRectangle(cornerRadius: 4)
                                .fill(token.color)
                                .frame(width: 44, height: 22)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(Palette.stroke, lineWidth: Metrics.cardStrokeWidth)
                                )
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: Metrics.cardCornerRadius)
                        .stroke(Palette.stroke, lineWidth: Metrics.cardStrokeWidth)
                )
                .padding(.horizontal, 32)

                Text("00:00")
                    .font(Typography.countdown)
                    .foregroundStyle(Palette.ink)
            }
        }
    }
}

#Preview("라이트") {
    RootView()
        .preferredColorScheme(.light)
}

#Preview("다크") {
    RootView()
        .preferredColorScheme(.dark)
}
