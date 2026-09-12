#!/usr/bin/env bash
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"
MODE="${1:-run}"
case "$MODE" in
  run|--build|--probe|--self-test|--shader-check) ;;
  *) echo "usage: $0 [--build|--probe|--self-test|--shader-check]" >&2; exit 2 ;;
esac
if [ "$MODE" = "--self-test" ]; then
  exec swift test
fi
swift build -c release
BUILD_DIR="$(swift build -c release --show-bin-path)"
APP_NAME="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleName' "$PROJECT_DIR/Info.plist")"
EXECUTABLE="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$PROJECT_DIR/Info.plist")"
BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$PROJECT_DIR/Info.plist")"
# UNFOLDMYMAC_APP_BUNDLE lets the release driver build into its own empty directory, so a
# notarized image can never inherit a file from an older bundle layout. Unset, this is the
# developer's usual dist/ bundle and nothing below changes.
APP_BUNDLE="${UNFOLDMYMAC_APP_BUNDLE:-$PROJECT_DIR/dist/$APP_NAME.app}"
# Preserve the bundle directory's identity for existing Finder/Dock references. Skipped for a
# release build: migrating a stale Luma.app into a release directory is exactly what the
# override exists to prevent.
if [ -z "${UNFOLDMYMAC_APP_BUNDLE:-}" ] && [ ! -e "$APP_BUNDLE" ] && [ -d "$PROJECT_DIR/dist/Luma.app" ]; then
  mv "$PROJECT_DIR/dist/Luma.app" "$APP_BUNDLE"
fi
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"
cp "$BUILD_DIR/$EXECUTABLE" "$APP_BUNDLE/Contents/MacOS/$EXECUTABLE"
# Remove generated artifacts belonging to the old product name.
rm -f "$APP_BUNDLE/Contents/MacOS/Luma" "$APP_BUNDLE/Contents/Resources/Luma.icns"
rm -rf "$APP_BUNDLE/Contents/Resources/Luma_LumaKit.bundle" "$APP_BUNDLE/Contents/Resources/UnfoldMyMac_LumaKit.bundle"
cp "$PROJECT_DIR/Info.plist" "$APP_BUNDLE/Contents/Info.plist"
"$PROJECT_DIR/script/make_icon.sh"
cp "$PROJECT_DIR/.build/UnfoldMyMac.icns" "$APP_BUNDLE/Contents/Resources/$APP_NAME.icns"
RESOURCE_BUNDLE="${APP_NAME}_UnfoldMyMacKit.bundle"
if [ -d "$BUILD_DIR/$RESOURCE_BUNDLE" ]; then
  rm -rf "$APP_BUNDLE/Contents/Resources/$RESOURCE_BUNDLE"
  cp -R "$BUILD_DIR/$RESOURCE_BUNDLE" "$APP_BUNDLE/Contents/Resources/"
  # Local resource notes are not part of the distributed app.
  find "$APP_BUNDLE/Contents/Resources/$RESOURCE_BUNDLE" -type f -name '*.md' -delete
  # Precompiled shader units, when the Metal toolchain is installed; the app falls back to source otherwise.
  "$PROJECT_DIR/script/compile_shaders.sh" "$BUILD_DIR/$EXECUTABLE" "$APP_BUNDLE/Contents/Resources/$RESOURCE_BUNDLE"
fi
cp "$PROJECT_DIR/../LICENSE" "$PROJECT_DIR/../NOTICE" "$APP_BUNDLE/Contents/Resources/"
IDENTITY="${UNFOLDMYMAC_SIGN_IDENTITY:-${LUMA_SIGN_IDENTITY:-${MACDUO_SIGN_IDENTITY:-}}}"
if [ -z "$IDENTITY" ]; then
  IDENTITY="$(/usr/bin/security find-identity -v -p codesigning | /usr/bin/sed -n 's/.*"\(Apple Development: .*\)"/\1/p' | /usr/bin/head -1)"
fi
IDENTITY="${IDENTITY:--}"
/usr/bin/codesign --force --sign "$IDENTITY" --identifier "$BUNDLE_ID" "$APP_BUNDLE"
case "$MODE" in
  --build) echo "Built $APP_BUNDLE"; exit 0 ;;
  --probe) exec "$APP_BUNDLE/Contents/MacOS/$EXECUTABLE" --probe ;;
  --shader-check) exec "$APP_BUNDLE/Contents/MacOS/$EXECUTABLE" --shader-check ;;
esac
pkill -x "$EXECUTABLE" >/dev/null 2>&1 || true
pkill -x Luma >/dev/null 2>&1 || true
pkill -x MacDuo >/dev/null 2>&1 || true
/usr/bin/open -n "$APP_BUNDLE"
