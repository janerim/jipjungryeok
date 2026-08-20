# 집중력 (Jipjungryeok)

원형 다이얼을 돌려 시간을 맞추고 집중하는 미니멀 타이머 앱. iPhone 전용, SwiftUI.

기획 전문은 [docs/spec.md](docs/spec.md).

---

## 현재 상태

| 마일스톤 | 내용 | 상태 |
|---|---|---|
| M0 | 프로젝트 골격 (XcodeGen + FocusCore + App Group + Asset Catalog) | 작성 완료 · **Mac 빌드 검증 대기** |
| M1 | 다이얼 & 타이머 코어 | 작성 완료 · **Mac 빌드 검증 대기** |
| M2 | 영속화 & 통계 | — |
| M3 | 알림 & 상태 복구 | — |
| M4 | 캘린더 연동 | — |
| M5 | 위젯 & Live Activity | — |
| M6 | Apple Watch (선택, 1차 릴리즈 이후) | — |

> ⚠️ 코드는 Windows 에서 작성하고 있고 Swift 툴체인이 없다.
> **컴파일·시뮬레이터 검증은 전부 Mac 단계에서 처음 이루어진다.** 첫 빌드에서
> 컴파일 에러가 몰려 나올 수 있다는 전제로 진행 중.

---

## Mac 에서 여는 법

```bash
brew install xcodegen     # 최초 1회
xcodegen generate
open Jipjungryeok.xcodeproj
```

`.xcodeproj` 는 생성물이라 git 에 들어 있지 않다. 프로젝트 구성을 바꿀 때는
Xcode GUI 가 아니라 [project.yml](project.yml) 을 고치고 `xcodegen generate` 를 다시 돌린다.

### 최초 1회 서명 설정

1. Xcode > `Jipjungryeok` 타겟 > Signing & Capabilities > Team 선택
2. `FocusWidgets` 타겟에도 동일 Team 선택
3. App Groups (`group.com.janerim.jipjungryeok`) 는 `project.yml` 이 이미 **양쪽 타겟에**
   선언해 두었으므로 손댈 필요 없다 (spec §13-1 의 사고 지점)

팀 ID 를 고정하고 싶으면 `project.yml` 의 `DEVELOPMENT_TEAM` 주석을 풀 것.

### 테스트

```bash
xcodebuild test -scheme Jipjungryeok -destination 'platform=iOS Simulator,name=iPhone 15'
```

또는 FocusCore 만:

```bash
cd FocusCore && swift test
```

---

## 구조

```
.
├── project.yml            # XcodeGen 프로젝트 정의 (유일한 소스 오브 트루스)
├── FocusCore/             # 로컬 Swift Package — 플랫폼 독립 로직 (§9)
│   ├── Sources/FocusCore/
│   │   ├── TimerEngine.swift   # 상태 전이 + 절대시각 계산 (§6)
│   │   ├── DialGeometry.swift  # 다이얼 각도 ↔ 분 변환 (§4.1)
│   │   ├── TimeDisplay.swift   # 시간 표기 규칙 (§4.1, §4.2)
│   │   ├── Models/             # RunningState, SessionRecord
│   │   └── DesignSystem/       # Palette, Typography, Metrics
│   └── Tests/FocusCoreTests/
├── Shared/                # 앱·위젯 두 타겟에 함께 컴파일되는 것
│   ├── Colors.xcassets/   # 디자인 토큰 6종 (라이트/다크)
│   └── AppGroup.swift     # App Group 식별자와 공유 저장소
├── Jipjungryeok/          # iOS 앱 타겟
│   ├── App/               # 진입점, RootView(3페이지), 햅틱, 페이지 인디케이터
│   └── Features/          # Timer(구현) / Stats·Settings(자리만)
└── FocusWidgets/          # 위젯 익스텐션 타겟
```

`project.yml` 의 소스는 경로 단위로 잡혀 있어서, 파일을 추가할 때 프로젝트 정의를
고칠 필요가 없다. Mac 에서 `xcodegen generate` 만 다시 돌리면 된다.

## 타이머 로직

시간 계산은 전부 [FocusCore/Sources/FocusCore/TimerEngine.swift](FocusCore/Sources/FocusCore/TimerEngine.swift)
에 있고, **현재 시각을 인자로 주입받는 순수 값 타입**이다. `Timer` 도 `Date()` 직접 호출도 없다.

덕분에 실제로 25분을 기다리거나 기기 시간대를 바꿔 보지 않고도 일시정지 누적,
앱 강제 종료 후 복귀, 시계 역행 같은 §12 수용 기준을 단위 테스트로 검증할 수 있다.
1초 `Timer` 는 앱 타깃의 `TimerViewModel` 에만 있고, 화면을 다시 그리라는 신호일 뿐이다.

**`FocusCore` 분리는 워치를 안 만들더라도 유지한다.** 타이머 로직을 앱 타겟 안에
넣어버리면 나중에 워치를 붙일 때 전부 뜯어내야 하고, 순수 로직 단위 테스트도 어려워진다.

## 식별자

| 대상 | 값 |
|---|---|
| iOS 앱 | `com.janerim.jipjungryeok` |
| 위젯 익스텐션 | `com.janerim.jipjungryeok.widgets` |
| App Group | `group.com.janerim.jipjungryeok` |

화면에 보이는 이름(`CFBundleDisplayName`)만 `집중력` 이고,
**타겟·폴더·파일명은 전부 영문 `Jipjungryeok`** 으로 유지한다 (한글 경로가 빌드 스크립트·CI 에서
인코딩 문제를 일으킬 수 있다).
