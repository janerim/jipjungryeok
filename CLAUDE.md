# CLAUDE.md

집중력(Jipjungryeok) — 원형 다이얼을 돌려 시간을 맞추고 집중하는 미니멀 타이머.
iPhone 전용, SwiftUI, 외부 라이브러리 없음.

**기획서가 유일한 사양이다: [docs/spec.md](docs/spec.md).** 아래 `§` 표기는 전부 그 문서의 절 번호다.
구현 판단이 갈릴 때는 추측하지 말고 해당 절을 먼저 읽을 것.

---

## 진행 상황

| 마일스톤 | 내용 | 상태 |
|---|---|---|
| M0 | 프로젝트 골격 | 완료 · 빌드 검증됨 |
| M1 | 다이얼 & 타이머 코어 | 완료 · 빌드 검증됨 |
| M2 | 영속화 & 통계 | 완료 · 빌드 검증됨 |
| M3 | 알림 & 상태 복구 | 미착수 |
| M4 | 캘린더 연동 | 미착수 |
| M5 | 위젯 & Live Activity | 미착수 |
| M6 | Apple Watch (선택, 1차 릴리즈 이후) | 미착수 |

각 마일스톤 범위는 §11, 완료 판정 기준은 §12.

첫 빌드 결과와 환경 설정에서 걸린 지점은 [docs/mac-first-build.md](docs/mac-first-build.md)
맨 위에 정리해 두었다. M3 이후 §12 눈 확인 항목은 아직 사람이 직접 봐야 하는 것들이 남아 있다.

---

## 명령

```bash
# 로직만 검증 (Xcode 프로젝트 없이 동작. 여기부터 돌릴 것)
cd FocusCore && swift test

# 프로젝트 생성 — .xcodeproj 는 추적하지 않는 생성물이다
xcodegen generate
open Jipjungryeok.xcodeproj

# 앱·위젯 빌드. 시뮬레이터 실행에는 ad-hoc 서명이 필요하다 —
# 서명이 빠지면 App Group entitlement 가 안 붙고 SessionStore 가 fatalError 로 즉사한다.
xcodebuild build -scheme Jipjungryeok \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  CODE_SIGN_IDENTITY="-" CODE_SIGN_STYLE=Manual
```

`brew install xcodegen` 이 선행돼야 한다.

`xcodebuild test` 는 **쓰지 않기로 했다.** 자동 테스트는 `swift test` 하나로 간다.
`FocusCoreTests` 는 로컬 패키지 안에 있어서 XcodeGen 이 스킴에 넣지 못하고(넣으면
generate 가 validation 에러로 죽는다), 스킴에 걸 앱 타겟 테스트 번들은 만들지 않는다.
이유는 아래 규칙 1.

---

## 구조와 규칙

```
project.yml       ← 프로젝트 정의의 유일한 소스 오브 트루스
FocusCore/        ← 로컬 Swift Package. 플랫폼 독립 순수 로직
Shared/           ← 앱·위젯 두 타겟에 함께 컴파일
Jipjungryeok/     ← iOS 앱 타겟
FocusWidgets/     ← 위젯 익스텐션 타겟
```

### 1. `FocusCore` 의 순수성을 깨지 말 것

`FocusCore` 는 **UIKit·SwiftData·EventKit·WidgetKit 을 import 하지 않는다.**
`Date()` 를 직접 호출하지도 않는다 — 현재 시각은 언제나 인자로 주입받는다.

이 규칙 덕분에 25분을 실제로 기다리거나 기기 시간대를 바꾸지 않고도 §12 수용 기준을
단위 테스트로 검증할 수 있다. 시간·집계 관련 로직을 화면 코드에 넣고 싶어지면
거의 항상 잘못된 판단이다.

**따라서 자동 테스트는 `FocusCore` 에만 둔다.** 앱 타겟용 테스트 번들은 만들지 않는다 —
거기서 검증할 `SessionStore`·`TimerViewModel`·`Haptics` 는 시뮬레이터가 떠 있어야
의미가 있어서, 얻는 것에 비해 굴리는 비용이 크다. 검증하고 싶은 로직이 생기면
**앱 타겟에 테스트를 붙이지 말고 그 로직을 `FocusCore` 로 옮긴다.** 그게 이 분리의 목적이다.
화면에서만 확인되는 것들(제스처, 다크모드, 위젯)은 테스트 대상이 아니라 §12 눈 확인 항목이다.

