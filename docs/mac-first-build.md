# Mac 첫 빌드 체크리스트

M0~M2 코드는 Windows 에서 작성되어 한 번도 컴파일된 적이 없었다.
이 문서는 그 코드를 처음 빌드하는 절차와, 미리 짚어둔 실패 예상 지점을 정리한 것이다.

---

## 첫 빌드 결과 (2026-08-20, Xcode 26.6 / Swift 6.3)

**통과했다.** `swift test` 66/66, 앱·위젯 빌드 에러 0 · 경고 0, 시뮬레이터 실행 정상.

미검증이라던 `.swift` 파일 약 30개 중 **고쳐야 했던 것은 하나도 없었다.**
아래 "3단계 예상 실패 지점" 의 1~3번(SwiftData, 동시성/Observation, SwiftUI 세부 문법)은
전부 그대로 통과했다. 실제로 걸린 것은 코드가 아니라 빌드 설정과 환경이었다:

| 걸린 것 | 증상 | 고친 곳 |
|---|---|---|
| `Package.swift` 에 macOS 플랫폼 없음 | `swift test` 가 배포 타깃 10.13 으로 빌드돼 `Color`(10.15+)·`Date.now`(12+) 가 전부 막힘 | `platforms` 에 `.macOS(.v14)` 추가 |
| 스킴이 패키지 테스트 타겟 참조 | `xcodegen generate` 가 validation 에러로 죽음 | `project.yml` 스킴에서 `FocusCoreTests` 제거 |
| iOS 플랫폼 미설치 | destination 이 하나도 안 잡힘 (`iOS 26.5 is not installed`) | `xcodebuild -downloadPlatform iOS` (8.5GB) |
| 시뮬레이터 실행 시 무서명 | 예상 지점 4번 그대로 — `AppGroup.containerURL` 에서 `fatalError` 즉사 | `CODE_SIGN_IDENTITY="-" CODE_SIGN_STYLE=Manual` 로 빌드 |

마지막 항목은 이 문서가 미리 경고한 바로 그 지점이었다. 서명 인증서가 없어도
시뮬레이터는 ad-hoc 서명으로 entitlement 를 붙일 수 있다. 실기기는 여전히 팀이 필요하다.

### 눈으로 확인된 것

4단계 체크리스트 중 스크린샷으로 확인된 항목:

- 다이얼 부채꼴이 12시에서 시계방향으로 채워짐 — `DialView.sector` 의 `clockwise` 는 손댈 필요 없음
- 흰 핸들이 부채꼴 끝단에 정확히 붙음
- 눈금 숫자 0, 5, 10 … 55 가 시계방향
- 다크모드가 재시작 없이 즉시 전환되고, 눈금과 배경 대비가 살아 있음

**아직 확인 못 한 것:** 드래그·탭·길게누르기 같은 제스처 항목, 페이지 스와이프 충돌,
통계 화면, 위젯 다크 팔레트. 전부 사람이 직접 만져봐야 한다.

---

## 0. 준비

```bash
xcode-select -p          # Xcode 경로가 나와야 한다
brew install xcodegen
xcodebuild -showdestinations -scheme Jipjungryeok   # 시뮬레이터가 목록에 나오는지
```

Xcode 15 이상이 필요하다 (iOS 17 타깃, SwiftData, `@Observable`, `#Preview`).

destination 목록이 비어 있고 `iOS <버전> is not installed` 만 나오면 Xcode 만 깔고
iOS 플랫폼을 안 받은 상태다. `xcodebuild -downloadPlatform iOS` 로 받는다 (8GB 대, 오래 걸림).
Xcode 를 새로 깔거나 올린 직후에 이렇게 되기 쉽다.

---

## 1단계 — FocusCore 만 먼저 (Xcode 프로젝트 없이)

```bash
git clone https://github.com/janerim/jipjungryeok.git
cd jipjungryeok/FocusCore
swift test
```

