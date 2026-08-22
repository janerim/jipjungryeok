import SwiftUI
import FocusCore

/// 세션이 끝난 직후 한 줄 메모를 받는 시트.
///
/// 이 앱에서 유일하게 사용자를 멈춰 세우는 화면이라 최소한으로 만든다.
/// 버튼은 "저장" 하나뿐이고, 나가는 길은 오른쪽 위 X 또는 시트를 아래로 내리는 것이다.
/// 둘 다 메모 없이 마무리되며 캘린더 기록은 그대로 남는다.
/// 여기서 막히면 §6-3 이 공들여 만든 "완료는 조용히" 가 무너진다.
struct MemoSheet: View {

    let session: SessionRecord
    let onSubmit: (String?) -> Void

    @State private var memo = ""
    @FocusState private var isFieldFocused: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Palette.background
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .top) {
                    header
                    Spacer(minLength: 12)
                    closeButton
                }

                // 한 줄만 보이면 길게 쓸 생각이 안 든다. 처음부터 여러 줄 높이를
                // 잡아두고, 늘어나도 시트가 밀리지 않을 만큼만 허용한다.
                TextField("무엇을 했나요?", text: $memo, axis: .vertical)
                    .font(Typography.statValue)
                    .foregroundStyle(Palette.ink)
                    .lineLimit(4...8)
                    .focused($isFieldFocused)
                    .submitLabel(.done)
                    .onSubmit { onSubmit(memo) }
                    .frame(minHeight: 180, alignment: .topLeading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .overlay(
                        RoundedRectangle(cornerRadius: Metrics.cardCornerRadius)
                            .stroke(Palette.stroke, lineWidth: Metrics.cardStrokeWidth)
                    )

                Spacer(minLength: 0)

                buttons
            }
            .padding(.horizontal, 24)
            .padding(.top, 28)
            .padding(.bottom, 24)
        }
        .presentationDetents([.height(460)])
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
                    .font(Typography.sheetTitle)
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

    /// 닫기 = 건너뛰기. 시트를 내리면 `RootView` 의 바인딩이 메모 없이 마무리하므로
    /// 여기서는 `dismiss()` 만 하면 된다. 별도의 "건너뛰기" 버튼을 두지 않는 이유는
    /// §6-3 — 이 시트는 사용자를 붙잡는 곳이 아니라 빠져나가기 쉬워야 하고,
    /// 버튼이 둘이면 그 자체가 한 번의 결정이 된다.
    private var closeButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Palette.inkSecondary)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        // 44pt 히트 영역을 유지하면서 시각적으로는 헤더 오른쪽 끝에 맞춘다.
        .padding(.trailing, -12)
        .padding(.top, -12)
        .accessibilityLabel("메모 없이 닫기")
    }

    private var buttons: some View {
        Button("저장") { onSubmit(memo) }
            .font(Typography.statValue)
            .foregroundStyle(Palette.background)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: Metrics.cardCornerRadius)
                    .fill(Palette.ink)
            )
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
