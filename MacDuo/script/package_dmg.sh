#!/usr/bin/env bash
# Package an ALREADY signed, notarized and stapled UnfoldMyMac.app into a signed disk image
# with a branded drag-to-Applications window, then prove the image holds that exact application.
#
# THE ORDERING THIS SITS INSIDE, and it is the only order that works:
#
#   sign .app -> notarize #1 -> staple .app
#     -> package DMG (here) -> sign DMG -> notarize #2 -> staple DMG -> verify
#
# Stapling writes the ticket INTO the bundle. Image first and staple after, and the loose app
# and the imaged copy differ, so the diff -qr below fails and the only repair is to notarize
# again. Staple first, image second.
#
# ditto, never cp -R: it preserves xattrs, ACLs, _CodeSignature/ and the staple ticket. A cp
# here produces an image that mounts, launches, and fails `stapler validate` in front of a user.
#
# The IMAGE is signed WITHOUT --options runtime and WITHOUT entitlements. A disk image is not
# executable code; the Hardened Runtime flag and the entitlement set belong to the application
# inside it, which already carries both.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$HERE/.." && pwd)"
IDENTITY="${UNFOLDMYMAC_SIGN_IDENTITY:-}"
THEME="${UNFOLDMYMAC_DMG_THEME:-light}"
# Artwork preview. Builds the same window, geometry, background and volume icon from whatever
# bundle it is handed, so the installer can be reviewed and re-rendered without spending a
# notarization submission on every change. It signs nothing, it asserts nothing about the
# application, and it forces a "-preview" filename so a preview can never be mistaken for, or
# uploaded as, a release artifact. Never ship the output.
PREVIEW="${UNFOLDMYMAC_DMG_PREVIEW:-0}"
FONTS="$PROJECT_DIR/Sources/UnfoldMyMacKit/Resources/Fonts"
APP="${1:-}"
DMG="${2:-}"

fail() { echo "✖ package_dmg: $*" >&2; exit 1; }

[ -n "$APP" ] || fail "usage: package_dmg.sh /path/UnfoldMyMac.app [/path/UnfoldMyMac-1.0.0.dmg]"
[ -d "$APP" ] && [ "${APP##*.}" = "app" ] || fail "not an application bundle: $APP"
APP="$(cd "$(dirname "$APP")" && pwd)/$(basename "$APP")"

if [ "$PREVIEW" != "1" ]; then
  case "$IDENTITY" in
    "Developer ID Application:"*) ;;
    *) fail "UNFOLDMYMAC_SIGN_IDENTITY must be an explicit 'Developer ID Application: …' identity" ;;
  esac
  identities="$(/usr/bin/security find-identity -v -p codesigning)"
  case "$identities" in
    *"\"$IDENTITY\""*) ;;
    *) fail "'$IDENTITY' is not a valid keychain signing identity" ;;
  esac
fi

# ── Pre-flight: refuse to image anything not release-ready ──────────────────
#
# Every one of these is a state the DMG would silently inherit and hand to a user.
echo "→ pre-flight on $(basename "$APP")"
/usr/bin/codesign --verify --deep --strict --verbose=2 "$APP"
app_details="$(/usr/bin/codesign -dv --verbose=4 "$APP" 2>&1)"
app_cdhash="$(printf '%s\n' "$app_details" | sed -n 's/^CDHash=//p' | sed -n '1p')"
[ -n "$app_cdhash" ] || fail "could not read the application code-directory hash"
if [ "$PREVIEW" = "1" ]; then
  echo "  ! PREVIEW: release checks skipped. This image is for looking at, not for shipping."
