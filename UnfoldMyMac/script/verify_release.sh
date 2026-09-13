#!/usr/bin/env bash
# The post-notarization gate. Runs against the finished artifacts, and against downloaded ones:
# nothing here depends on the build tree except the reviewed entitlements and Info.plist.
#
# A validly notarized DMG is not evidence by itself. It has to contain THIS application, not a
# previously notarized one, which is why the CDHash and diff comparison is repeated here.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$HERE/.." && pwd)"
ENTITLEMENTS="$PROJECT_DIR/UnfoldMyMac.entitlements"
TEAM="${UNFOLDMYMAC_TEAM_ID:-WW382UC8JD}"
APP="${1:-}"
DMG="${2:-}"

fail() { echo "✖ verify_release: $*" >&2; exit 1; }
ok()   { echo "  ✓ $*"; }

[ -n "$APP" ] && [ -n "$DMG" ] || fail "usage: verify_release.sh /path/UnfoldMyMac.app /path/UnfoldMyMac-1.0.0.dmg"
[ -d "$APP" ] || fail "not an application bundle: $APP"
[ -f "$DMG" ] || fail "not a disk image: $DMG"
APP="$(cd "$(dirname "$APP")" && pwd)/$(basename "$APP")"
DMG="$(cd "$(dirname "$DMG")" && pwd)/$(basename "$DMG")"

mount_dir=""; mounted=0
cleanup() {
  [ "$mounted" -eq 1 ] && [ -n "$mount_dir" ] && /usr/bin/hdiutil detach "$mount_dir" -quiet >/dev/null 2>&1 || true
  [ -n "$mount_dir" ] && rm -rf "$mount_dir" || true
}
trap cleanup EXIT

echo "→ application"
/usr/bin/codesign --verify --deep --strict --verbose=2 "$APP"
details="$(/usr/bin/codesign -dv --verbose=4 "$APP" 2>&1)"
case "$details" in *"Authority=Developer ID Application:"*) ;; *) fail "application is not Developer ID signed" ;; esac
app_team="$(printf '%s\n' "$details" | sed -n 's/^TeamIdentifier=//p' | sed -n '1p')"
[ "$app_team" = "$TEAM" ] || fail "application TeamIdentifier is '$app_team', expected '$TEAM'"
case "$details" in *"Runtime Version="*) ;; *) fail "application is missing the Hardened Runtime flag" ;; esac
case "$details" in *"flags=0x10000(runtime)"*) ;; *) fail "code directory flags do not carry runtime" ;; esac
case "$details" in *"Timestamp="*) ;; *) fail "application carries no secure timestamp" ;; esac
app_cdhash="$(printf '%s\n' "$details" | sed -n 's/^CDHash=//p' | sed -n '1p')"
ok "Developer ID, team $app_team, hardened runtime, secure timestamp"

embedded="$(mktemp)"; trap 'rm -f "$embedded"; cleanup' EXIT
/usr/bin/codesign -d --entitlements - --xml "$APP" >"$embedded" 2>/dev/null || true
case "$(cat "$embedded")" in *get-task-allow*) fail "com.apple.security.get-task-allow is embedded" ;; esac
keys_of() { /usr/bin/plutil -convert xml1 -o - "$1" 2>/dev/null | sed -n 's/.*<key>\(.*\)<\/key>.*/\1/p' | sort; }
if [ -s "$embedded" ]; then
  [ "$(keys_of "$embedded")" = "$(keys_of "$ENTITLEMENTS")" ] || fail "embedded entitlements differ from $ENTITLEMENTS"
fi
ok "entitlements are the reviewed set"

# Every nested Mach-O must carry the same team, or Gatekeeper rejects the bundle on a machine
# that is not this one.
while IFS= read -r -d '' item; do
  /usr/bin/file -b "$item" | grep -q 'Mach-O' || continue
  nested_team="$(/usr/bin/codesign -dv --verbose=4 "$item" 2>&1 | sed -n 's/^TeamIdentifier=//p' | sed -n '1p')"
  [ "$nested_team" = "$TEAM" ] || fail "nested binary $item has team '$nested_team'"
done < <(/usr/bin/find "$APP/Contents" -name '*.metallib' -prune -o -type f -print0)
ok "every nested Mach-O carries team $TEAM"

version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")"
source_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$PROJECT_DIR/Info.plist")"
[ "$version" = "$source_version" ] || fail "bundle version $version does not match UnfoldMyMac/Info.plist $source_version"
/usr/libexec/PlistBuddy -c 'Print :LSApplicationCategoryType' "$APP/Contents/Info.plist" >/dev/null 2>&1 \
  || fail "LSApplicationCategoryType is missing from the shipped Info.plist"
