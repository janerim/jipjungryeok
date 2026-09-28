import SwiftUI
import FocusCore

/// §4.4 업데이트 안내.
///
/// 메모 시트와 같은 얼개를 쓴다 — 제목, 오른쪽 위 X, 아래 버튼 하나.
/// 이 앱에서 사용자를 멈춰 세우는 화면은 형태가 같아야 한다.
struct WhatsNewSheet: View {

    let version: String
    let notes: [String]
    let onClose: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Palette.background
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("새로워진 점")
                            .font(Typography.sheetTitle)
                            .foregroundStyle(Palette.ink)
                        Text("버전 \(version)")
                            .font(Typography.statCaption)
                            .foregroundStyle(Palette.inkSecondary)
                    }

                    Spacer(minLength: 12)

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
                    .accessibilityLabel("닫기")
                }

                VStack(alignment: .leading, spacing: 12) {
                    ForEach(notes, id: \.self) { note in
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            // 점 하나로 항목을 나눈다. 시스템 불릿은 팔레트를 안 따른다.
                            Circle()
                                .fill(Palette.accent)
                                .frame(width: 5, height: 5)
                            Text(note)
                                .font(Typography.sheetTitle)
                                .foregroundStyle(Palette.ink)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(.top, 2)

                Spacer(minLength: 0)

                Button("확인") { dismiss() }
                    .font(Typography.sheetTitle)
                    .filledButton()
            }
            .padding(.horizontal, 24)
            .padding(.top, 28)
            .padding(.bottom, 24)
        }
        // iOS 15 에는 시트 높이 조절(`presentationDetents`, iOS 16)이 없어 전체 높이로 뜬다.
        // 위의 `Spacer` 가 버튼을 맨 아래로 밀어 준다.
        // X 로 닫든 아래로 내리든 본 것으로 친다. 다시 띄우면 성가시다.
        .onDisappear(perform: onClose)
    }
}

#Preview {
    WhatsNewSheet(
        version: "1.1",
        notes: [
            "집중 시간이 끝난 뒤에도 계속 일했다면, 회고를 저장한 순간까지가 기록됩니다.",
            "업데이트가 있을 때 무엇이 바뀌었는지 알려 드립니다."
        ],
        onClose: {}
    )
}