else
  case "$app_details" in
    *"Authority=Developer ID Application:"*) ;;
    *) fail "application is not Developer ID signed; run script/sign_release.sh first" ;;
  esac
  case "$app_details" in *"Runtime Version="*) ;; *) fail "application is missing the Hardened Runtime flag" ;; esac
  app_team="$(printf '%s\n' "$app_details" | sed -n 's/^TeamIdentifier=//p' | sed -n '1p')"
  [ -n "$app_team" ] || fail "application has no TeamIdentifier"
  # THE ordering assertion. Imaging an unstapled app produces a DMG whose inner bundle can never
  # pass verification, and the only repair is another notarization of the application.
  /usr/bin/xcrun stapler validate "$APP" >/dev/null 2>&1 \
    || fail "the application has no stapled notarization ticket.
     Notarize and staple the .app BEFORE packaging: script/notarize_release.sh \"$APP\""
fi

version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")"
source_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$PROJECT_DIR/Info.plist")"
[ "$version" = "$source_version" ] \
  || fail "version mismatch: bundle=$version, MacDuo/Info.plist=$source_version. The bundle is stale."
product="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleName' "$APP/Contents/Info.plist")"
if [ "$PREVIEW" = "1" ]; then
  # Forced, not defaulted: a preview must never be able to occupy the release filename.
  DMG="$(cd "$(dirname "$APP")" && pwd)/${product}-${version}-preview.dmg"
  echo "  ✓ preview image, version $version"
else
  [ -n "$DMG" ] || DMG="$(cd "$(dirname "$APP")" && pwd)/${product}-${version}.dmg"
  [ "${DMG##*.}" = "dmg" ] || fail "output path must end in .dmg: $DMG"
  echo "  ✓ Developer ID, hardened, stapled, version $version"
fi

volname="$product $version"
staging=""; render_dir=""; rw_dir=""; rw_mount=""; rw_mounted=0; mount_dir=""; mounted=0
cleanup() {
  [ "$mounted" -eq 1 ] && [ -n "$mount_dir" ] && /usr/bin/hdiutil detach "$mount_dir" -quiet >/dev/null 2>&1 || true
  # A read-write image left attached survives the script and blocks the next run with a
  # "resource busy" that reads like a permissions problem.
  [ "$rw_mounted" -eq 1 ] && [ -n "$rw_mount" ] && /usr/bin/hdiutil detach "$rw_mount" -quiet >/dev/null 2>&1 || true
  # Deliberately NOT `rm -rf "$rw_mount"`: that path is under /Volumes and, if the detach above
  # failed, it is a MOUNTED VOLUME. Detach releases it; the mount point goes with it.
  [ -n "$rw_dir" ] && rm -rf "$rw_dir" || true
  [ -n "$mount_dir" ] && rm -rf "$mount_dir" || true
  [ -n "$staging" ] && rm -rf "$staging" || true
  [ -n "$render_dir" ] && rm -rf "$render_dir" || true
}
trap cleanup EXIT

# ── Stage ───────────────────────────────────────────────────────────────────
staging="$(mktemp -d)"
echo "→ staging with ditto (xattrs, ACLs, _CodeSignature, staple ticket)"
/usr/bin/ditto "$APP" "$staging/$(basename "$APP")"

# ── Branding ────────────────────────────────────────────────────────────────
echo "→ rendering installer artwork ($THEME theme, Space Grotesk)"
render_dir="$(mktemp -d)"
/usr/bin/xcrun swift "$HERE/render_dmg_background.swift" \
  --out "$render_dir" --fonts "$FONTS" --theme "$THEME" --version "$version" >/dev/null \
  || fail "could not render the installer background"

# A HiDPI TIFF, not a PNG. Finder reads a background image's PIXEL size as POINTS, so handing it
# the @2x PNG alone would open a 1320x840-point window on every Mac. The paired TIFF carries the
# 2x representation flagged as HiDPI: a 660x420 window that stays sharp on Retina.
mkdir -p "$staging/.background"
/usr/bin/tiffutil -cathidpicheck "$render_dir/background.png" "$render_dir/background@2x.png" \
  -out "$staging/.background/background.tiff" >/dev/null \
  || fail "could not build the HiDPI background"