archs="$(/usr/bin/lipo -archs "$APP/Contents/MacOS/$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$APP/Contents/Info.plist")")"
[ "$archs" = "${UNFOLDMYMAC_ARCHS:-arm64}" ] || fail "architectures are '$archs'"
ok "version $version, category set, $archs"

/usr/bin/xcrun stapler validate "$APP" >/dev/null || fail "the application has no valid stapled ticket"
/usr/sbin/spctl --assess --type execute --verbose=4 "$APP" 2>&1 | grep -q 'accepted' \
  || fail "Gatekeeper does not accept the application"
ok "stapled and accepted by Gatekeeper"

echo "→ disk image"
/usr/bin/hdiutil verify "$DMG" >/dev/null
/usr/bin/codesign --verify --strict --verbose=2 "$DMG"
dmg_details="$(/usr/bin/codesign -dv --verbose=4 "$DMG" 2>&1)"
case "$dmg_details" in *"Authority=Developer ID Application:"*) ;; *) fail "image is not Developer ID signed" ;; esac
dmg_team="$(printf '%s\n' "$dmg_details" | sed -n 's/^TeamIdentifier=//p' | sed -n '1p')"
[ "$dmg_team" = "$TEAM" ] || fail "image TeamIdentifier is '$dmg_team'"
/usr/bin/xcrun stapler validate "$DMG" >/dev/null || fail "the image has no valid stapled ticket"
/usr/sbin/spctl --assess --type open --context context:primary-signature --verbose=4 "$DMG" 2>&1 | grep -q 'accepted' \
  || fail "Gatekeeper does not accept the image"
ok "Developer ID, team $dmg_team, stapled, accepted by Gatekeeper"

mount_dir="$(mktemp -d)"
/usr/bin/hdiutil attach -readonly -nobrowse -noautoopen -mountpoint "$mount_dir" "$DMG" >/dev/null
mounted=1
shopt -s nullglob
dmg_apps=("$mount_dir"/*.app)
[ "${#dmg_apps[@]}" -eq 1 ] || fail "image must contain exactly one top-level .app"
dmg_app="${dmg_apps[0]}"
[ -L "$mount_dir/Applications" ] || fail "the image has no drag-to-Applications symlink"
[ -f "$mount_dir/.background/background.tiff" ] || fail "the image has no installer background"
[ -s "$mount_dir/.DS_Store" ] || fail "the image has no Finder window layout"
[ -f "$mount_dir/.VolumeIcon.icns" ] || fail "the image has no volume icon"
/usr/bin/codesign --verify --deep --strict --verbose=2 "$dmg_app"
inner_cdhash="$(/usr/bin/codesign -dv --verbose=4 "$dmg_app" 2>&1 | sed -n 's/^CDHash=//p' | sed -n '1p')"
[ "$inner_cdhash" = "$app_cdhash" ] || fail "the imaged application is a different build (CDHash $inner_cdhash vs $app_cdhash)"
/usr/bin/diff -qr "$APP" "$dmg_app" >/dev/null || fail "the imaged application is not byte-identical"
/usr/bin/xcrun stapler validate "$dmg_app" >/dev/null || fail "the imaged application lost its ticket"
ok "branded window, Applications symlink, volume icon, byte-identical stapled application"
/usr/bin/hdiutil detach "$mount_dir" -quiet
mounted=0

# What the in-app updater will accept, asserted against these exact artifacts. The requirement it
# uses is read out of the built binary, so this cannot drift from the code that installs updates.
echo "→ in-app updater trust"
"$HERE/check_update_trust.sh" "$APP" "$DMG" | sed 's/^/  /'

sha="$(/usr/bin/shasum -a 256 "$DMG" | awk '{print $1}')"
echo "✓ verify_release: $(basename "$DMG") is ready to publish"
echo
echo "SHA-256: $sha"
echo

# Written, not just printed. The in-app updater reads this file from the release as its primary
# manifest: it is the only place that states the macOS version a build needs, and reading it costs
# no GitHub API quota, which the wallpaper connector is already spending from the same address.
# The website consumes the identical bytes, so the two can never drift.
manifest="$(dirname "$DMG")/release.json"
cat >"$manifest" <<JSON
{
  "status": "available",
  "version": "$version",
  "tag": "v$version",
  "assetUrl": "https://github.com/satyajiit/UnfoldMyMac/releases/download/v$version/$(basename "$DMG")",
  "sha256": "$sha",
  "architectures": ["$archs"],
  "minimumMacOS": "$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "$APP/Contents/Info.plist" | cut -d. -f1)",
  "signing": "developer-id-notarized",
  "verifiedAt": "$(date -u +%Y-%m-%d)"
}
JSON
/usr/bin/plutil -lint "$manifest" >/dev/null || fail "the generated release.json is not valid JSON"
echo "website/src/lib/release.json (also written to $manifest):"
cat "$manifest"
