import SwiftUI
import FocusCore

/// §4.2-3 이미 저장된 세션의 메모를 고치는 시트.
///
/// 회고(§6-6)는 세션이 끝난 직후 한 번 뜨고 사라진다. 그 순간에 제대로 못 적는 일이
/// 많다 — 회의에 불려 가는 중이었거나, 무엇을 했는지가 한참 뒤에 정리되거나.
/// 고칠 길이 없으면 그 메모는 틀린 채로 영영 남고, 그러면 기록 화면을 열 이유가 준다.
///
/// 회고 시트와 같은 얼개를 쓴다 — 제목, 오른쪽 위 X, 아래 버튼 하나.
/// 다른 점은 둘뿐이다. 처음부터 지금 메모가 들어 있고, 나가는 문이 "저장 안 함" 이다.
struct MemoEditSheet: View {

    let session: SessionRecord
    let onSave: (String?) -> Void

    @State private var memo: String
    @FocusState private var isFieldFocused: Bool
    @Environment(\.dismiss) private var dismiss

    init(session: SessionRecord, onSave: @escaping (String?) -> Void) {
        self.session = session
        self.onSave = onSave
        _memo = State(initialValue: session.memo ?? "")
    }

    var body: some View {
        ZStack {
            Palette.background
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    header
                    Spacer(minLength: 12)
                    closeButton
                }

                // 한 줄 칸인 이유는 `MemoSheet` 와 같다 (iOS 15).
                TextField(kind.placeholder, text: $memo)
                    .font(Typography.sheetTitle)
                    .foregroundStyle(Palette.ink)
                    .focused($isFieldFocused)
                    .submitLabel(.done)
                    .onSubmit(save)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .overlay(
                        RoundedRectangle(cornerRadius: Metrics.cardCornerRadius)
                            .stroke(Palette.stroke, lineWidth: Metrics.cardStrokeWidth)
                    )

                Button("저장", action: save)
                    .font(Typography.sheetTitle)
                    .filledButton()
            }
            .padding(.horizontal, 24)
            .padding(.top, 28)
            .padding(.bottom, 24)
            // 전체 높이 시트라 위로 붙인다 — `MemoSheet` 참고.
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .onAppear { isFieldFocused = true }
    }

    /// 어느 세션을 고치고 있는지 밝힌다. 목록에서 눌러 들어오므로 시각과 길이가
    /// 맞아야 엉뚱한 줄을 고치고 있지 않다는 것을 알 수 있다.
    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Circle()
                    .fill(Palette.accent)
                    .frame(width: 8, height: 8)
                Text(kind.title(minutes: TimeDisplay.minutes(session.actualSeconds)))
                    .font(Typography.sheetTitle)
                    .foregroundStyle(Palette.ink)
                    .monospacedDigit()
            }
            Text(subtitle)
                .font(Typography.statCaption)
                .foregroundStyle(Palette.inkSecondary)
        }
    }

    private var subtitle: String {
        "\(TimeDisplay.monthDay(session.startAt)) \(TimeDisplay.clockTime(session.startAt)) 시작"
    }

    /// 완료된 세션과 중지한 세션은 묻는 말이 다르다 (§6-4).
    /// 회고 시트와 같은 곳에서 가져와야 한쪽만 바뀌는 일이 없다.
    private var kind: MemoPromptKind {
        MemoPromptKind(record: session)
    }

    /// **X 는 저장하지 않고 나가는 문이다.** 회고 시트에서는 닫기가 "메모 없이 확정"
    /// 이었지만 여기서 같은 뜻으로 두면, 읽어 보려고 열었다가 닫는 것만으로 메모가
    /// 지워진다. 고치는 화면에서 닫기는 언제나 취소여야 한다.
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
        .padding(.trailing, -12)
        .padding(.top, -12)
        .pressable()
        .accessibilityLabel("저장하지 않고 닫기")
    }

    /// 빈 칸으로 저장하면 메모를 **지운다**. 잘못 적은 것을 비웠는데 옛 값이 그대로면
    /// 지울 방법이 아예 없다. 정규화(`normalizedMemo`)는 받는 쪽이 한다.
    private func save() {
        onSave(memo)
        dismiss()
    }
}

#Preview {
    let t0 = Date()
    return MemoEditSheet(
        session: SessionRecord(
            id: UUID(),
            startAt: t0.addingTimeInterval(-1500),
            endAt: t0,
            plannedSeconds: 1500,
            actualSeconds: 1500,
            isCompleted: true,
            memo: "기획서 §7 다시 읽기"
        ),
        onSave: { _ in }
    )
}
