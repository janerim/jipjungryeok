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

    /// §6-7 시트를 띄워 둔 채 계속 일한 시간을 세션에 더할지.
    /// 참이면 제목이 1초마다 갱신되어 **저장하면 기록될 값**을 그대로 보여준다.
    /// 이 표시가 없으면 "25분 완료" 라고 쓰여 있는데 40분이 저장되는 일이 생긴다.
    let canExtend: Bool

    let onSubmit: (String?) -> Void

    @State private var memo = ""
    @FocusState private var isFieldFocused: Bool
    @Environment(\.dismiss) private var dismiss

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

                // `main` 은 여러 줄로 늘어나는 칸(`axis: .vertical`, iOS 16)이다. iOS 15 에는
                // 한 줄 칸뿐이라 긴 메모는 옆으로 흐른다. `TextEditor` 로 여러 줄을 받을 수는
                // 있지만, iOS 15 에서는 배경이 흰색으로 고정돼 테마·다크모드가 깨지고
                // 엔터가 저장이 아니라 줄바꿈이 된다.
                TextField(kind.placeholder, text: $memo)
                    // 시트 제목과 같은 크기. 여기가 제목보다 크면 한 줄짜리 메모를
                    // 받는 칸이 화면의 주인공처럼 보인다.
                    .font(Typography.sheetTitle)
                    .foregroundStyle(Palette.ink)
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
            }
            .padding(.horizontal, 24)
            .padding(.top, 28)
            .padding(.bottom, 24)
            // iOS 15 에는 시트 높이 조절(`presentationDetents`, iOS 16)이 없어서 전체 높이로
            // 뜬다. 위로 붙이지 않으면 내용이 화면 한가운데 떠 있다.
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .onAppear { isFieldFocused = true }
    }

    @ViewBuilder
    private var header: some View {
        if canExtend {
            // 1초마다 다시 그린다. 저장 버튼을 누르는 순간의 값과 화면의 값이 같아야 한다.
            TimelineView(.periodic(from: .now, by: 1)) { context in
                headerBody(
                    title: "\(TimeDisplay.minutes(elapsedSeconds(at: context.date)))분 집중 중",
                    caption: "저장을 누르면 여기까지 기록됩니다"
                )
            }
        } else {
            headerBody(
                title: kind.title(minutes: TimeDisplay.minutes(session.actualSeconds)),
                caption: subtitle
            )
        }
    }

    /// 무엇을 묻는지는 세션 하나로 정해진다 (§6-4).
    private var kind: MemoPromptKind {
        MemoPromptKind(record: session)
    }

    private func headerBody(title: String, caption: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Circle()
                    .fill(Palette.accent)
                    .frame(width: 8, height: 8)
                Text(title)
                    .font(Typography.sheetTitle)
                    .foregroundStyle(Palette.ink)
                    .monospacedDigit()
            }
            Text(caption)
                .font(Typography.statCaption)
                .foregroundStyle(Palette.inkSecondary)
        }
    }

    private func elapsedSeconds(at now: Date) -> Int {
        SessionExtension.extendedActualSeconds(original: session, savedAt: now)
    }

    /// 백그라운드에서 끝나 나중에 묻는 경우가 있으므로 언제 끝난 세션인지 밝힌다.
    ///
    /// 중지한 세션에서는 대신 **기록이 남는다는 사실**을 말한다. 여기까지 온 사람은
    /// 방금 하던 일을 접은 참이라, 알고 싶은 것은 언제 끝났는지가 아니라
    /// "이렇게 그만둬도 남나" 다. 사유를 비워 두고 닫아도 남는다는 것을 밝혀 둔다 —
    /// 안 그러면 적을 말이 없을 때 시트를 닫는 것 자체를 망설인다.
    private var subtitle: String {
        switch kind {
        case .completed:
            "\(TimeDisplay.monthDay(session.startAt)) \(TimeDisplay.clockTime(session.endAt)) 종료"
        case .stopped:
            "비워 두고 닫아도 기록은 남습니다"
        }
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
        .pressable()
        .accessibilityLabel(kind == .stopped ? "사유 없이 닫기" : "메모 없이 닫기")
    }

    private var buttons: some View {
        Button("저장") { onSubmit(memo) }
            .font(Typography.sheetTitle)
            .filledButton()
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
        canExtend: true,
        onSubmit: { _ in }
    )
}
