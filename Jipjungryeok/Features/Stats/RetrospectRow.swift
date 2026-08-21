import SwiftUI
import FocusCore

/// §4.2-2 회고 — 최근 완료 세션 3건, 가로 3분할.
///
/// 각 칸은 위에서부터 날짜(`M월 d일`) / 집중 분 / 종료 시각(`HH:mm`).
/// 3건이 안 되면 빈 칸을 그린다 (§12 — 세션 0건이어도 크래시 없이 그려져야 한다).
struct RetrospectRow: View {

    let sessions: [SessionRecord]

    var body: some View {
        HStack(spacing: 10) {
            ForEach(0..<SessionStore.retrospectLimit, id: \.self) { index in
                if index < sessions.count {
                    RetrospectCell(session: sessions[index])
                } else {
                    RetrospectCell(session: nil)
                }
            }
        }
    }
}

private struct RetrospectCell: View {

    /// `nil` 이면 아직 채워지지 않은 칸
    let session: SessionRecord?

    var body: some View {
        VStack(spacing: 4) {
            Text(session.map { TimeDisplay.monthDay($0.startAt) } ?? "—")
                .font(Typography.statCaption)
                .foregroundStyle(Palette.inkSecondary)

            Text(session.map { "\(TimeDisplay.minutes($0.actualSeconds))" } ?? "—")
                .font(Typography.statValue)
                .foregroundStyle(Palette.ink)
                .monospacedDigit()

            Text(session.map { TimeDisplay.clockTime($0.endAt) } ?? "—")
                .font(Typography.statCaption)
                .foregroundStyle(Palette.inkSecondary)
                .monospacedDigit()

            // 메모가 있으면 무엇을 했는지 보여준다. 이게 있어야 "회고" 가 된다.
            // 메모가 없어도 자리는 남긴다 — HStack 안에서 카드 높이가 들쭉날쭉하면
            // 세 칸이 어긋나 보인다.
            Text(session?.memo ?? " ")
                .font(Typography.statCaption)
                .foregroundStyle(Palette.ink)
                .lineLimit(1)
                .truncationMode(.tail)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .opacity(session == nil ? 0.45 : 1)
        .overlay(
            RoundedRectangle(cornerRadius: Metrics.cardCornerRadius)
                .stroke(Palette.stroke, lineWidth: Metrics.cardStrokeWidth)
        )
    }
}

#Preview("빈 상태") {
    ZStack {
        Palette.background.ignoresSafeArea()
        RetrospectRow(sessions: [])
            .padding(20)
    }
}
