#!/usr/bin/env bash
# What the in-app updater will and will not accept, run against real signed artifacts.
#
# This exists because the obvious requirement is wrong. Pinning `anchor apple generic`, the bundle
# identifier and the team OU looks sufficient and is not: an *Apple Development* certificate carries
# the same team OU, so that requirement accepts any debug build of this team and would let one
# replace the shipping app. The Developer ID leaf OID and `notarized` are what actually separate
# them, and the only way to keep knowing that is to assert it against both artifacts.
#
# usage: check_update_trust.sh /path/release/UnfoldMyMac.app /path/UnfoldMyMac-1.0.1.dmg [/path/dev/UnfoldMyMac.app]
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$HERE/.." && pwd)"
APP="${1:-}"; DMG="${2:-}"; DEV_APP="${3:-$PROJECT_DIR/dist/UnfoldMyMac.app}"

fail() { echo "✖ check_update_trust: $*" >&2; exit 1; }
ok() { echo "  ✓ $*"; }

[ -d "$APP" ] || fail "usage: check_update_trust.sh /path/release/UnfoldMyMac.app /path/UnfoldMyMac-1.0.1.dmg [dev.app]"
[ -f "$DMG" ] || fail "not a disk image: $DMG"

# Read the requirements out of the freshly built binary rather than restating them here: one source
# of truth means this check cannot quietly test something the app no longer uses.
#
# Deliberately NOT the release artifact being verified. A build predating this flag would ignore it
# and launch the interface instead of printing anything, so the probe runs against the current
# SwiftPM product and is given a hard deadline in case it ever stops exiting.
ask() { /usr/bin/perl -e 'alarm 20; exec @ARGV' "$1" --update-requirements 2>/dev/null; }

requirements=""
for candidate in ${UNFOLDMYMAC_BINARY:-} "$PROJECT_DIR/.build/debug/UnfoldMyMac" "$PROJECT_DIR/.build/release/UnfoldMyMac"; do
  [ -n "$candidate" ] && [ -x "$candidate" ] || continue
  # A stale build from an earlier checkout simply will not answer; try the next one.
  if requirements="$(ask "$candidate")" && [ -n "$requirements" ]; then BINARY="$candidate"; break; fi
  requirements=""
done
[ -n "$requirements" ] || fail "no build answers --update-requirements; run swift build, or set UNFOLDMYMAC_BINARY"
APP_REQ="$(printf '%s\n' "$requirements" | awk -F'\t' '$1=="application"{print $2}')"
DMG_REQ="$(printf '%s\n' "$requirements" | awk -F'\t' '$1=="diskImage"{print $2}')"
[ -n "$APP_REQ" ] && [ -n "$DMG_REQ" ] || fail "could not read the update requirements from the binary"

echo "→ the shipping application is accepted"
/usr/bin/codesign --verify -R="$APP_REQ" --strict "$APP" 2>/dev/null || fail "the release application does not satisfy the updater's own requirement"
ok "Developer ID, team, hardened runtime and a stapled notarization ticket"

echo "→ the disk image is accepted"
/usr/bin/codesign --verify -R="$DMG_REQ" --strict "$DMG" 2>/dev/null || fail "the disk image does not satisfy the updater's requirement"
ok "signed and notarized as its own artifact"

# package_dmg.sh signs the image without --identifier, so codesign derives one from the file name
# (UnfoldMyMac-1 for 1.0.1). Pinning the bundle identifier here would pass today and break at 2.0.
echo "→ the image requirement deliberately omits the bundle identifier"
if /usr/bin/codesign --verify -R="$DMG_REQ and identifier \"com.unfoldmymac\"" --strict "$DMG" 2>/dev/null; then
  fail "the image now carries the bundle identifier; the updater's requirement can be tightened"
fi
ok "its signing identifier comes from the file name, as expected"

echo "→ a development build is refused"
if [ -d "$DEV_APP" ]; then
  if /usr/bin/codesign --verify -R="$APP_REQ" --strict "$DEV_APP" 2>/dev/null; then
    fail "a development build satisfies the updater's requirement; it could replace the shipping app"
  fi
  ok "an Apple Development signature does not pass, despite carrying the same team"
else
  echo "  – skipped: no development build at $DEV_APP (run script/build_and_run.sh --build)"
fi

echo "✓ check_update_trust: the updater accepts only what this project signs"
