#!/usr/bin/env bash
# Build Trace.app and wrap an unsigned local dogfood DMG (ADR-0008).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$ROOT/app"
BUILD_DIR="${TRACE_BUILD_DIR:-$ROOT/build/dmg}"
DERIVED="$BUILD_DIR/DerivedData"
STAGE="$BUILD_DIR/stage"
DMG_PATH="$BUILD_DIR/Trace-dogfood.dmg"

mkdir -p "$BUILD_DIR" "$STAGE"
rm -rf "$STAGE"/* "$DMG_PATH"

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "xcodegen required. brew install xcodegen" >&2
  exit 1
fi

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

APP="$(find "$DERIVED/Build/Products/Release" -maxdepth 1 -name 'Trace.app' -print -quit)"
if [[ -z "$APP" || ! -d "$APP" ]]; then
  echo "Trace.app not found after build" >&2
  exit 1
fi

cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"

hdiutil create \
  -volname "Trace" \
  -srcfolder "$STAGE" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

echo "DMG ready: $DMG_PATH"
echo "Open the DMG, drag Trace to Applications, then launch from the menu bar."
