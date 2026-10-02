import SwiftUI
import UIKit
import UniformTypeIdentifiers
import FocusCore

/// §4.3 설정 화면 — 타이머에서 오른쪽으로 스와이프.
///
/// 여기에 항목을 늘리고 싶어지면 §2·§3 의 "설정을 만들지 않는다" 원칙과 제외 목록을
/// 먼저 볼 것. 지금 있는 것들은 각각 근거가 있다 — 권한을 사용자가 켜야 하거나(캘린더),
/// 매번 같은 값으로 시작하는 사람이 많거나(기본 시간), 색이 곧 앱의 인상이거나(테마).
struct SettingsView: View {

    let recorder: SessionRecorder
    @ObservedObject var settings: AppSettings
    @ObservedObject var calendar: CalendarService
    @ObservedObject var notifications: NotificationService
    let timerModel: TimerViewModel

    @State private var isRequestingCalendarAccess = false
    @State private var showsFirstResetConfirm = false
    @State private var showsSecondResetConfirm = false
    @State private var showsImporter = false
    @State private var transferAlert: TransferAlert?

    var body: some View {
        ScrollView(showsIndicators: false) {
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
                if settings.isCalendarEnabled && calendar.canWrite {
                    calendarPickerRow
                }
                themeRow
                transferRow
                resetRow
                versionRow
            }
            .padding(.horizontal, 20)
            .padding(.top, 28)
            // 하단 페이지 인디케이터에 가리지 않게 띄운다
            .padding(.bottom, 44)
        }
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
                    Text("세션이 끝나거나 멈추면 메모를 묻습니다")
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
    /// §4.1 다이얼이 처음 가리키는 분. 5분 단위 휠.
    ///
    /// `main` 은 시스템 휠을 피하고 가로 스크롤을 직접 만들었다. 휠은 돌릴 때마다
    /// "따따닥" 소리를 끌 수 없고, 글자를 시스템이 그려 `Palette` 를 온전히 따르지 않는다.
    /// 그런데 가운데로 착 붙는 가로 스크롤(`scrollTargetBehavior`·`scrollPosition`)이
    /// iOS 17 부터라, `ios15` 브랜치는 휠로 돌아왔다. 휠은 VoiceOver 조정도 기본으로 된다.
    private var defaultMinutesRow: some View {
        card {
            VStack(alignment: .leading, spacing: 10) {
                Text("기본 시간")
                    .foregroundStyle(Palette.ink)

                Picker("기본 시간", selection: defaultMinutesBinding) {
                    ForEach(Self.minuteOptions, id: \.self) { minutes in
                        Text("\(minutes)분")
                            .foregroundStyle(Palette.ink)
                            .tag(minutes)
                    }
                }
                .pickerStyle(.wheel)
                // 휠의 기본 높이(약 216pt)는 설정 카드 하나로는 너무 크다.
                // 위아래 두 칸씩만 보이게 줄인다.
                .frame(height: 120)
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
            set: { applyDefaultMinutes($0) }
        )
    }

    /// 휠이 멈춘 값이 곧 선택값이다.
    private func applyDefaultMinutes(_ minutes: Int) {
        guard minutes != settings.defaultMinutes else { return }
        settings.setDefaultMinutes(minutes)
        // 쉬고 있는 다이얼은 즉시 새 값으로 옮겨 준다. 설정하고 돌아갔더니
        // 그대로면 적용이 안 된 줄 안다.
        timerModel.applyDefaultMinutes(settings.defaultMinutes)
    }

    /// §7 어느 캘린더에 남길지.
    ///
    /// **캘린더 목록 조회에는 전체 접근 권한이 필요하다.** 쓰기 전용 권한으로는
    /// 이벤트를 만들 수는 있어도 캘린더를 열거하지 못한다 — 시뮬레이터에서는 로컬
    /// 캘린더가 보여서 되는 줄 알았는데 실기기의 iCloud 계정에서는 빈 목록이 온다.
    ///
    /// 그래서 기본은 쓰기 전용 그대로 두고, 고르고 싶은 사람만 여기서 권한을 올린다.
    /// 전체 접근은 사용자의 모든 일정을 읽을 수 있다는 뜻이라 필요 없는 사람에게까지
    /// 물어보지 않는다.
    private var calendarPickerRow: some View {
        card {
            if calendar.canListCalendars {
                calendarMenu
            } else {
                calendarAccessUpgrade
            }
        }
    }

    private var calendarMenu: some View {
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

    /// 목록이 비어 있을 때 아무것도 안 보여주면 "왜 안 나오지" 로 끝난다.
    /// 이유와 해결 방법을 같은 자리에 놓는다.
    private var calendarAccessUpgrade: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("기록할 캘린더")
                    .foregroundStyle(Palette.ink)
                Text("지금은 기본 캘린더에 남깁니다. 고르려면 캘린더 읽기 권한이 필요합니다.")
                    .font(Typography.statCaption)
                    .foregroundStyle(Palette.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button("캘린더 선택 허용") {
                Task { await calendar.requestFullAccess() }
            }
            .font(Typography.statCaption)
            .filledButton()
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
        .pressable()
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

    /// §4.3 다른 iPhone 으로 기록을 옮긴다.
    ///
    /// 클라우드 동기화는 만들지 않기로 했으므로(§3) 사용자가 파일을 직접 옮긴다 —
    /// 한쪽에서 내보내 AirDrop 으로 보내고, 받은 쪽에서 "파일" 에 저장한 뒤 가져온다.
    /// 두 버튼을 한 카드에 두는 이유는 보내는 쪽과 받는 쪽이 짝이라는 것이 한눈에 읽혀야 해서다.
    ///
    /// 알림과 파일 선택기를 이 카드에 단다. 화면 맨 바깥에는 초기화 확인 알림이 이미
    /// 둘 붙어 있다. 한 뷰에 sheet 를 둘 붙이면 하나만 살아남는 사고(§4.4, `RootView`)를
    /// 같은 이유로 피해 간다.
    private var transferRow: some View {
        card {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("기록 옮기기")
                        .foregroundStyle(Palette.ink)
                    Text("다른 iPhone 에서 내보낸 파일을 가져오면 기록이 합쳐집니다. 이미 있는 세션은 그대로 둡니다.")
                        .font(Typography.statCaption)
                        .foregroundStyle(Palette.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 10) {
                    Button("내보내기", action: exportSessions)
                        .font(Typography.statCaption)
                        .filledButton()
                    Button("가져오기") { showsImporter = true }
                        .font(Typography.statCaption)
                        .filledButton()
                }
            }
        }
        .fileImporter(isPresented: $showsImporter, allowedContentTypes: [.json]) { result in
            importSessions(result)
        }
        .alert(
            transferAlert?.title ?? "",
            isPresented: Binding(
                get: { transferAlert != nil },
                set: { if !$0 { transferAlert = nil } }
            ),
            presenting: transferAlert
        ) { _ in
            Button("확인", role: .cancel) {}
        } message: { alert in
            Text(alert.message)
        }
    }

    private func exportSessions() {
        let archive = recorder.store.exportArchive()
        guard !archive.sessions.isEmpty else {
            transferAlert = TransferAlert(
                title: "내보낼 기록이 없습니다",
                message: "세션을 하나 끝내면 내보낼 수 있습니다."
            )
            return
        }

        do {
            // 임시 폴더에 쓴다. 공유가 끝나면 필요 없는 파일이고, 시스템이 알아서 치운다.
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent(archive.suggestedFileName())
            try archive.encoded().write(to: url, options: .atomic)
            ShareSheet.present(url)
        } catch {
            transferAlert = TransferAlert(title: "내보내지 못했습니다", message: error.localizedDescription)
        }
    }

    private func importSessions(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            // "파일" 앱에서 고른 파일은 앱 샌드박스 밖이라 접근을 열어야 읽힌다.
            // 열었으면 반드시 닫는다 — Apple 문서상 안 닫으면 커널 자원이 새고, 쌓이면
            // 앱을 다시 켤 때까지 다른 파일도 열지 못한다.
            let isAccessing = url.startAccessingSecurityScopedResource()
            defer { if isAccessing { url.stopAccessingSecurityScopedResource() } }

            let archive = try SessionArchive.decode(Data(contentsOf: url))
            let added = recorder.store.importSessions(from: archive)
            let skipped = archive.sessions.count - added

            if added == 0 {
                transferAlert = TransferAlert(
                    title: "새 기록이 없습니다",
                    message: "파일에 있는 \(skipped)건이 모두 이미 있습니다."
                )
            } else {
                transferAlert = TransferAlert(
                    title: "기록을 가져왔습니다",
                    message: skipped == 0
                        ? "\(added)건을 가져왔습니다."
                        : "\(added)건을 가져왔습니다. \(skipped)건은 이미 있어서 건너뛰었습니다."
                )
            }
        } catch SessionArchive.ReadError.unsupportedVersion {
            transferAlert = TransferAlert(
                title: "가져오지 못했습니다",
                message: "더 새 버전의 집중력에서 만든 파일입니다. 앱을 업데이트한 뒤 다시 가져와 주세요."
            )
        } catch {
            transferAlert = TransferAlert(
                title: "가져오지 못했습니다",
                message: "집중력에서 내보낸 기록 파일이 아닙니다."
            )
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

/// 기록 옮기기 결과 알림.
private struct TransferAlert {
    let title: String
    let message: String
}

/// UIKit 공유 시트를 맨 위 화면에 띄운다.
///
/// SwiftUI 의 `ShareLink` 를 쓰지 않는 이유: iOS 16 부터라 `ios15` 브랜치에서 쓸 수 없다.
/// 두 브랜치의 코드를 같게 두려고 iOS 15 에서도 되는 길로 간다.
/// `.sheet` 안에 `UIActivityViewController` 를 넣지 않는 이유: 공유 시트가 SwiftUI 시트 안에
/// 한 겹 더 들어간다. 직접 띄우면 시스템 기본 모양 그대로 뜬다.
private enum ShareSheet {

    @MainActor
    static func present(_ url: URL) {
        guard let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive }),
              var top = scene.keyWindow?.rootViewController else { return }

        // 이미 다른 화면이 떠 있으면 그 위에 띄워야 보인다. 아래에 띄우면 조용히 무시된다.
        while let presented = top.presentedViewController {
            top = presented
        }
        top.present(
            UIActivityViewController(activityItems: [url], applicationActivities: nil),
            animated: true
        )
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