# The window layout comes from the renderer, so the drawn arrow and the real icons cannot drift.
layout="$render_dir/layout.plist"
[ -f "$layout" ] || fail "the renderer did not emit layout.plist"
geom() { /usr/libexec/PlistBuddy -c "Print :$1" "$layout"; }
win_w="$(geom windowWidth)"; win_h="$(geom windowHeight)"; icon_px="$(geom iconSize)"
app_x="$(geom appIconCenterX)"; app_y="$(geom appIconCenterY)"
apps_x="$(geom applicationsIconCenterX)"; apps_y="$(geom applicationsIconCenterY)"

# Finder's window `bounds` cover the TITLE BAR as well as the icon view, but the background
# image is laid against the icon view's top-left and is not scaled. Setting bounds to the art's
# own height therefore crops the bottom of the art by exactly the title bar, which silently eats
# the footer line. Ask AppKit what the chrome measures on THIS macOS instead of hardcoding it.
chrome="$(/usr/bin/xcrun swift -e 'import AppKit
let content = NSRect(x: 0, y: 0, width: 660, height: 420)
let frame = NSWindow.frameRect(forContentRect: content, styleMask: [.titled, .closable, .miniaturizable, .resizable])
print(Int(frame.height - content.height))' 2>/dev/null)"
case "$chrome" in
  ''|*[!0-9]*) fail "could not measure the Finder window title bar height" ;;
esac
[ "$chrome" -ge 20 ] && [ "$chrome" -le 60 ] \
  || fail "implausible title bar height ${chrome}pt; refusing to lay out a cropped window"
frame_h=$((win_h + chrome))

# ── Image ───────────────────────────────────────────────────────────────────
#
# TWO STAGE, and it has to be. A window layout (background picture, icon positions, icon size)
# lives in a .DS_Store that only Finder can write, and Finder can only write to a MOUNTED,
# WRITABLE volume. There is no way to set any of it on a compressed read-only image. So: build
# UDRW, let Finder record the layout, then convert to the UDZO that ships.
echo "→ creating $DMG"
rm -f "$DMG"
rw_dir="$(mktemp -d)"
rw_dmg="$rw_dir/rw.dmg"

# Sized with slack. An image created at exactly content size leaves Finder no room to write
# .DS_Store, and the layout step then fails in a way that looks like an AppleScript problem
# rather than a full disk.
staging_kb="$(/usr/bin/du -sk "$staging" | cut -f1)"
/usr/bin/hdiutil create -volname "$volname" -fs HFS+ -size "$(( staging_kb + 65536 ))k" -ov -quiet "$rw_dmg"
[ -f "$rw_dmg" ] || fail "hdiutil produced no read-write image"

# A volume of this name must NOT already be mounted. If one is, macOS mounts ours at "<name> 1"
# while BOTH keep the same VOLUME NAME, and the layout step addresses Finder by name, so it would
# silently lay out the stale volume and leave this image with no .DS_Store at all. That image
# still signs, notarizes, staples and verifies; it just opens as a bare Finder window.
[ ! -e "/Volumes/$volname" ] || fail "a volume named '$volname' is already mounted.
     Building now would lay out THAT volume and ship an unbranded image that passes every check.
     Eject it first:  hdiutil detach '/Volumes/$volname'"

# Attached at its DEFAULT location under /Volumes and WITHOUT -nobrowse. Both are load-bearing:
# Finder addresses a volume as `disk "<name>"` and can only find one mounted under /Volumes and
# browsable. A -mountpoint of our own choosing fails with AppleScript error -1728, "Can't get
# disk …", which reads like a permissions problem and is not one.
attach_output="$(/usr/bin/hdiutil attach "$rw_dmg" -readwrite -noautoopen)"
rw_mount="$(printf '%s\n' "$attach_output" | awk -F'\t' '/\/Volumes\//{ print $NF }' | tail -1)"
[ -n "$rw_mount" ] && [ -d "$rw_mount" ] || fail "could not determine where the read-write image mounted:
$attach_output"
rw_mounted=1
[ "$(basename "$rw_mount")" = "$volname" ] \
  || fail "the image mounted as '$(basename "$rw_mount")' rather than '$volname'; another volume holds that name"

