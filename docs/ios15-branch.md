# ios15 브랜치 — 아이폰 6s 설치 가이드

아이폰 6s(마지막 지원 버전이 iOS 15)에 직접 설치하기 위한 브랜치다.
**스토어에 올리지 않는다.** 스토어판은 `main`(iOS 17)이고, 이 브랜치는 `main` 에 합치지 않는다.

> 2026-09-28, 6s(iOS 15.8.8)에서 **실행과 4장 체크리스트를 확인했다.**
> 설치는 Xcode GUI 가 아니라 `./scripts/install-ios15.sh` 로 한다 — 사유는 2장.

---

## 1. `main` 과 다른 점

### 빠진 기능

- Live Activity / Dynamic Island (iOS 16.1+)
- 잠금화면 위젯 (iOS 16+)
- 다이얼 스냅 햅틱 — 코드는 그대로다. 6s 의 진동 모터가 이 API 를 지원하지 않을 뿐이다.

### 동작은 같지만 모양이 다른 것

| 항목 | `main` | `ios15` |
|---|---|---|
| 설정 > 기본 시간 | 가로 스크롤 | 시스템 휠 피커 (소리 남) |
| 메모·새로운 기능 시트 | 짧은 시트 | 전체 높이 시트 |
| 메모 입력칸 | 4~6줄로 늘어남 | 한 줄 (긴 메모는 옆으로 흐름) |
| 캘린더 권한 | 쓰기 전용 → 선택 시 전체 | 처음부터 전체 접근 하나 |
| 타이머 숫자·오늘 링 숫자 | 숫자 굴림 애니메이션 | 굴림 없음 |

### 속만 바뀐 것

- 저장소: SwiftData → **Core Data** (`FocusSession.swift`, `SessionStore.swift`)
  - 저장 파일 이름: `Jipjungryeok-ios15.sqlite` (`main` 은 `Jipjungryeok.store`)
- 상태 관리: `@Observable` → `ObservableObject` + `@Published`

---

## 2. Mac 에서 할 순서

> 아래는 **2026-09-28 에 실제로 성공한 절차다.** 처음 적어 둔 "Xcode 로 열어 ⌘R" 은
> 더 이상 쓸 수 없다. 왜 그런지는 바로 아래 "Xcode 두 개가 필요한 이유" 에 적었다.

```bash
git switch ios15

# ① 로직 테스트. macOS 12 기준으로 빌드하므로 iOS 16+ API 를 쓰면 여기서 걸린다.
cd FocusCore && swift test && cd ..

# ② 6s 를 USB 로 연결 → 잠금 해제 → "이 컴퓨터를 신뢰"
#    잠겨 있으면 "Failed to prepare the device for development" 로 막힌다.
idevice_id -l        # UDID 가 나오면 붙은 것

# ③ 빌드 → 서명 → 설치 (⌘R 을 대신한다)
./scripts/install-ios15.sh
```

④ 6s 홈 화면에서 **집중력** 실행

- 유료 개발자 계정 + 정식 개발 프로파일이면 **"신뢰하지 않은 개발자" 가 뜨지 않고 바로 켜진다.**
  뜬다면 **설정 > 일반 > VPN 및 기기 관리 > 개발자 앱 > 신뢰** 로 간다.
  그 메뉴 항목은 **앱을 한 번 실행하려다 막혀야** 생긴다 — 미리 찾아봐도 없다.
- iOS 15 에는 **개발자 모드 설정이 없다**(iOS 16 부터). `mac-first-build.md` 의 "개발자 모드 켜기"는 건너뛴다.
- 첫 실행은 **Wi-Fi 가 켜진 상태에서** 한다. 개발자 인증서 확인에 네트워크가 필요할 수 있다.

### 6s 를 개발자 계정에 등록해 두어야 한다 (최초 1회)

