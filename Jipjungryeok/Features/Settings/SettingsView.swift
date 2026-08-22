import SwiftUI
import UIKit
import FocusCore

/// §4.3 설정 화면 — 타이머에서 오른쪽으로 스와이프.
///
/// 여기에 항목을 늘리고 싶어지면 §2·§3 의 "설정을 만들지 않는다" 원칙과 제외 목록을
/// 먼저 볼 것. 지금 있는 것들은 각각 근거가 있다 — 권한을 사용자가 켜야 하거나(캘린더),
/// 매번 같은 값으로 시작하는 사람이 많거나(기본 시간), 색이 곧 앱의 인상이거나(테마).
struct SettingsView: View {

    let recorder: SessionRecorder
    let settings: AppSettings
    let calendar: CalendarService
    let notifications: NotificationService
    let timerModel: TimerViewModel

    @State private var isRequestingCalendarAccess = false
    @State private var showsFirstResetConfirm = false
    @State private var showsSecondResetConfirm = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                calendarRow
                if calendar.isDenied && settings.isCalendarEnabled {
                    permissionNotice(
                        message: "캘린더 권한이 꺼져 있어 기록되지 않습니다.",
                        action: openSystemSettings
                    )
                }

                if shouldShowNotificationNotice {
                    permissionNotice(
                        message: "알림이 꺼져 있어 백그라운드에서 완료를 알리지 못합니다.",
                        action: openSystemSettings
                    )
                }