**여기부터 하는 이유:** 지금까지 쌓은 로직의 핵심(타이머 엔진, 다이얼 기하, 통계 집계,
시간 표기)이 전부 `FocusCore` 에 있고, UIKit·SwiftData 의존이 없다.
프로젝트 생성도 서명도 시뮬레이터도 필요 없어서 **가장 빠르고 가장 원인이 좁다.**

여기서 컴파일이 깨지면 그 위의 모든 것도 깨진다. 앱 타깃부터 건드리지 말 것.

### 통과하면 확인되는 것

- §6 타이머 규칙 — 일시정지 누적, 강제 종료 후 복귀, 시계 역행/점프, 중도 중지 60초 기준
- §4.1 다이얼 각도 — 12시가 0분, 시계방향, 12시 경계 처리, 중심 데드존
- §4.2 통계 — 월요일 주 시작, 자정 넘는 세션의 시작일 귀속, 롤링 7·28일 경계, 차트 순서
- §4.1/§4.2 시간·날짜 표기

테스트가 **실패**(컴파일은 되는데 assertion 이 깨짐)한다면 그건 진짜 로직 버그다.
어느 테스트가 어떤 값을 기대했는지 메시지에 한글로 적혀 있다.

---

## 2단계 — Xcode 프로젝트

```bash
cd ..            # 리포지터리 루트
xcodegen generate
open Jipjungryeok.xcodeproj
```

### 최초 1회 서명

1. `Jipjungryeok` 타겟 → Signing & Capabilities → Team 선택
2. `FocusWidgets` 타겟에도 **같은 Team** 선택
3. App Groups(`group.com.janerim.jipjungryeok`)는 `project.yml` 이 이미 양쪽에
   선언해 두었다. **GUI 에서 추가하거나 지우지 말 것** — 다음 `xcodegen generate` 에 날아간다.

팀을 고정하고 싶으면 `project.yml` 의 `DEVELOPMENT_TEAM` 주석을 풀어 채운다.

> Xcode 에서 타겟 설정을 바꿔봐야 소용없다. `.xcodeproj` 는 생성물이라 git 에 없다.
> 구성 변경은 전부 `project.yml` 에서 하고 다시 generate 한다.

---

## 3단계 — 예상 실패 지점

가능성이 높은 순서다. 여기 적힌 것들은 작성 중에 "확인할 방법이 없어 위험하다" 고
표시해 둔 지점들이다.

### 1. SwiftData API (M2, 가장 위험)

`Jipjungryeok/Store/SessionStore.swift`

- `ModelConfiguration(url:)` / `ModelConfiguration(isStoredInMemoryOnly:)` 의 정확한 시그니처
- `#Predicate<FocusSession> { ... }` 문법
- `context.delete(model: FocusSession.self)`
- `FetchDescriptor` + `SortDescriptor(\.startAt, order: .reverse)`

SwiftData 가 이번에 처음 들어왔고 전부 미검증이다. 여기가 깨지면
`ModelConfiguration(groupContainer: .identifier(AppGroup.identifier))` 형태가 대안이다.

### 2. 동시성 / Observation

- `@MainActor @Observable final class` + `@ObservationIgnored` 조합
- `Timer(timeInterval:repeats:block:)` 의 `@Sendable` 클로저에서 `[weak self]` 로
  `@MainActor` 클래스를 잡는 부분 (`TimerViewModel.startTicking`)
- `@MainActor enum Haptics` 의 static 저장 프로퍼티
- `App.init()` 안에서 `_store = State(initialValue:)` 로 `@MainActor` 객체 생성

경고로 끝날 수도 있고 에러가 될 수도 있다. Swift 6 모드로 올리면 확실히 문제가 된다.

### 3. SwiftUI 사소한 것들

- `#Preview` 안의 `let ... ; return ...` 패턴
- `.contentTransition(.numericText())`, `.scrollIndicators(.hidden)`
- `TabView(selection:)` + `.tag(Page.stats)` + `.page(indexDisplayMode: .never)`
- `.highPriorityGesture(_:including:)` 의 `GestureMask` 값

### 4. 실행 시점 크래시 — App Group

