# 다음에 Mac 에서 할 일

> 2026-11-03 Windows 에서 작성. 이전 판(1.3 업로드 순서)은 끝났다 — 1.3 은 10월 7일 스토어에 나갔다.
> 이번 판은 **책력·집중력을 "력 시리즈" 로 맞추는 일**이고, 두 저장소에 걸쳐 있다.
> **아무것도 빌드해 보지 않았다.** 할 일이 끝나면 이 파일을 지우거나 다음 할 일로 바꾼다.

## 들어온 것

| 저장소 | 커밋 | 내용 |
|---|---|---|
| jipjungryeok `main` | `eb43c95` | 스토어 문구 — 공통 문장, 광고·계정 약속 빼기 |
| jipjungryeok `main` | `1809476` | 앱 아이콘 교체 (라이트·다크). 틀과 색 값은 [spec §10](docs/spec.md) "앱 아이콘" |
| chaekryeok `main` | `af212fd` | iOS 앱 아이콘 (라이트·다크), `app.json` 의 `ios.icon` 으로 연결 |

`ios15` 브랜치에는 넣지 않았다. 6s 는 옛 아이콘 그대로다.

아이콘 PNG 는 SVG 를 Chrome 으로 렌더한 뒤 24bit PNG(1024², 알파 없음)로 저장했다.
SVG 원본은 저장소에 두지 않는다(§10) — 다시 그려야 하면 §10 의 값에서 출발한다.

### 이번에 정한 것

- **메인 화면은 달력으로 바꾸지 않는다.** 책력(冊曆)의 력은 달력이지만 집중력의 력은 力이고,
  앱을 여는 이유가 "바로 시작" 이다. 시리즈의 공통점은 화면 안이 아니라 **아이콘과 스토어 문구**에서 낸다
- **아이콘 틀 "종이와 잉크"**: `paper` 크림 바탕 + 잉크색 상징 하나 + 앱마다 포인트 색 하나, 글자 없음.
  이전 집중력 아이콘은 "밝은 아이콘은 홈 화면에서 묻힌다" 는 이유로 어두운 바탕이었다(`6272ebf`).
  그걸 알고 뒤집었다 — 1번에서 눈으로 확인할 것
- **공통 문장**: "하루하루가 쌓여 기록이 됩니다." 계정·광고 없음은 내세우지 않는다.
  나중에 수익 모델을 붙이면 거짓이 되는 약속이다
- **개발자 이름**은 개인 계정이라 법적 이름(`jeongrim oh`)으로 고정이다. 번들 ID 와는 관계없다.
  두 앱은 이미 같은 개발자로 묶여 스토어의 "다른 앱" 에 서로 뜬다

---

## 1. 집중력 — 받기 + 아이콘 확인

```bash
cd jipjungryeok
git switch main && git pull
(cd FocusCore && swift test)     # 코드는 안 바뀌었다. 습관대로
xcodegen generate
open Jipjungryeok.xcodeproj      # iPhone 17 시뮬레이터 → ⌘R
```

> 실기기 iPhone 17 에는 깔지 않는다. 진짜 기록이 든 스토어판이 있다.

- [ ] 홈 화면 아이콘이 크림 바탕 + 잉크 다이얼 + 주황 핸들이다
- [ ] 홈 화면 길게 누르기 > 편집 > 사용자화 > **어둡게** 에서 짙은 바탕 + 크림 다이얼로 바뀐다
- [ ] **밝은 배경화면에서 묻히지 않는다.** 이전 결정을 뒤집은 지점이라 꼭 본다.
      묻히면 "반전안"(라이트에서도 짙은 바탕)으로 돌아가는 선택지가 있다 — 시안 캔버스의 "(가) 반전"

## 2. 책력 — 받기 + 아이콘 확인

```bash
cd chaekryeok
git pull
npm install
npx expo prebuild --clean --platform ios   # ios/ 는 커밋하지 않는 생성물이라 지워도 된다
npm run ios                                # expo run:ios → 시뮬레이터
```

- [ ] prebuild 가 `ios.icon` 의 `{ light, dark }` 객체를 받아들인다.
      Expo 문서상 SDK 54 에서 지원하지만 **이 저장소에서는 처음 쓴다.** 에러가 나면 원문을 가져온다