                defaultMinutesRow
                memoPromptRow
                if calendar.canWrite && settings.isCalendarEnabled {
                    calendarPickerRow
                }
                themeRow
                resetRow
                versionRow
            }
            .padding(.horizontal, 20)
            .padding(.top, 28)
            // 하단 페이지 인디케이터에 가리지 않게 띄운다
            .padding(.bottom, 44)
        }
        .scrollIndicators(.hidden)
        .task {
            // 사용자가 시스템 설정에서 권한을 바꾸고 돌아왔을 수 있다.
            calendar.refreshAuthorization()
            await notifications.refreshAuthorization()
        }
        .alert("모든 기록을 지울까요?", isPresented: $showsFirstResetConfirm) {
            Button("취소", role: .cancel) {}
            Button("계속", role: .destructive) { showsSecondResetConfirm = true }
        } message: {
            Text("저장된 집중 세션과 통계가 전부 사라집니다.")
        }
        .alert("정말 지울까요?", isPresented: $showsSecondResetConfirm) {
            Button("취소", role: .cancel) {}
            Button("지우기", role: .destructive) { recorder.resetAllData() }
        } message: {
            Text("되돌릴 수 없습니다. 캘린더에 이미 기록된 일정은 지워지지 않습니다.")
        }
    }

    // MARK: - 줄

    /// §6-6 — 이 앱에서 유일하게 사용자를 멈춰 세우는 화면이라 끌 수 있어야 한다.
    private var memoPromptRow: some View {
        card {
            Toggle(isOn: memoPromptBinding) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("회고 남기기")
                        .foregroundStyle(Palette.ink)
                    Text("세션이 끝나면 메모를 묻습니다")
                        .font(Typography.statCaption)
                        .foregroundStyle(Palette.inkSecondary)
                }
            }
            .tint(Palette.accent)
        }
    }

    private var memoPromptBinding: Binding<Bool> {
        Binding(
            get: { settings.isMemoPromptEnabled },
            set: { isOn in
                settings.isMemoPromptEnabled = isOn
                // 끄는 순간 대기 중인 회고가 있으면 메모 없이 확정한다.
                // 안 그러면 그 세션이 캘린더에 영영 안 올라간다.
                if !isOn { recorder.refreshMemoPrompt() }
            }
        )
    }


    /// §4.1 다이얼이 처음 가리키는 분.
    ///
    /// 5분 단위다. 여기서 1분 단위로 맞출 일이 없다 — 그날의 미세 조정은 다이얼이 한다.
    private var defaultMinutesRow: some View {
        card {
            HStack(spacing: 12) {
                Text("기본 시간")
                    .foregroundStyle(Palette.ink)

                Spacer(minLength: 0)

                // 5분 단위 스크롤. +/− 버튼은 25분에서 90분까지 열세 번을 눌러야 해서
                // 값을 크게 옮길 때 손이 많이 갔다.
                Picker("기본 시간", selection: defaultMinutesBinding) {
                    ForEach(Self.minuteOptions, id: \.self) { minutes in
                        Text("\(minutes)분")
                            .foregroundStyle(Palette.ink)
                            .tag(minutes)
                    }
                }
                .labelsHidden()
                .pickerStyle(.wheel)
                .frame(width: 116, height: 96)
                .clipped()
            }
        }
    }

    private static let minuteOptions: [Int] = Array(
        stride(from: AppSettings.minutesStep, through: TimerEngine.maximumMinutes, by: AppSettings.minutesStep)
    )

    private var defaultMinutesBinding: Binding<Int> {
        Binding(
            get: { settings.defaultMinutes },
            set: { minutes in
                settings.setDefaultMinutes(minutes)
                // 쉬고 있는 다이얼은 즉시 새 값으로 옮겨 준다. 설정하고 돌아갔더니
                // 그대로면 적용이 안 된 줄 안다.
                timerModel.applyDefaultMinutes(settings.defaultMinutes)
            }
        )
    }

    /// §7 어느 캘린더에 남길지.
    ///
    /// 쓰기 전용 권한에서도 목록 조회가 되는 것을 확인하고 넣었다. 전체 접근으로
    /// 올리지 않는다. 권한이 없거나 기록이 꺼져 있으면 이 줄 자체를 보여주지 않는다 —
    /// 고를 수는 있는데 기록이 안 되는 상태가 제일 헷갈린다.
    private var calendarPickerRow: some View {
        card {
            HStack(spacing: 0) {
                Text("기록할 캘린더")
                    .foregroundStyle(Palette.ink)

                Spacer(minLength: 12)

                Menu {
                    Button("기본 캘린더") { settings.calendarIdentifier = nil }
                    ForEach(calendar.writableCalendars(), id: \.calendarIdentifier) { item in
                        Button(item.title) { settings.calendarIdentifier = item.calendarIdentifier }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(selectedCalendarTitle)
                            .foregroundStyle(Palette.inkSecondary)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Palette.inkSecondary)
                    }
                }
            }
        }
    }

    /// 고른 캘린더가 사라졌으면 "기본 캘린더" 로 보인다. 실제 기록도 그리로 간다.
    private var selectedCalendarTitle: String {
        calendar.calendarTitle(for: settings.calendarIdentifier) ?? "기본 캘린더"
    }


    /// §10 색 테마.
    ///
    /// 라이트/다크는 여전히 시스템을 따른다. 여기서 고르는 것은 색 계열이지 밝기가 아니라
    /// 항목을 "밝게/어둡게" 로 오해할 여지가 없다.
    private var themeRow: some View {
        card {
            VStack(alignment: .leading, spacing: 12) {
                Text("색")
                    .foregroundStyle(Palette.ink)

                HStack(spacing: 10) {
                    ForEach(PaletteTheme.allCases, id: \.self) { theme in
                        themeChip(theme)
                    }
                }
            }
        }
    }

    private func themeChip(_ theme: PaletteTheme) -> some View {
        let isSelected = settings.theme == theme

        return Button {
            settings.theme = theme
        } label: {
            Text(theme.displayName)
                .font(Typography.statCaption)
                // 선택된 칩만 배경으로 채운다. 색 이름을 그 테마의 색으로 칠하면
                // 지금 적용된 테마 위에서 서로 안 어울려 오히려 못 읽는다.
                .foregroundStyle(isSelected ? Palette.background : Palette.ink)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: Metrics.cardCornerRadius)
                        .fill(isSelected ? Palette.ink : Palette.background)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Metrics.cardCornerRadius)
                        .stroke(Palette.stroke, lineWidth: Metrics.cardStrokeWidth)
                )
                .contentShape(Rectangle())
        }
        .accessibilityLabel("\(theme.displayName) 색")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }


    /// §4.3 — 켤 때 권한을 요청한다.
    private var calendarRow: some View {
        card {
            Toggle(isOn: calendarBinding) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("캘린더 기록")
                        .foregroundStyle(Palette.ink)
                    Text("완료한 세션을 캘린더에 남깁니다")
                        .font(Typography.statCaption)
                        .foregroundStyle(Palette.inkSecondary)
                }
            }
            .tint(Palette.accent)
            .disabled(isRequestingCalendarAccess)
        }
    }

    private var calendarBinding: Binding<Bool> {
        Binding(
            get: { settings.isCalendarEnabled },
            set: { isOn in
                guard isOn else {
                    // 끄는 것은 권한과 무관하다. 과거 이벤트는 지우지 않는다 (§7).
                    settings.isCalendarEnabled = false
                    return
                }
                Task {
                    isRequestingCalendarAccess = true
                    let granted = await calendar.requestAccess()
                    isRequestingCalendarAccess = false
                    // 거부되면 토글을 켜지 않는다. 켜져 있는데 기록이 안 되는 상태가
                    // 제일 헷갈린다 — 대신 아래 안내 배너로 이유를 알린다.
                    settings.isCalendarEnabled = granted
                }
            }
        )
    }

    /// §4.3 — 권한이 없을 때만 노출된다.
    private var shouldShowNotificationNotice: Bool {
        notifications.authorizationStatus == .denied
    }

    private func permissionNotice(message: String, action: @escaping () -> Void) -> some View {
        card {
            HStack(spacing: 12) {
                Text(message)
                    .font(Typography.statCaption)
                    .foregroundStyle(Palette.inkSecondary)
                Spacer(minLength: 8)
                Button("설정 열기", action: action)
                    .font(Typography.statCaption)
                    .foregroundStyle(Palette.ink)
            }
        }
    }

    private var resetRow: some View {
        card {
            Button {
                showsFirstResetConfirm = true
            } label: {
                HStack {
                    Text("데이터 초기화")
                        .foregroundStyle(Palette.ink)
                    Spacer()
                }
            }
        }
    }

    private var versionRow: some View {
        card {
            HStack {
                Text("앱 버전")
                    .foregroundStyle(Palette.ink)
                Spacer()
                Text(Self.versionText)
                    .foregroundStyle(Palette.inkSecondary)
                    .monospacedDigit()
            }
        }
    }

    // MARK: -

    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            // 시트 제목과 같은 크기. 설정은 훑어보는 화면이라 항목 글자가 크면
            // 한 화면에 안 들어오고, 무엇보다 목록이 무거워 보인다.
            .font(Typography.sheetTitle)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(
                RoundedRectangle(cornerRadius: Metrics.cardCornerRadius)
                    .stroke(Palette.stroke, lineWidth: Metrics.cardStrokeWidth)
            )
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private static var versionText: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "0.0.0"
        let build = info?["CFBundleVersion"] as? String ?? "0"
        return "\(short) (\(build))"
    }
}

#Preview {
    let store = SessionStore(inMemory: true)
    let settings = AppSettings()
    let calendar = CalendarService()
    let recorder = SessionRecorder(store: store, calendar: calendar, settings: settings)
    let notifications = NotificationService()
    return ZStack {
        Palette.background.ignoresSafeArea()
        SettingsView(
            recorder: recorder,
            settings: settings,
            calendar: calendar,
            notifications: notifications,
            timerModel: TimerViewModel(
                recorder: recorder,
                notifications: notifications,
                defaultMinutes: settings.defaultMinutes
            )
        )
    }
}
