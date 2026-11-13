#!/usr/bin/env bash
# Build Release Trace.app and replace /Applications/Trace.app (local dogfood).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$ROOT/app"
DERIVED="$ROOT/build/DerivedData"
APP_SRC="$DERIVED/Build/Products/Release/Trace.app"
APP_DST="/Applications/Trace.app"

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "xcodegen required. brew install xcodegen" >&2
  exit 1
fi

killall Trace 2>/dev/null || true

cd "$APP_DIR"
xcodegen generate
xcodebuild \
  -project Trace.xcodeproj \
  -scheme Trace \
  -configuration Release \
  -derivedDataPath "$DERIVED" \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_ALLOWED=YES \
  build

if [[ ! -d "$APP_SRC" ]]; then
  echo "Trace.app not found at $APP_SRC" >&2
  exit 1
fi

rm -rf "$APP_DST"
cp -R "$APP_SRC" "$APP_DST"
xattr -dr com.apple.quarantine "$APP_DST" 2>/dev/null || true
open -a "$APP_DST"
echo "Installed and launched $APP_DST"
