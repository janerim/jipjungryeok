# 다음에 Mac 에서 할 일

> 2026-10-02 Windows 에서 작성. **아래 코드는 아직 한 번도 컴파일하지 않았다.**
> 할 일이 끝나면 이 파일을 지우거나 다음 할 일로 바꾼다.

## 들어온 것

| 브랜치 | 커밋 | 내용 |
|---|---|---|
| `main` · `ios15` | `594fef2` · `a4f2af6` | 회고 시트가 떠 있을 때 화면을 껐다 켜도 연장이 유지되게 (§6-7) |
| `main` · `ios15` | `9c92a80` · `8a1a150` | **1.3** — 설정 > 기록 옮기기 [내보내기] [가져오기] (§4.3), 버전 1.3 (4) |

두 브랜치의 코드는 같다. `ios15` 는 저장소 줄 하나만 Core Data 문법이다.

---

## 1. 받기 + 테스트 (두 브랜치 다)

```bash
git fetch
git switch main  && git pull && (cd FocusCore && swift test)
git switch ios15 && git pull && (cd FocusCore && swift test)
```

- 새 테스트 `SessionArchiveTests` 12개가 늘었다. 둘 다 전부 통과해야 한다.
- `ios15` 는 macOS 12 기준으로 빌드하므로, iOS 16+ API 를 썼다면 여기서 걸린다.
- **실패하면 여기서 멈추고** 에러 원문을 가져온다.

## 2. 6s — `ios15` 설치

```bash
git switch ios15
./scripts/install-ios15.sh      # 6s 를 USB 로 연결하고 잠금 해제한 상태에서
```

6s 에서 확인할 것:

- [ ] 앱을 열면 "새로워진 점 · 버전 1.3" 시트가 뜬다
- [ ] **연장 고침**: 1분 세션을 끝까지 → `1분 집중 중` 시트 → 옆 버튼으로 화면 껐다 켜기
      → 문구가 `저장을 누르면 여기까지 기록됩니다` 그대로다 (전에는 종료 시각으로 바뀌었다)
- [ ] 설정 > 기록 옮기기 > **내보내기** → 공유 시트 → **AirDrop 으로 이 Mac** 에 보낸다
      → `~/Downloads/jipjungryeok-YYYYMMDD.json` 이 생긴다 (3번에서 쓴다)

## 3. iPhone 17 쪽 — `main` 을 **시뮬레이터**로 확인

> **실기기 iPhone 17 에는 깔지 말 것.** 진짜 기록이 든 스토어판이 있다. 그 위에 개발 빌드를
> 덮었을 때 기록이 남는지는 확인된 적이 없다. 1.3 이 스토어로 나간 뒤 업데이트로 받는다.

```bash
git switch main
xcodegen generate
open Jipjungryeok.xcodeproj     # iPhone 17 시뮬레이터 선택 → ⌘R
```

- [ ] 시뮬레이터에서 세션을 하나 끝내 둔다 (기록이 섞이는 것을 보려고)
- [ ] 2번에서 받은 json 을 **시뮬레이터 창에 끌어다 놓아** "파일" 에 넣는다
      ⚠️ 이 방법은 확인하지 않았다. 안 되면 시뮬레이터 안에서 내보내기 → "파일에 저장" →
      그 파일을 가져오기로 대신한다. 자기 기록이라 전부 "새 기록이 없습니다" 가 나와야 정상이다
- [ ] 설정 > 기록 옮기기 > **가져오기** → 그 파일 → "N건을 가져왔습니다"
- [ ] 통계(오늘 링·이번 주)와 기록 시트에 6s 세션이 보이고, 시뮬레이터 세션도 그대로 있다
- [ ] **같은 파일을 한 번 더** 가져오면 "새 기록이 없습니다", 통계가 늘지 않는다
- [ ] 캘린더 기록을 켠 상태에서 가져와도 **캘린더에 일정이 새로 생기지 않는다**
- [ ] 이 앱이 만들지 않은 json 을 고르면 "집중력에서 내보낸 기록 파일이 아닙니다", 기록은 그대로

나머지 항목은 [docs/mac-first-build.md](docs/mac-first-build.md) 의 "기록 옮기기 (1.3, §4.3)".

## 4. 1.3 스토어 업로드 (`main`)

버전(1.3 / 빌드 4), `ReleaseNotes`, 스토어 문구는 **이미 고쳐 두었다.** CLAUDE.md "새 버전 낼 때" 의 4단계만 남았다.

```bash
git switch main
(cd FocusCore && swift test)
xcodegen generate
open Jipjungryeok.xcodeproj     # Product > Archive → Organizer 에서 업로드
```

- App Store Connect "이번 버전의 새로운 기능" 에는
  [docs/appstore-metadata.md](docs/appstore-metadata.md) 의 1.3 블록을 그대로 붙인다.
- 개인정보 처리방침에 "기록 내보내기" 절을 추가했다([docs/privacy.md](docs/privacy.md)).
  시행일은 **2026-10-06 으로 바꿨다.** 그 문서의 "방침 변경" 절이 내용이 바뀌면 시행일을
  고치겠다고 약속하고 있고, 기기 밖으로 기록이 나가는 길이 새로 생긴 것은 실질적인 변경이다.
  **라이브 페이지는 손댈 것이 없다.** 처리방침은 GitHub Pages 가 `main` 의 `/docs` 에서
  자동으로 게시한다(`https://janerim.github.io/jipjungryeok/privacy`). 푸시하면 끝이다.
  Notion 에 있는 것은 **지원 URL** 뿐이고 그건 손으로 고쳐야 한다 — 1.3 에서 바뀔 내용은 없다.
- 앱 개인정보 표기는 "데이터를 수집하지 않음" 그대로다. 사용자가 직접 보내는 파일은 수집이 아니다.

## 5. 1.3 이 iPhone 17 에 깔린 뒤

- [ ] iPhone 17 에서 내보내기 → AirDrop → 6s 에서 "파일" 에 저장 → 가져오기 (반대 방향)
- [ ] 6s → iPhone 17 방향도 한 번 더 (실기기끼리)
- [ ] 두 폰의 통계가 같아졌는지

---

## 막혔을 때 가져올 것

1. 어느 번호에서 멈췄는지
2. 에러 원문 — `swift test`·`xcodebuild` 출력, 6s 는 `idevicesyslog -m Jipjungryeok`
   ([docs/ios15-branch.md](docs/ios15-branch.md) 3장)
3. 위 체크 항목 중 실패한 것
