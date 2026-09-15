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
# The macOS 26 wallpaper provider. It renders the same Metal scenes as the app on the desktop and
# the lock screen, and it must carry its own copy of the Kit resource bundle: inside the appex,
# Bundle.main is the appex, so BundleResources resolves shaders and templates relative to it.
EXTENSION_NAME="UnfoldMyMacWallpaperExtension"
EXTENSION_BUNDLE="$APP_BUNDLE/Contents/PlugIns/$EXTENSION_NAME.appex"
EXTENSION_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$PROJECT_DIR/WallpaperExtension.plist")"
rm -rf "$EXTENSION_BUNDLE"
mkdir -p "$EXTENSION_BUNDLE/Contents/MacOS" "$EXTENSION_BUNDLE/Contents/Resources"
cp "$BUILD_DIR/$EXTENSION_NAME" "$EXTENSION_BUNDLE/Contents/MacOS/$EXTENSION_NAME"
cp "$PROJECT_DIR/WallpaperExtension.plist" "$EXTENSION_BUNDLE/Contents/Info.plist"
# Stamped from the app so the appex can never advertise a version the app does not have.
for KEY in CFBundleShortVersionString CFBundleVersion; do
  /usr/libexec/PlistBuddy -c "Set :$KEY $(/usr/libexec/PlistBuddy -c "Print :$KEY" "$PROJECT_DIR/Info.plist")" "$EXTENSION_BUNDLE/Contents/Info.plist"
done
if [ -d "$APP_BUNDLE/Contents/Resources/$RESOURCE_BUNDLE" ]; then
  cp -R "$APP_BUNDLE/Contents/Resources/$RESOURCE_BUNDLE" "$EXTENSION_BUNDLE/Contents/Resources/"
fi
IDENTITY="${UNFOLDMYMAC_SIGN_IDENTITY:-${LUMA_SIGN_IDENTITY:-${MACDUO_SIGN_IDENTITY:-}}}"
if [ -z "$IDENTITY" ]; then
  IDENTITY="$(/usr/bin/security find-identity -v -p codesigning | /usr/bin/sed -n 's/.*"\(Apple Development: .*\)"/\1/p' | /usr/bin/head -1)"
fi
IDENTITY="${IDENTITY:--}"
# Inside out: a nested bundle signed after its container invalidates the container's signature.
# The appex is sandboxed and the app is not, so they are signed against different entitlement files.
/usr/bin/codesign --force --sign "$IDENTITY" --identifier "$EXTENSION_ID" --entitlements "$PROJECT_DIR/WallpaperExtension.entitlements" "$EXTENSION_BUNDLE"
/usr/bin/codesign --force --sign "$IDENTITY" --identifier "$BUNDLE_ID" --entitlements "$PROJECT_DIR/UnfoldMyMac.entitlements" "$APP_BUNDLE"
case "$MODE" in
  --build) echo "Built $APP_BUNDLE"; exit 0 ;;
  --probe) exec "$APP_BUNDLE/Contents/MacOS/$EXECUTABLE" --probe ;;
  --shader-check) exec "$APP_BUNDLE/Contents/MacOS/$EXECUTABLE" --shader-check ;;
esac
pkill -x "$EXECUTABLE" >/dev/null 2>&1 || true
pkill -x Luma >/dev/null 2>&1 || true
pkill -x MacDuo >/dev/null 2>&1 || true
/usr/bin/open -n "$APP_BUNDLE"
