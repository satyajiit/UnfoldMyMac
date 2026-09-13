#!/usr/bin/env bash
# The release driver. Runs every step in the only order that works, and can resume.
#
#   host -> build -> sign -> notarize-app -> dmg -> notarize-dmg -> verify -> checksum
#
# Resume matters: by the `dmg` step the .app carries a ticket that took the better part of an
# hour to obtain. Identity resolution and every derived path happen in SETUP, outside any
# skippable step, so `--from dmg` cannot die several minutes in blaming the operator for a
# variable the driver was supposed to set.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$HERE/.." && pwd)"
REPO_ROOT="$(cd "$PROJECT_DIR/.." && pwd)"

STEPS="host build sign notarize-app dmg notarize-dmg verify checksum"
FROM=""; ONLY=""; ALLOW_DIRTY=""
while [ $# -gt 0 ]; do
  case "$1" in
    --from) FROM="${2:-}"; shift 2 ;;
    --only) ONLY="${2:-}"; shift 2 ;;
    --allow-dirty) ALLOW_DIRTY="--allow-dirty"; shift ;;
    --theme) export UNFOLDMYMAC_DMG_THEME="${2:-light}"; shift 2 ;;
    --list) echo "$STEPS" | tr ' ' '\n'; exit 0 ;;
    *) echo "usage: release_macos.sh [--from STEP] [--only STEP] [--allow-dirty] [--theme light|dark] [--list]" >&2; exit 2 ;;
  esac
done

fail() { echo "✖ release_macos: $*" >&2; exit 1; }

# ── Setup: everything derived once, before any skippable work ───────────────
export UNFOLDMYMAC_SIGN_IDENTITY="${UNFOLDMYMAC_SIGN_IDENTITY:-}"
export UNFOLDMYMAC_NOTARY_PROFILE="${UNFOLDMYMAC_NOTARY_PROFILE:-unfoldmymac-notary}"
[ -n "$UNFOLDMYMAC_SIGN_IDENTITY" ] || fail "UNFOLDMYMAC_SIGN_IDENTITY is unset. Export the exact identity:
     export UNFOLDMYMAC_SIGN_IDENTITY=\"Developer ID Application: … (TEAMID)\""

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$PROJECT_DIR/Info.plist")"
PRODUCT="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleName' "$PROJECT_DIR/Info.plist")"
RELEASE_DIR="${UNFOLDMYMAC_RELEASE_DIR:-$PROJECT_DIR/dist/release}"
APP="$RELEASE_DIR/$PRODUCT.app"
DMG="$RELEASE_DIR/$PRODUCT-$VERSION.dmg"
MARK="Sources/UnfoldMyMacKit/Resources/Brand/UnfoldMyMacMark.png"

should_run() {
  local step="$1"
  if [ -n "$ONLY" ]; then [ "$step" = "$ONLY" ] && return 0 || return 1; fi
  if [ -n "$FROM" ]; then
    local seen=0
    for s in $STEPS; do
      [ "$s" = "$FROM" ] && seen=1
      [ "$s" = "$step" ] && { [ "$seen" -eq 1 ] && return 0 || return 1; }
    done
    return 1
  fi
  return 0
}
announce() { echo; echo "════ $1 ════"; }

echo "UnfoldMyMac $VERSION → $DMG"

if should_run host; then
  announce "host"
  "$HERE/check_release_host.sh" $ALLOW_DIRTY
fi

if should_run build; then
  announce "build"
  # Built into a freshly emptied directory so no file from an older bundle layout can ride along
  # into a notarized image. Signed ad-hoc here on purpose: sign_release.sh replaces it, and an
  # unambiguous placeholder is better than a half-real signature.
  rm -rf "$APP"
  mkdir -p "$RELEASE_DIR"
  ( cd "$PROJECT_DIR" && UNFOLDMYMAC_APP_BUNDLE="$APP" UNFOLDMYMAC_SIGN_IDENTITY=- ./script/build_and_run.sh --build )
  # make_icon.sh regenerates UnfoldMyMacMark.png into the source tree when the logo is newer.
  # If that happened, the bundle about to be notarized matches no commit. Fail loudly and rarely
  # rather than hiding it with a checkout.
  if [ -z "$ALLOW_DIRTY" ]; then
    drift="$(git -C "$REPO_ROOT" status --porcelain -- "UnfoldMyMac/$MARK")"
    [ -z "$drift" ] || fail "make_icon.sh regenerated $MARK during the release build.
     The bundle about to be notarized does not match any commit.
     Commit the regenerated mark, re-tag, and re-run."
  fi
fi

if should_run sign;         then announce "sign";          "$HERE/sign_release.sh" "$APP"; fi
if should_run notarize-app; then announce "notarize (1/2)"; "$HERE/notarize_release.sh" "$APP"; fi
if should_run dmg;          then announce "dmg";            "$HERE/package_dmg.sh" "$APP" "$DMG"; fi
if should_run notarize-dmg; then announce "notarize (2/2)"; "$HERE/notarize_release.sh" "$DMG"; fi
if should_run verify;       then announce "verify";         "$HERE/verify_release.sh" "$APP" "$DMG"; fi

if should_run checksum; then
  announce "checksum"
  # LAST, and not cosmetically. `stapler staple` REWRITES the DMG, so a hash taken before
  # stapling is the hash of a file that no longer exists, and the website's release gate
  # re-hashes the bytes it downloads.
  ( cd "$RELEASE_DIR" && /usr/bin/shasum -a 256 "$(basename "$DMG")" | tee SHA256SUMS )
  echo
  echo "Publish with:"
  echo "  gh release create v$VERSION --repo satyajiit/UnfoldMyMac \\"
  echo "    --title \"$PRODUCT $VERSION\" --notes-file <notes> --verify-tag --draft \\"
  echo "    \"$DMG\" \"$RELEASE_DIR/SHA256SUMS\""
fi
