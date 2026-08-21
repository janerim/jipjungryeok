import SwiftUI
import FocusCore

/// 세션이 끝난 직후 한 줄 메모를 받는 시트.
///
/// 이 앱에서 유일하게 사용자를 멈춰 세우는 화면이라 최소한으로 만든다.
/// 건너뛰기가 저장과 나란히 있고, 시트를 그냥 내려도 건너뛴 것으로 처리된다.
/// 여기서 막히면 §6-3 이 공들여 만든 "완료는 조용히" 가 무너진다.
struct MemoSheet: View {

    let session: SessionRecord
    let onSubmit: (String?) -> Void

    @State private var memo = ""
    @FocusState private var isFieldFocused: Bool

    var body: some View {
        ZStack {
            Palette.background
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 20) {
                header

                TextField("무엇을 했나요?", text: $memo, axis: .vertical)
                    .font(Typography.statValue)
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1...3)
                    .focused($isFieldFocused)
                    .submitLabel(.done)
                    .onSubmit { onSubmit(memo) }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .overlay(
                        RoundedRectangle(cornerRadius: Metrics.cardCornerRadius)
                            .stroke(Palette.stroke, lineWidth: Metrics.cardStrokeWidth)
                    )

                buttons

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 24)
            .padding(.top, 28)
        }
        .presentationDetents([.height(280)])
        .presentationDragIndicator(.visible)
        .onAppear { isFieldFocused = true }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Circle()
                    .fill(Palette.accent)
                    .frame(width: 8, height: 8)
                Text("\(TimeDisplay.minutes(session.actualSeconds))분 집중 완료")
                    .font(Typography.statusLabel)
                    .foregroundStyle(Palette.ink)
            }
            Text(subtitle)
                .font(Typography.statCaption)
                .foregroundStyle(Palette.inkSecondary)
        }
    }

    /// 백그라운드에서 끝나 나중에 묻는 경우가 있으므로 언제 끝난 세션인지 밝힌다.
    private var subtitle: String {
        "\(TimeDisplay.monthDay(session.startAt)) \(TimeDisplay.clockTime(session.endAt)) 종료"
    }

    private var buttons: some View {
        HStack(spacing: 10) {
            Button("건너뛰기") { onSubmit(nil) }
                .font(Typography.statValue)
                .foregroundStyle(Palette.inkSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .overlay(
                    RoundedRectangle(cornerRadius: Metrics.cardCornerRadius)
                        .stroke(Palette.stroke, lineWidth: Metrics.cardStrokeWidth)
                )

            Button("저장") { onSubmit(memo) }
                .font(Typography.statValue)
                .foregroundStyle(Palette.background)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: Metrics.cardCornerRadius)
                        .fill(Palette.ink)
                )
        }
    }
}

#Preview {
    let t0 = Date()
    return MemoSheet(
        session: SessionRecord(
            id: UUID(),
            startAt: t0.addingTimeInterval(-1500),
            endAt: t0,
            plannedSeconds: 1500,
            actualSeconds: 1500,
            isCompleted: true
        ),
        onSubmit: { _ in }
    )
}