`SessionStore` 는 App Group 컨테이너를 못 열면 **`fatalError` 로 즉사한다.**
서명이 안 맞으면 UI 한 번 못 보고 죽는다. 메시지에 원인이 적혀 있으니
그 경우 위 서명 절차를 다시 볼 것. (§13-1 이 경고한 바로 그 지점이다.)

---

## 3.5단계 — 실기기

시뮬레이터에서 확인할 수 없는 것들이 있다. 아래 항목은 **실기기에서만** 참·거짓이 갈린다.

```bash
./scripts/setup-device-signing.sh
```

이 스크립트가 인증서에서 팀 ID 를 뽑아 `project.yml` 에 넣고 프로젝트를 다시 만든다.
그 전에 **Xcode > Settings > Accounts 에서 Apple ID 로그인**이 되어 있어야 한다.

> **유료 개발자 계정이어야 한다.** App Group(`group.com.janerim.jipjungryeok`)을 쓰는데
> 무료 개인 팀은 App Groups Capability 를 쓸 수 없다. 그 상태로 실기기에 올리면
> `AppGroup.containerURL` 에서 `fatalError` 로 즉사한다 (§13-1). 시뮬레이터에서는
> ad-hoc 서명으로 넘어가던 문제라 여기서 처음 드러난다.

기기를 USB 로 연결하고 잠금을 해제한 뒤 "이 컴퓨터를 신뢰" 를 누른다.
첫 실행이 거부되면 기기에서 **설정 > 일반 > VPN 및 기기 관리 > 개발자 앱 > 신뢰**.

### 실제로 걸렸던 것 세 가지

1. **계정 로그인만으로는 인증서가 안 생긴다.** Xcode > Settings > Apple Accounts 에서
   `Manage Certificates…` > `+` > `Apple Development` 를 눌러야 이 Mac 용 인증서가 만들어진다.
2. **기기의 개발자 모드가 꺼져 있으면 빌드가 destination 단계에서 멈춘다.**
   기기에서 설정 > 개인정보 보호 및 보안 > 개발자 모드 > 켜기 (재시동 필요).
   이 항목은 Xcode 가 개발 빌드를 한 번 시도한 뒤에야 설정에 나타난다.
3. **첫 실행은 Xcode GUI 로 해야 한다.** 기기 등록과 프로비저닝 프로파일 생성에
   Apple 계정 세션이 필요한데 `xcodebuild` 에는 그 세션이 없다.
   `-allowProvisioningUpdates` 를 줘도 "Device isn't registered" 로 실패한다.
   Xcode 에서 한 번 `⌘R` 하고 나면 프로파일이 생겨서 그다음부터는 CLI 도 된다.

빌드 중 키체인이 `codesign 이 키 접근을 허용하고자 합니다` 라고 물으면 **Mac 로그인 암호**를
넣고 `항상 허용` 을 누른다. `허용` 은 한 번만이라 빌드마다 다시 묻는다.

### 실기기에서만 확인되는 것

- [ ] **완료 시 소리 없이 햅틱만 온다** (§6-3). 시뮬레이터에는 햅틱이 없다
- [ ] **무음 스위치를 내린 상태에서도** 완료 알림이 소리를 내지 않는다
- [ ] 다이얼 드래그 중 1분 스냅마다 햅틱이 온다. 손끝으로만 판단되는 감각이다
- [ ] 잠금화면에서 Live Activity 가 뜨고, 화면을 끈 채로도 남은 시간이 맞는다
- [ ] Dynamic Island 의 compact / expanded / minimal 세 형태가 모두 정상이다
- [ ] **캘린더가 여러 개인 계정에서** 목록이 제대로 나오고 고른 곳에 기록된다
      (시뮬레이터에는 로컬 캘린더 하나뿐이라 이 경로가 검증되지 않았다)
- [ ] iCloud 캘린더에 쓴 이벤트가 다른 기기에도 동기화된다
- [ ] 실행 중 화면이 자동으로 꺼지지 않고, 끝나면 다시 꺼진다
- [ ] 배터리·발열이 이상하지 않다 (1초 타이머 + Live Activity 를 오래 켜 둔 뒤)

## 4단계 — 눈으로만 확인되는 것

