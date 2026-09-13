#!/usr/bin/env bash
# Seal an assembled UnfoldMyMac.app for distribution: Developer ID, Hardened Runtime, secure
# timestamp, reviewed entitlements. No fallback to ad-hoc or Apple Development, ever.
#
# This is deliberately separate from build_and_run.sh. That script signs with whatever is at
# hand so CI (UNFOLDMYMAC_SIGN_IDENTITY="-") and local development keep working, and macOS keys
# TCC grants on the designated requirement, so a developer build should keep its Apple
# Development identity rather than churn the Screen Recording grant on every build. A release
# path that can silently fall back is a release path that ships an unnotarizable bundle.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$HERE/.." && pwd)"
REPO_ROOT="$(cd "$PROJECT_DIR/.." && pwd)"
IDENTITY="${UNFOLDMYMAC_SIGN_IDENTITY:-}"
ENTITLEMENTS="$PROJECT_DIR/UnfoldMyMac.entitlements"
APP="${1:-}"

fail() { echo "✖ sign_release: $*" >&2; exit 1; }

[ -n "$APP" ] || fail "usage: sign_release.sh /path/to/UnfoldMyMac.app"
[ -d "$APP" ] && [ "${APP##*.}" = "app" ] || fail "not an application bundle: $APP"
APP="$(cd "$(dirname "$APP")" && pwd)/$(basename "$APP")"
[ -f "$ENTITLEMENTS" ] || fail "missing reviewed entitlements at $ENTITLEMENTS"

case "$IDENTITY" in
  "Developer ID Application:"*) ;;
  *) fail "UNFOLDMYMAC_SIGN_IDENTITY must be an explicit 'Developer ID Application: …' identity.
     This path has no fallback by design." ;;
esac
identities="$(/usr/bin/security find-identity -v -p codesigning)"
case "$identities" in
  *"\"$IDENTITY\""*) ;;
  *) fail "'$IDENTITY' is not a valid keychain signing identity" ;;
esac

BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Contents/Info.plist")"
EXECUTABLE="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$APP/Contents/Info.plist")"
RESOURCES="$APP/Contents/Resources"
KIT_BUNDLE="$RESOURCES/UnfoldMyMac_UnfoldMyMacKit.bundle"

# ── Bundle shape, asserted before anything is sealed ────────────────────────
#
# These are the same properties CI verifies after a build, promoted to release gates. Each one
# is something a user would meet instead of us.
echo "→ checking bundle shape"
[ -f "$APP/Contents/MacOS/$EXECUTABLE" ] || fail "missing executable Contents/MacOS/$EXECUTABLE"
/usr/bin/file -b "$APP/Contents/MacOS/$EXECUTABLE" | grep -q 'Mach-O' \
  || fail "Contents/MacOS/$EXECUTABLE is not a Mach-O binary"
/usr/bin/cmp -s "$REPO_ROOT/LICENSE" "$RESOURCES/LICENSE" || fail "bundled LICENSE differs from $REPO_ROOT/LICENSE"
/usr/bin/cmp -s "$REPO_ROOT/NOTICE"  "$RESOURCES/NOTICE"  || fail "bundled NOTICE differs from $REPO_ROOT/NOTICE"
[ -f "$RESOURCES/UnfoldMyMac.icns" ] || fail "missing Contents/Resources/UnfoldMyMac.icns"
# The OFL requires its licence to travel with the fonts.
[ -f "$KIT_BUNDLE/Resources/Fonts/OFL.txt" ] || fail "missing the Space Grotesk OFL licence in the resource bundle"
# compile_shaders.sh exits 0 without the Metal toolchain. A release that took that path would
# compile every shader on the user's Mac at first paint.
[ -s "$KIT_BUNDLE/Shaders/Compiled/index.json" ] \
  || fail "no precompiled shaders: $KIT_BUNDLE/Shaders/Compiled/index.json is missing or empty"
stray_md="$(/usr/bin/find "$APP" -type f -name '*.md' -print -quit)"
[ -z "$stray_md" ] || fail "Markdown shipped inside the bundle: $stray_md"
stray_ds="$(/usr/bin/find "$APP" -name '.DS_Store' -print -quit)"
[ -z "$stray_ds" ] || fail ".DS_Store shipped inside the bundle: $stray_ds"

archs="$(/usr/bin/lipo -archs "$APP/Contents/MacOS/$EXECUTABLE")"
expected_archs="${UNFOLDMYMAC_ARCHS:-arm64}"
[ "$archs" = "$expected_archs" ] || fail "architecture mismatch: bundle has '$archs', expected '$expected_archs'"
echo "  ✓ shape, licences, precompiled shaders, $archs"

# Quarantine and Finder xattrs make notarization results noisy and break the later diff -qr.
/usr/bin/xattr -cr "$APP"