들어가는 것: `TimerEngine`, `DialGeometry`, `StatsCalculator`, `TimeDisplay`,
모델(값 타입), 디자인 토큰.
들어가지 않는 것: 화면, 제스처, 저장소, 캘린더, 위젯, 햅틱.

워치(§8-1)를 1차에서 제외했어도 이 분리는 유지한다.

### 2. 시간 계산은 절대시각으로만 (§6-1)

```swift
남은 시간 = plannedSeconds - (now - startAt) + accumulatedPauseSeconds
```

1초 `Timer` 는 화면을 다시 그리라는 신호일 뿐이다. **절대로 `remaining -= 1` 로
누적하지 않는다.** 앱이 죽어 있던 동안에도 값이 맞아야 한다.

완료 시각은 `now` 가 아니라 `expectedEndDate` 로 기록한다. 백그라운드에서 끝난
세션이 3시간짜리로 캘린더에 남으면 안 된다.

### 3. 통계 날짜 판정은 언제나 `startAt` 기준 (§4.2)

23:50 에 시작해 00:15 에 끝난 세션은 **전부 시작일에 귀속**되며 두 날에 나눠
배분하지 않는다. 차트·회고·시간 요약 전부 같은 규칙이다.

주는 **월요일**에 시작한다(§1-1). `Calendar.current` 를 그대로 쓰면 기기 지역 설정에
따라 일요일 시작으로 바뀌므로 항상 `Calendar.focus` 를 쓴다. 날짜 테스트는 시간대를
`Asia/Seoul` 로 못박는다 — 안 그러면 다른 기기에서 하루씩 어긋난다.

### 4. 색은 Asset Catalog 를 통해서만 (§10)

`Palette.ink` 처럼 토큰으로만 참조한다. **하드코딩된 hex 나 `.gray`, `.black` 같은
시스템 색을 쓰지 않는다.** 그림자 색도 마찬가지다.

`.preferredColorScheme` 을 지정하지 않는다. 시스템 설정을 그대로 따른다.
테마 선택 기능은 만들지 않는다.

Color Set 은 `Shared/Colors.xcassets` 에 있고 `project.yml` 이 앱·위젯 **양쪽**
타겟에 넣는다. 여기서 한쪽이 빠지면 다크모드에서 위젯 색이 깨진다(§13-4).

### 5. 설정을 늘리지 말 것 (§2, §3)

기획서의 "제외" 목록은 강한 제약이다. 테마 선택, 알림음 선택, 배경음악, 세션 종류,
태그, 로그인, 서버, 결제 — 요청받지 않는 한 만들지 않는다.
세션은 "집중" 하나뿐이며 휴식/포모도로 사이클 개념이 없다.

### 6. 파일·타겟명은 영문, 화면 문자열만 한글 (§1-1)

`CFBundleDisplayName` 만 `집중력` 이다. 폴더·파일·타겟은 전부 `Jipjungryeok`.
한글 경로는 빌드 스크립트·CI 에서 인코딩 문제를 일으킨다.

**테스트 메서드명도 영문으로 쓴다.** XCTest 가 ObjC 런타임으로 테스트를 찾기 때문에
비ASCII 셀렉터가 문제될 수 있다. 설명은 메서드 주석에 한글로 남긴다.

### 7. 주석은 "왜" 를 적는다

이 코드베이스의 주석은 무엇을 하는지가 아니라 **왜 그렇게 했는지, 안 그러면 무엇이
깨지는지**를 적는다. 기존 밀도와 문체를 맞출 것. 주석은 한글.

### 8. 프로젝트 구성은 `project.yml` 에서만 바꾼다

`.xcodeproj` 는 `.gitignore` 에 있는 생성물이다. Xcode GUI 에서 타겟 설정을 바꾸면
다음 `xcodegen generate` 에 날아간다. 소스는 경로 단위로 잡혀 있어서 **파일 추가만
하는 경우에는 `project.yml` 을 고칠 필요가 없다.**

---

## 식별자

| 대상 | 값 |
|---|---|
| iOS 앱 | `com.janerim.jipjungryeok` |
| 위젯 익스텐션 | `com.janerim.jipjungryeok.widgets` |
| App Group | `group.com.janerim.jipjungryeok` |

App Groups Capability 는 **앱·위젯 양쪽 모두**에 필요하다(§13-1). `project.yml` 이
두 타겟에 각각 선언하고 있으니 GUI 에서 손대지 말 것.