테스트가 잡아주지 못하는 것들이다. 시뮬레이터에서 직접 볼 것.

### 다이얼 (§4.1)

- [ ] 부채꼴이 **12시 방향에서 시계방향으로** 채워진다
      (SwiftUI 는 y축이 아래로 향해서 `addArc` 의 `clockwise` 가 직관과 반대다.
      뒤집혀 있으면 `DialView.sector` 의 `clockwise: false` 를 `true` 로)
- [ ] 흰 핸들이 부채꼴 끝단에 붙어 있다
- [ ] 눈금 숫자가 0, 5, 10 … 55 로 시계방향으로 놓인다
- [ ] 드래그하면 1분 단위로 스냅되고 스냅마다 햅틱이 온다
- [ ] 손을 떼면 **즉시** 카운트다운이 시작된다
- [ ] 실행 중 탭 = 일시정지, 다시 탭 = 재개, 0.6초 길게 = 중지

### 제스처 충돌 (§4.0, §12)

- [ ] **다이얼 위에서** 좌우로 드래그 → 페이지가 안 넘어가고 시간이 조정된다
- [ ] **다이얼 바깥 여백에서** 좌우로 스와이프 → 통계/설정으로 넘어간다
- [ ] 타이머 실행 중 통계로 갔다 돌아와도 세션이 유지된다

### 통계 (§4.2)

- [ ] 세션 0건일 때 크래시 없이 빈 상태가 그려진다
- [ ] 35분 세션 하나 완료 후 다섯 칸이 전부 `00:35`
- [ ] 차트가 **최신 날짜를 왼쪽에** 두고 10일치를 표시한다
- [ ] 회고 카드에 날짜 / 분 / 종료 시각이 들어간다

### 다크모드 (§12)

- [ ] 시스템을 다크로 바꾸면 앱이 다크 팔레트로 전환된다
- [ ] 앱 실행 중에 모드를 바꿔도 재시작 없이 즉시 반영된다
- [ ] 다크에서 다이얼 눈금과 배경의 대비가 식별된다
- [ ] 위젯도 다크 팔레트를 따른다 (§13-4 — 여기가 자주 깨진다)

### 알림 & 상태 복구 (M3, §6-5 / §12)

시뮬레이터에서 백그라운드로 내리고 기다려야 확인된다.

- [ ] 첫 세션을 시작할 때 알림 권한을 묻는다 (앱 시작 시점이 아니다)
- [ ] 앱을 백그라운드로 내린 채 세션이 끝나면 **무음** 배너가 뜬다
- [ ] 포그라운드로 세션이 끝나면 배너 없이 햅틱만 온다 (배너가 중복으로 뜨면 안 됨)
- [ ] 일시정지한 뒤 원래 종료 시각이 지나도 알림이 뜨지 않는다
- [ ] 세션을 중지한 뒤에도 알림이 뜨지 않는다
- [ ] 실행 중 앱을 스와이프 kill 하고 다시 켜면 **남은 시간이 이어진다**
- [ ] 꺼져 있는 동안 끝난 세션은 앱을 켜면 통계에 들어와 있고, 그때 진동하지 않는다

### 캘린더 (M4, §7)

- [ ] 설정에서 캘린더 기록을 **켤 때** 권한을 묻는다
- [ ] 권한 허용 후 세션 완료 시 **기본 캘린더**에 이벤트가 생긴다
- [ ] 이벤트 제목이 `🎯 집중` / 중도 중지는 `🎯 집중 (중단)` — 제목에 분은 안 들어간다
- [ ] 이벤트의 **길이**가 실제 집중한 시간과 같다 (25분 맞춰놓고 7분에 멈추면 7분짜리)
- [ ] 권한을 거부해도 앱이 정상 동작하고 세션은 저장된다
- [ ] 앱을 여러 번 껐다 켜도 `집중` 이라는 캘린더가 새로 생기지 않는다