# ── Nested Mach-O code, inside out ──────────────────────────────────────────
#
# Today this signs nothing: the bundle holds exactly one Mach-O. It stays because the day a
# helper, framework or XPC service appears, an unsigned nested binary fails notarization with a
# message that does not name the file.
#
# The *.metallib prune is load-bearing. A .metallib is an MTLB container, not Mach-O, and
# signing one breaks makeLibrary(URL:) at runtime on the user's Mac. file(1) already reports
# them as "MetalLib executable", but a wording change upstream should not be able to start
# signing 16 shader containers.
echo "→ signing nested code"
nested=0
while IFS= read -r -d '' item; do
  [ "$item" = "$APP/Contents/MacOS/$EXECUTABLE" ] && continue
  /usr/bin/file -b "$item" | grep -q 'Mach-O' || continue
  /usr/bin/codesign --force --timestamp --options runtime --sign "$IDENTITY" "$item"
  nested=$(( nested + 1 ))
done < <(/usr/bin/find "$APP/Contents" -name '*.metallib' -prune -o -type f -print0)
echo "  ✓ $nested nested Mach-O items"

# ── Seal ────────────────────────────────────────────────────────────────────
echo "→ sealing $APP"
/usr/bin/codesign --force --timestamp --options runtime \
  --entitlements "$ENTITLEMENTS" \
  --identifier "$BUNDLE_ID" \
  --sign "$IDENTITY" "$APP"

# ── Verify what was actually written ────────────────────────────────────────
/usr/bin/codesign --verify --deep --strict --verbose=2 "$APP"
details="$(/usr/bin/codesign -dv --verbose=4 "$APP" 2>&1)"
authority="$(printf '%s\n' "$details" | sed -n 's/^Authority=//p' | sed -n '1p')"
[ "$authority" = "$IDENTITY" ] || fail "sealed with '$authority', expected '$IDENTITY'"
team="$(printf '%s\n' "$details" | sed -n 's/^TeamIdentifier=//p' | sed -n '1p')"
[ "$team" = "${UNFOLDMYMAC_TEAM_ID:-WW382UC8JD}" ] || fail "TeamIdentifier is '$team'"
case "$details" in *"Runtime Version="*) ;; *) fail "the Hardened Runtime flag is missing" ;; esac
case "$details" in *"flags=0x10000(runtime)"*) ;; *) fail "code directory flags do not carry runtime: $(printf '%s\n' "$details" | grep '^CodeDirectory')" ;; esac
# Timestamp=, not "Signed Time=". The latter is the local clock and means the timestamp
# authority was never reached, which notarization rejects after the upload.
case "$details" in *"Timestamp="*) ;; *) fail "no secure timestamp in the signature" ;; esac
echo "  ✓ $authority, team $team, hardened runtime, secure timestamp"

# ── The shipped entitlement set is the reviewed one ─────────────────────────
actual="$(mktemp)"; trap 'rm -f "$actual"' EXIT
/usr/bin/codesign -d --entitlements - --xml "$APP" >"$actual" 2>/dev/null || true
case "$(cat "$actual")" in
  *get-task-allow*) fail "com.apple.security.get-task-allow is embedded; notarization would return Invalid" ;;
esac
keys_of() { /usr/bin/plutil -convert xml1 -o - "$1" 2>/dev/null | sed -n 's/.*<key>\(.*\)<\/key>.*/\1/p' | sort; }
if [ -s "$actual" ]; then
  [ "$(keys_of "$actual")" = "$(keys_of "$ENTITLEMENTS")" ] \
    || fail "the embedded entitlements differ from the reviewed set in $ENTITLEMENTS:
embedded: $(keys_of "$actual" | tr '\n' ' ')
reviewed: $(keys_of "$ENTITLEMENTS" | tr '\n' ' ')"
fi
echo "  ✓ entitlements match $ENTITLEMENTS (no get-task-allow)"

# ── Does the hardened bundle actually run? ──────────────────────────────────
#
# This is the empirical answer to the entitlement reasoning in UnfoldMyMac.entitlements.
# --shader-check exercises runtime MSL compilation, which is the one thing a missing
# allow-jit would break. Seconds here, versus an hour and a rebuild after notarization.
echo "→ exercising the hardened bundle"
"$APP/Contents/MacOS/$EXECUTABLE" --probe >/dev/null \
  || fail "the hardened bundle fails --probe"
"$APP/Contents/MacOS/$EXECUTABLE" --shader-check >/dev/null \
  || fail "the hardened bundle fails --shader-check: runtime Metal compilation is broken under the
     Hardened Runtime. Re-examine the reasoning in $ENTITLEMENTS before adding any entitlement."
echo "  ✓ --probe and --shader-check pass under the Hardened Runtime"

echo "✓ sign_release: $APP is ready for notarization"