Xcode 27 은 6s 를 **보지 못하므로** 기기를 자동 등록해 주지 못한다.
[developer.apple.com/account/resources/devices/list](https://developer.apple.com/account/resources/devices/list)
에서 UDID 를 직접 넣는다. UDID 는 `idevice_id -l` 로 얻는다.

등록하지 않으면 설치는 성공하는데 **실행만 거부된다.** 증상이 "설치는 됐는데 안 켜짐" 이라
원인을 찾기 어렵다. `install-ios15.sh` 가 설치 전에 프로파일을 열어 이걸 먼저 확인한다.

### Xcode 두 개가 필요한 이유 — 그리고 결국 하나로 된 이유

macOS 26(Tahoe) 위에서 이 둘이 **서로 다른 쪽이 빠져 있다.**

| | 빌드용 SDK | iOS 15 기기와 대화 | GUI |
|---|---|---|---|
| Xcode 27 | ✅ iOS 15.0 배포 타깃 정식 지원 | ❌ `DeviceSupport/` 가 아예 없다 | ✅ |
| Xcode 16.4 | ❌ `iPhoneOS18.5.sdk` 가 **0바이트 스텁** | ✅ `DeviceSupport/15.0~15.5` | ❌ Tahoe 가 실행을 거부 |

Xcode 16 의 SDK 는 `xcodebuild -downloadPlatform iOS` 로 약 7GB 를 따로 받아야 채워진다.
보통 GUI 첫 실행 때 받아지는데 그 GUI 가 막혀 있다. **그런데 받아 봐야 소용이 없다** —
iOS 15 기기에 설치하는 공개 CLI 가 Xcode 에 없기 때문이다(`devicectl` 은 iOS 17+ 전용,
나머지는 GUI 가 내부 API 로 한다). 즉 **어느 쪽이든 서드파티 설치 도구가 필요하다.**

그래서 Xcode 16 을 버리고 이렇게 나눴다.

- **빌드·서명**: Xcode 27. `iPhoneOS.sdk` 의 `MinimumDeploymentTarget` 이 15.0 이라 정식 지원이다.
  결과 바이너리는 `arm64` / `minos 15.0` 으로 나온다.
- **설치**: `ideviceinstaller`(libimobiledevice). USB 로 직접 붙는다.
  **설치에는 DeveloperDiskImage 가 필요 없다** — 그건 디버깅·실행 제어용이다.

대가는 **Xcode 콘솔 로그와 디버거를 못 쓰는 것**이다. 4장 체크리스트가 전부 기기에서
눈으로 보는 항목이라 지장이 없고, 튕기는 경우에는 아래 3장의 로그 수집으로 대신한다.

> ⚠️ **Xcode 16 의 명령줄 도구를 돌리면 시스템 공용 부품이 그쪽 버전으로 내려앉는다.**
> `CoreSimulator`·`CoreDevice` 가 덮여서 그 뒤로 **Xcode 27 이 시뮬레이터도 실기기도 못 본다**
> (`CoreSimulator is out of date`, `DVTCoreDeviceCore ... Symbol not found`).
> 실제로 이걸 겪었다. 복구는 `sudo xcodebuild -runFirstLaunch` 한 번이다.
> **Xcode 16 은 아예 건드리지 않는 것이 맞다.**

---

## 3. 실제로 걸렸던 것 / 걸릴 수 있는 것

### 실제로 걸린 것은 하나뿐이었다

Windows 에서 쓴 코드는 **첫 빌드에 그대로 통과했다.** 아래 하나만 고쳤다.

**`Palette.assetName` 의 `String + Substring`** — Swift 6.1(Xcode 16)이
`Collection.dropFirst()`(→`Substring`) 가 아니라 `Sequence.dropFirst()`(→`DropFirstSequence<String>`)
를 골라서 `+` 가 막혔다. `String(...)` 으로 감싸 해결했다. 최신 툴체인은 알아서 푼다.

걱정했던 `#Preview` 매크로, Core Data, deprecated API 는 **전부 그냥 통과했다.**
`@NSManaged var plannedSeconds: Int` 도 Integer 64 모델과 문제없이 맞물렸다.

### 안 걸린 것을 기록해 두는 이유

실행되는 것만으로 큰 위험 셋이 한꺼번에 통과한다. 다음에 뭔가 바꿨을 때
**앱이 켜지기만 해도** 아래가 멀쩡하다는 뜻이다.

- Core Data 스토어가 열렸다 — 못 열면 `fatalError` 로 즉사한다
- App Group 이 붙었다 — 안 붙으면 `AppGroup.defaults` 에서 역시 즉사한다
- SwiftUI 화면이 iOS 15 에서 그려진다

### 튕기거나 이상할 때 로그 뽑기

```bash
# 실행 중 로그 (앱 이름으로 걸러서)
idevicesyslog -m Jipjungryeok

# 크래시 리포트 — DIRECTORY 는 위치 인자다. -f 는 이름 필터지 경로가 아니다
mkdir -p /tmp/jjr-crash
idevicecrashreport -k -e /tmp/jjr-crash
```

- `timeout` 은 macOS 에 없다. 시간을 끊으려면 `gtimeout`(coreutils)을 쓰거나 직접 종료한다.
- 기기가 빠져 있으면 `No device found` 만 찍힌다. 로그가 비어 있으면 연결부터 확인할 것.

---

## 4. 6s 에서 확인할 것

### 핵심 (여기가 깨지면 쓸 수 없다)

- [ ] 앱이 켜지고 다이얼이 보인다
- [ ] 다이얼로 시간을 맞추고 숫자를 탭해 시작 → 일시정지 → 재개 → 중지
- [ ] 세션을 1분 넘게 돌리고 중지 → 메모 시트가 뜨고 저장된다
- [ ] **앱을 완전히 종료했다가 다시 켜도 기록이 남아 있다** (Core Data 저장 확인)
- [ ] 세션 도중 앱을 종료했다가 켜면 이어서 돈다 (상태 복구)
- [ ] 통계 화면의 오늘 링·이번 주 막대에 방금 세션이 반영된다

### iOS 15 로 바뀐 부분

- [ ] 설정 > 기본 시간 휠을 돌리면 값이 바뀌고, 타이머 화면 다이얼도 따라간다
- [ ] 메모 시트가 전체 높이로 뜨고 내용이 위쪽에 붙어 있다. 키보드가 입력칸을 가리지 않는다
- [ ] 설정 > 캘린더 기록 켜기 → 권한 팝업 → 허용 → "기록할 캘린더" 메뉴가 바로 보인다
- [ ] 세션을 끝내면 캘린더에 `🎯 집중` 일정이 생긴다
- [ ] 홈 화면 위젯(작은 것·중간 것)을 추가하면 배경색이 꽉 차고, 가장자리에 여백이 있다
- [ ] 색 테마 3종과 다크모드에서 글자가 다 읽힌다

### 오프라인

- [ ] 비행기 모드에서 세션을 시작하고 끝내면 기록되고, 무음 완료 알림이 뜬다

---

## 5. 유지 관리

- **서명은 1년짜리다.** 만료되면 앱이 실행 즉시 꺼진다. Mac 에 연결해
  `./scripts/install-ios15.sh` 를 다시 돌리면 덮어 설치되고 **기록은 남는다.**
  앱을 삭제하면 기록도 함께 지워지니 삭제하지 말 것.
- 코드를 고쳤을 때도 같은 스크립트 하나면 된다. 덮어 설치라 기록이 유지된다.
- `main` 에 새 기능이 생겨도 이 브랜치에는 자동으로 들어오지 않는다. 필요하면 골라서 옮긴다.
- 버전 번호는 `main` 과 같은 `project.yml` 값을 그대로 쓴다. 이 브랜치로 업로드하지 않는다.

---

## 6. 막혔을 때 가져올 것

첫 빌드는 2026-09-28 에 끝났고 4장 체크리스트도 통과했다. 이후에 막히면 아래를 붙인다.

1. 어느 단계에서 멈췄는지 (`swift test` / 빌드 / 설치 / 실행)
2. 에러 메시지 원문. 빌드는 `xcodebuild` 출력, 실행은 3장의 `idevicesyslog`·크래시 리포트
3. 4장 체크리스트 중 실패한 항목