전용 `집중` 캘린더는 만들지 않기로 했다. 쓰기 전용 권한에서 기존 캘린더 조회가
막히면 세션마다 캘린더가 새로 생겨 사용자 캘린더 목록이 오염되기 때문이다.
조회가 필요 없는 구조라 이제 그 실패 모드 자체가 없다. 대신 집중 세션이 일반 일정과
섞이므로, 제목의 `🎯` 접두어가 유일한 구분 수단이다.

### 위젯 & Live Activity (M5, §8)

- [ ] 홈화면 small 에 오늘 링이, medium 에 링 + 이번 주 7칸이 나온다
- [ ] 세션을 끝내면 5초 이내에 위젯의 오늘 시간이 갱신된다
- [ ] 잠금화면 `accessoryCircular`·`accessoryRectangular` 가 벽지 위에서 읽힌다
- [ ] 테마를 바꾸면 홈 위젯 색도 따라 바뀐다 (위젯은 앱과 다른 프로세스라 여기가 자주 어긋난다)
- [ ] **세션을 시작하면 잠금화면에 Live Activity 가 뜨고 남은 시간이 스스로 줄어든다**
- [ ] 앱을 완전히 닫아도 Live Activity 의 카운트다운이 계속 맞는다 (push 없이 시스템이 줄인다)
- [ ] 일시정지하면 카운트다운이 멈추고 `일시정지` 로 바뀐다
- [ ] 완료·중지 시 Live Activity 가 즉시 사라진다
- [ ] 실행 중 앱을 스와이프 kill 하고 다시 켜도 Live Activity 가 **하나만** 남는다
- [ ] Dynamic Island compact 에 남은 시간이, expanded 에 링과 종료 예정 시각이 나온다

### 세션 메모 (§6-6)

- [ ] 세션이 **완료**되면 메모 시트가 뜬다 (중도 중지는 안 뜬다)
- [ ] 건너뛰거나 시트를 내려도 캘린더 이벤트가 만들어진다
- [ ] 메모를 쓰면 캘린더 이벤트 notes 에 들어간다
- [ ] 회고 카드에 메모 한 줄이 보이고, 메모 없는 칸과 높이가 같다
- [ ] 백그라운드에서 끝난 세션은 **앱을 다시 열 때** 메모를 묻는다
- [ ] 메모를 안 받은 채 새 세션을 끝내면, 앞 세션이 메모 없이 캘린더에 올라간다
      (앞 세션이 영영 누락되면 안 된다)

### 설정 화면 (M4, §4.3)

- [ ] 네 줄만 있다 — 캘린더 기록 / (권한 없을 때만) 안내 배너 / 데이터 초기화 / 앱 버전
- [ ] 캘린더 권한을 거부하면 토글이 켜지지 않고 안내 배너가 뜬다
- [ ] "설정 열기" 가 시스템 설정의 이 앱 화면으로 간다
- [ ] 데이터 초기화가 **확인 2단계**를 거치고, 통계가 빈 상태로 돌아간다

### 기타

- [ ] 타이머 실행 중 화면이 자동으로 꺼지지 않고, 끝나면 다시 꺼진다
- [ ] 완료 시 **소리 없이** 햅틱만 온다 (무음모드 해제 상태에서도)
- [ ] `Info.plist` 의 한글 문자열(`집중력`, 캘린더 권한 안내문)이 안 깨진다
- [ ] 다이얼 최대가 **90분**이고 라벨이 0/15/30/45/60/75 로 보인다

---

## 5단계 — 결과 정리

Claude Code 로 이어서 작업한다면 다음을 그대로 넘기면 된다:

1. `swift test` 출력 (실패한 테스트 이름과 메시지)
2. 첫 빌드 에러 목록 — 파일명과 줄 번호가 있는 그대로
3. 위 눈 확인 체크리스트에서 어긋난 항목

에러가 많아 보여도 대부분 같은 원인에서 파생된 것들이다.
**`FocusCore` → 앱 타깃 → 위젯 순서로 하나씩** 좁히는 게 빠르다.

첫 빌드가 통과하면 [CLAUDE.md](../CLAUDE.md) 의 경고 섹션을 지우고
진행 상황 표의 "빌드 미검증" 을 갱신할 것.
