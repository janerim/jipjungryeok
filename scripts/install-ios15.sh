#!/bin/bash
# ios15 브랜치 — 6s 에 빌드해서 설치한다.
#
# Xcode GUI 의 ⌘R 을 대신한다. macOS 26(Tahoe)에서 Xcode 16 GUI 가 실행을 거부하고,
# Xcode 27 에는 iOS 15 DeviceSupport 가 없어서 기기를 아예 보지 못하기 때문이다.
# 자세한 경위는 docs/ios15-branch.md 2장.
#
# 빌드·서명은 Xcode 27 이 한다(iOS 15.0 배포 타깃을 정식 지원한다).
# 설치만 libimobiledevice 가 USB 로 직접 한다 — 설치에는 DeveloperDiskImage 가 필요 없다.
#
#   $ ./scripts/install-ios15.sh
set -euo pipefail

cd "$(dirname "$0")/.."

command -v xcodegen >/dev/null || { echo "xcodegen 이 없다: brew install xcodegen"; exit 1; }
command -v ideviceinstaller >/dev/null || { echo "ideviceinstaller 가 없다: brew install ideviceinstaller"; exit 1; }

UDID="$(idevice_id -l | head -1)"
[ -n "$UDID" ] || { echo "기기가 안 보인다. USB 로 연결하고 잠금을 해제할 것."; exit 1; }
echo "기기: $UDID ($(ideviceinfo -k ProductVersion 2>/dev/null))"

echo "== 프로젝트 생성 =="
xcodegen generate >/dev/null

echo "== 빌드·서명 =="
# -allowProvisioningUpdates 로 프로파일을 받아온다. 6s 는 Xcode 27 에 보이지 않으므로
# 자동 등록(-allowProvisioningDeviceRegistration)이 되지 않는다. UDID 를 개발자 포털에
# 미리 등록해 둬야 프로파일에 들어간다 — docs/ios15-branch.md 2장.
xcodebuild build -scheme Jipjungryeok \
  -destination 'generic/platform=iOS' \
  -allowProvisioningUpdates \
  | grep -E "^\*\* |error: " || true

APP_DIR="$(xcodebuild -showBuildSettings -scheme Jipjungryeok -destination 'generic/platform=iOS' 2>/dev/null \
  | grep -m1 " BUILT_PRODUCTS_DIR" | sed 's/.*= //')"
APP="$APP_DIR/Jipjungryeok.app"
[ -d "$APP" ] || { echo "빌드 결과가 없다: $APP"; exit 1; }

# 프로파일에 이 기기가 없으면 설치는 되지만 실행이 거부된다. 먼저 걸러 낸다.
security cms -D -i "$APP/embedded.mobileprovision" -o /tmp/jjr-profile.plist 2>/dev/null
python3 - "$UDID" <<'PY'
import plistlib, sys
devices = plistlib.load(open('/tmp/jjr-profile.plist','rb')).get('ProvisionedDevices') or []
if sys.argv[1] not in devices:
    sys.exit(f"프로파일에 이 기기가 없다. developer.apple.com 에 UDID 를 등록할 것:\n  {sys.argv[1]}")
PY

echo "== 설치 =="
ideviceinstaller install "$APP"
echo "완료. 6s 홈 화면에서 실행할 것."
