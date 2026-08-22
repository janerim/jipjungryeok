import SwiftUI
import UIKit
import FocusCore

/// §4.3 설정 화면 — 타이머에서 오른쪽으로 스와이프.
///
/// 리스트 4줄이 전부다. 여기에 항목을 늘리고 싶어지면 §2·§3 의 "설정을 만들지 않는다"
/// 원칙과 제외 목록을 먼저 볼 것.
struct SettingsView: View {

    let recorder: SessionRecorder
    let settings: AppSettings
    let calendar: CalendarService
    let notifications: NotificationService

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
                    Text("완료한 세션을 '집중' 캘린더에 남깁니다")
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
            .font(Typography.statValue)
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
    return ZStack {
        Palette.background.ignoresSafeArea()
        SettingsView(
            recorder: SessionRecorder(store: store, calendar: calendar, settings: settings),
            settings: settings,
            calendar: calendar,
            notifications: NotificationService()
        )
    }
}
