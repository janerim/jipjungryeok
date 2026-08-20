# Mac 첫 빌드 체크리스트

M0~M2 코드는 Windows 에서 작성되어 **한 번도 컴파일된 적이 없다.**
이 문서는 그 코드를 처음 빌드하는 절차와, 미리 짚어둔 실패 예상 지점을 정리한 것이다.

첫 빌드는 "되는지 보는 일" 이 아니라 **에러를 걷어내는 작업**이라고 생각하고 시작할 것.
한 번에 다 통과하면 운이 좋은 것이다.

---

## 0. 준비

```bash
xcode-select -p          # Xcode 경로가 나와야 한다
brew install xcodegen
```

Xcode 15 이상이 필요하다 (iOS 17 타깃, SwiftData, `@Observable`, `#Preview`).

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

### 기타

- [ ] 타이머 실행 중 화면이 자동으로 꺼지지 않고, 끝나면 다시 꺼진다
- [ ] 완료 시 **소리 없이** 햅틱만 온다 (무음모드 해제 상태에서도)
- [ ] `Info.plist` 의 한글 문자열(`집중력`, 캘린더 권한 안내문)이 안 깨진다

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