# Copied item by item, NOT `ditto "$staging" "$rw_mount"`. The staging tree gains a symlink to
# /Applications below, and a copy that dereferenced it would silently pull the user's entire
# Applications folder into the image: a multi-gigabyte DMG that still builds, signs and mounts.
echo "→ populating the image"
/usr/bin/ditto "$staging/$(basename "$APP")" "$rw_mount/$(basename "$APP")"
# Named `Applications`, so it does not match the `*.app` glob used to assert the image holds
# exactly one top-level application.
/bin/ln -s /Applications "$rw_mount/Applications"
mkdir -p "$rw_mount/.background"
/usr/bin/ditto "$staging/.background/background.tiff" "$rw_mount/.background/background.tiff"
# .VolumeIcon.icns is deliberately NOT written here. See after the layout step.

echo "→ laying out the installer window (${win_w}x${win_h} of art, ${frame_h}pt tall with the ${chrome}pt title bar, icons at ${app_x},${app_y} and ${apps_x},${apps_y})"
# Finder positions are the icon CENTRE in the icon view's coordinate space, whose origin is the
# top-left of the window content: the same origin the background was drawn against.
if ! /usr/bin/osascript - "$volname" "$(basename "$APP")" \
      "$win_w" "$frame_h" "$icon_px" "$app_x" "$app_y" "$apps_x" "$apps_y" <<'APPLESCRIPT'
on run argv
  set volName to item 1 of argv
  set appName to item 2 of argv
  set winW to (item 3 of argv) as integer
  set frameH to (item 4 of argv) as integer
  set iconPx to (item 5 of argv) as integer
  set appX to (item 6 of argv) as integer
  set appY to (item 7 of argv) as integer
  set appsX to (item 8 of argv) as integer
  set appsY to (item 9 of argv) as integer
  tell application "Finder"
    tell disk volName
      open
      set current view of container window to icon view
      set toolbar visible of container window to false
      set statusbar visible of container window to false
      set the bounds of container window to {200, 150, 200 + winW, 150 + frameH}
      set viewOptions to the icon view options of container window
      set arrangement of viewOptions to not arranged
      set icon size of viewOptions to iconPx
      set text size of viewOptions to 13
      set background picture of viewOptions to file ".background:background.tiff"
      set position of item appName of container window to {appX, appY}
      set position of item "Applications" of container window to {appsX, appsY}
      close
      open
      update without registering applications
      delay 2
      close
    end tell
  end tell
end run
APPLESCRIPT
then
  fail "Finder would not lay out the installer window.

     This step drives Finder over AppleScript, so it needs Automation permission for whichever
     program is running this script (Terminal, iTerm, your editor). Grant it under
     System Settings > Privacy & Security > Automation > <that app> > Finder, then re-run.
     It also fails over SSH or in a context with no GUI login session.

     Refusing rather than shipping an unbranded image: a silent fallback here would produce a
     plain white Finder window that still passes every downstream check, and nobody would
     notice until it was in front of a user."
fi

# Finder is addressed by name, so prove it wrote to THIS volume. Without this, a layout applied
# to the wrong disk is indistinguishable from a successful one.
[ -s "$rw_mount/.DS_Store" ] \
  || fail "Finder wrote no .DS_Store to $rw_mount; the window layout did not land on this image"

# ── Volume icon, written LAST, and the order is not stylistic ───────────────
#
# Finder DELETES .VolumeIcon.icns from a volume it opens. Write it before the layout step and
# the finished image is left with the custom-icon bit set and no icon to satisfy it: a blank
# disc in the sidebar, which looks like the artwork simply failed rather than like a file was
# removed.
/usr/bin/ditto "$PROJECT_DIR/.build/UnfoldMyMac.icns" "$rw_mount/.VolumeIcon.icns"
[ -f "$rw_mount/.VolumeIcon.icns" ] \
  || fail "the volume icon did not survive the Finder layout step; it must be written AFTER it"
