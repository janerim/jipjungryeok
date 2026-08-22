#!/bin/bash
# 실기기 빌드 준비 — Xcode 에 로그인한 개발자 팀 ID 를 찾아 project.yml 에 넣는다.
#
# 팀 ID 는 인증서의 OU(Organizational Unit) 필드에 들어 있다. 사람이 찾아 옮겨
# 적는 것보다 여기서 뽑는 편이 오타가 없다.
#
#   사용법:  ./scripts/setup-device-signing.sh
set -euo pipefail
cd "$(dirname "$0")/.."

echo "▸ 서명 인증서 확인"
if ! security find-identity -v -p codesigning 2>/dev/null | grep -q "Apple Develop"; then
  cat <<'MSG'
✗ 개발용 서명 인증서가 없습니다.

  Xcode > Settings(⌘,) > Accounts 에서 Apple ID 로 로그인한 뒤 다시 실행하세요.
  App Group(group.com.janerim.jipjungryeok)을 쓰므로 **유료 개발자 계정**이어야
  합니다. 무료 개인 팀은 App Groups Capability 를 쓸 수 없어 앱이 실행 즉시
  fatalError 로 죽습니다 (§13-1).
MSG
  exit 1
fi

echo "▸ 팀 ID 추출"
TEAM=$(security find-certificate -a -c "Apple Develop" -p 2>/dev/null \
  | openssl x509 -noout -subject 2>/dev/null \
  | grep -oE 'OU *= *[A-Z0-9]{10}' | head -1 | grep -oE '[A-Z0-9]{10}' || true)

if [ -z "${TEAM}" ]; then
  echo "✗ 인증서에서 팀 ID 를 찾지 못했습니다. project.yml 의 DEVELOPMENT_TEAM 을 직접 채우세요."
  exit 1
fi
echo "  팀 ID: ${TEAM}"

echo "▸ project.yml 갱신"
python3 - "$TEAM" <<'PY'
import pathlib, re, sys
team = sys.argv[1]
p = pathlib.Path("project.yml")
s = p.read_text(encoding="utf-8")
if re.search(r'^\s*DEVELOPMENT_TEAM:', s, re.M):
    s = re.sub(r'^(\s*)DEVELOPMENT_TEAM:.*$', rf'\g<1>DEVELOPMENT_TEAM: {team}', s, flags=re.M)
else:
    s = s.replace("    # DEVELOPMENT_TEAM: XXXXXXXXXX", f"    DEVELOPMENT_TEAM: {team}")
p.write_text(s, encoding="utf-8")
print(f"  DEVELOPMENT_TEAM: {team}")
PY

echo "▸ 프로젝트 재생성"
xcodegen generate >/dev/null
echo "  완료"

echo
echo "▸ 연결된 기기"
xcrun devicectl list devices 2>/dev/null | grep -iE "iphone|ipad" || echo "  (없음)"

cat <<'MSG'

다음 순서:
  1. iPhone 을 USB 로 연결하고 잠금을 해제한 뒤 "이 컴퓨터를 신뢰" 를 누르세요.
     위 목록에서 상태가 available 이어야 합니다.
  2. open Jipjungryeok.xcodeproj  →  좌상단에서 기기를 고르고 ⌘R
  3. 첫 실행 시 기기에서 거부되면:
     설정 > 일반 > VPN 및 기기 관리 > 개발자 앱 > 신뢰
MSG
