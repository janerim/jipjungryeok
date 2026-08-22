import SwiftUI
import FocusCore

/// §4.2 세션 한 줄. 통계 화면의 최근 목록과 기록 시트가 함께 쓴다.
///
/// 두 곳이 같은 모양이어야 "전체" 로 들어갔을 때 목록이 이어지는 느낌이 난다.
/// 서로 다르게 그리면 같은 세션인지 알아보는 데 한 박자가 든다.
struct SessionRow: View {

    let session: SessionRecord

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            // 시각을 고정폭 열로 세워야 하루치가 시간축처럼 읽힌다.
            Text(TimeDisplay.clockTime(session.startAt))
                .font(Typography.statCaption)
                .foregroundStyle(Palette.inkSecondary)
                .monospacedDigit()
                .frame(width: 44, alignment: .leading)

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(TimeDisplay.minutes(session.actualSeconds))분")
                        // 목록에서 이 숫자가 크면 메모보다 시간이 주인공처럼 보인다.
                        // 기록 화면의 목적은 "그때 뭘 했더라" 이지 "몇 분 했나" 가 아니다.
                        .font(Typography.sheetTitle)
                        .foregroundStyle(Palette.ink)
                        .monospacedDigit()

                    // 계획을 못 채운 세션. 시각만 봐서는 드러나지 않는다 (§7 과 같은 표기).
                    if !session.isCompleted {
                        Text("중단")
                            .font(Typography.statCaption)
                            .foregroundStyle(Palette.inkSecondary)
                    }
                }

                if let memo = session.memo, !memo.isEmpty {
                    Text(memo)
                        .font(Typography.statCaption)
                        .foregroundStyle(Palette.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 0)
        }
    }
}