# The icon file alone does nothing; the 'C' attribute on the volume root is what makes Finder use it.
/usr/bin/xcrun SetFile -a C "$rw_mount" || fail "could not mark the volume as having a custom icon"

# Flush Finder's .DS_Store to the image before detaching, or the layout is lost.
/bin/sync
/usr/bin/hdiutil detach "$rw_mount" -quiet
rw_mounted=0

echo "→ compressing to the distributable read-only image"
/usr/bin/hdiutil convert "$rw_dmg" -format UDZO -imagekey zlib-level=9 -o "$DMG" -quiet
[ -f "$DMG" ] || fail "hdiutil produced no image at $DMG"

if [ "$PREVIEW" = "1" ]; then
  echo "→ not signing: preview image"
else
  echo "→ signing the image"
  /usr/bin/codesign --force --timestamp --sign "$IDENTITY" "$DMG"
fi

# ── Self-check: the image holds the exact application we were handed ────────
#
# The same comparison verify_release.sh performs post-notarization, run here so a bad image is
# caught BEFORE a second notarization submission rather than after it.
echo "→ verifying the image contents"
/usr/bin/hdiutil verify "$DMG" >/dev/null
if [ "$PREVIEW" != "1" ]; then
  dmg_details="$(/usr/bin/codesign -dv --verbose=4 "$DMG" 2>&1)"
  case "$dmg_details" in
    *"Authority=Developer ID Application:"*) ;;
    *) fail "image is not Developer ID signed" ;;
  esac
  dmg_team="$(printf '%s\n' "$dmg_details" | sed -n 's/^TeamIdentifier=//p' | sed -n '1p')"
  [ "$dmg_team" = "$app_team" ] || fail "image TeamIdentifier '$dmg_team' differs from the application's '$app_team'"
fi

mount_dir="$(mktemp -d)"
/usr/bin/hdiutil attach -readonly -nobrowse -noautoopen -mountpoint "$mount_dir" "$DMG" >/dev/null
mounted=1
shopt -s nullglob
dmg_apps=("$mount_dir"/*.app)
[ "${#dmg_apps[@]}" -eq 1 ] || fail "image must contain exactly one top-level .app, found ${#dmg_apps[@]}"
dmg_app="${dmg_apps[0]}"
[ "$(basename "$dmg_app")" = "$(basename "$APP")" ] || fail "imaged application name differs"
/usr/bin/codesign --verify --deep --strict --verbose=2 "$dmg_app"
mounted_cdhash="$(/usr/bin/codesign -dv --verbose=4 "$dmg_app" 2>&1 | sed -n 's/^CDHash=//p' | sed -n '1p')"
[ "$mounted_cdhash" = "$app_cdhash" ] \
  || fail "imaged application code-directory hash differs (expected $app_cdhash, got $mounted_cdhash)"
/usr/bin/diff -qr "$APP" "$dmg_app" >/dev/null || fail "the image does not contain the byte-identical application"
if [ "$PREVIEW" != "1" ]; then
  /usr/bin/xcrun stapler validate "$dmg_app" >/dev/null \
    || fail "the imaged application lost its stapled ticket; the copy was not made with ditto"
fi
/usr/bin/hdiutil detach "$mount_dir" -quiet
mounted=0

if [ "$PREVIEW" = "1" ]; then
  echo "✓ package_dmg: $DMG is an UNSIGNED PREVIEW of the installer window. Do not distribute it."
  echo "  open it with: open \"$DMG\""
else
  echo "✓ package_dmg: $DMG holds the byte-identical stapled application (CDHash $app_cdhash)"
  echo "  next: notarize and staple the IMAGE, then run script/verify_release.sh"
fi