- [ ] 생성된 `ios/*/Images.xcassets/AppIcon.appiconset/Contents.json` 에 dark 항목이 있다
- [ ] 시뮬레이터 홈 화면에서 라이트·다크 아이콘이 둘 다 맞게 나온다
- [ ] 집중력과 나란히 놓고 한 벌로 보인다
- 스플래시는 옛 그림(`app-icon.png`) 그대로인 게 맞다. 아래 "남은 결정" 2번

## 3. App Store Connect — 빌드 없이 지금 할 수 있는 것

프로모션 텍스트는 새 버전 없이 바로 바뀐다.

- [ ] 집중력 프로모션 텍스트 ← [docs/appstore-metadata.md](docs/appstore-metadata.md) 프로모션 블록 그대로
- [ ] 책력 프로모션 텍스트에 "하루하루가 쌓여 기록이 됩니다." 를 넣는다.
      책력 저장소에는 스토어 문구 문서가 없어서 직접 넣는다

## 4. 다음 버전에 실어 보내기

아이콘·설명·부제는 새 버전을 제출할 때만 바뀐다.

**집중력 1.4** — CLAUDE.md "새 버전 낼 때" 순서대로

- [ ] `project.yml` 의 `MARKETING_VERSION` 1.4 / `CURRENT_PROJECT_VERSION` 5 (지금 1.3 / 4, 두 타깃 다)
- [ ] `ReleaseNotes.swift` — 아이콘만 바뀐 릴리즈면 비워 둘지 정한다(비우면 앱 안 업데이트 안내가 안 뜬다)
- [ ] [docs/appstore-metadata.md](docs/appstore-metadata.md) — "이번 버전의 새로운 기능" 1.4 블록,
      "버전" 줄(아직 `1.2` 로 남아 있다)
- [ ] App Store Connect 설명 ← 문서의 설명 블록 통째로 (이번에 바뀌었다)
- [ ] `swift test` → archive → Organizer 업로드

**책력 1.0.4**

- [ ] `app.json`·`package.json` 의 `version` 1.0.4 (빌드 번호는 EAS 가 원격으로 올린다)
- [ ] `RELEASE_NOTES.md` 에 1.0.4
- [ ] `eas build --profile production --platform ios` → `eas submit --profile production --platform ios`

## 5. 이전 판에서 넘어온 것

1.3 이 나간 뒤 실기기끼리 해 보기로 한 확인이다. 했다면 지운다.

- [ ] iPhone 17 → 6s, 6s → iPhone 17 양쪽으로 기록 내보내기·가져오기, 두 폰 통계가 같아지는지

---

## 남은 결정

1. **부제** — 두 앱 다 비어 있다. 예: 책력 "나만의 독서 달력" / 집중력 "나만의 집중 타이머"
2. **책력의 나머지 아이콘** — 스플래시·Android 적응형 아이콘·웹 파비콘은 옛 `app-icon.png` 다.
   Android 로 출시했는지에 따라 맞출지 정한다
3. **틴트 아이콘**(iOS 18+) — 두 앱 다 없다
4. **`ios15` 브랜치**(6s)에도 새 아이콘을 넣을지
5. **집중력 1.4** 를 아이콘만으로 낼지, 다음 기능과 묶을지

## 발견만 하고 손대지 않은 것

- [docs/appstore-metadata.md](docs/appstore-metadata.md) "저작권" 줄은 `2026 오정림` 인데,
  스토어에는 두 앱 다 `© 2026 ryubi` 로 나간다. 문서를 스토어에 맞출지
- 두 앱 다 스토어 "언어" 가 **영어** 로 나온다(한국어 앱인데). 원인 미확인 — 개발 지역이 en 일 가능성
- spec §1-1 "로마자는 책력(`chaekryeok`)과 같은 철자 기반" — 책력의 실제 식별자는 `chaengnyeok`(발음 기반)이다

## 참고

- 아이콘 시안 캔버스: https://claude.ai/artifact/6CNkCVe7YnR6MjByYGmfDf
  **다듬기 전 시안이다.** 최종본은 저장소의 PNG, 값은 spec §10

## 막혔을 때 가져올 것

1. 어느 번호에서 멈췄는지
2. 에러 원문 — `swift test`·`xcodebuild`·`expo prebuild` 출력
3. 위 체크 항목 중 실패한 것, 아이콘이 이상하면 홈 화면 스크린샷
