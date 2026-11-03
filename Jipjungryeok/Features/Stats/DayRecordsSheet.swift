import SwiftUI
import FocusCore

/// §4.2-3 달력에서 날짜를 눌렀을 때 그날 세션을 보여주는 시트.
///
/// 달력이 "며칠 나왔나" 를 답한다면 여기는 "그날 뭘 했나" 를 답한다.
/// 기록 시트(`HistoryView`)와 같은 줄(`SessionRow`)을 쓴다 — 어디서 들어오든
/// 같은 세션이 같은 모양이어야 알아보는 데 한 박자가 들지 않는다.
struct DayRecordsSheet: View {

    let date: Date
    let store: SessionStore
    let recorder: SessionRecorder

    @State private var sessions: [SessionRecord] = []
    @State private var editing: SessionRecord?
    @Environment(\.dismiss) private var dismiss

    private let calendar = Calendar.focus

    var body: some View {
        ZStack {
            Palette.background
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                header

                if sessions.isEmpty {
                    emptyState
                } else {
                    list
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .task { reload() }
        .sheet(item: $editing) { session in
            MemoEditSheet(session: session) { memo in
                recorder.updateMemo(memo, for: session.id)
                reload()
            }
        }
    }

    /// 열 때마다 스토어에서 다시 읽는다. 달력이 들고 있던 값을 넘겨받으면
    /// 메모를 고친 뒤 옛 값이 남는다.
    private func reload() {
        let day = calendar.startOfDay(for: date)
        sessions = store.allRecords()
            .filter { calendar.isDate($0.startAt, inSameDayAs: day) }
            // §4.2 와 같은 축으로 정렬한다 — 늦게 시작한 세션이 위.
            .sorted { $0.startAt > $1.startAt }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text(TimeDisplay.monthDay(date))
                    .font(Typography.sheetTitle)
                    .foregroundStyle(Palette.ink)

                if !sessions.isEmpty {
                    Text("\(sessions.count)회 · \(TimeDisplay.hhmm(totalSeconds))")
                        .font(Typography.statCaption)
                        .foregroundStyle(Palette.inkSecondary)
                        .monospacedDigit()
                }
            }

            Spacer()

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
        .padding(.horizontal, 24)
        .padding(.top, 24)
    }

    private var totalSeconds: Int {
        sessions.reduce(0) { $0 + $1.actualSeconds }
    }

    /// 달력에서 빈 날을 눌러도 들어올 수 있다. 빈 시트가 그려져야 한다 (§12).
    private var emptyState: some View {
        Text("이 날은 기록이 없습니다")
            .font(Typography.statCaption)
            .foregroundStyle(Palette.inkSecondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var list: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                ForEach(sessions) { session in
                    SessionRow(session: session) { editing = session }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 18)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
    }
}

#Preview {
    let store = SessionStore(inMemory: true)
    let settings = AppSettings()
    return DayRecordsSheet(
        date: Date(),
        store: store,
        recorder: SessionRecorder(
            store: store,
            calendar: CalendarService(),
            settings: settings
        )
    )
}
