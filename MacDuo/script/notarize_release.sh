#!/usr/bin/env bash
# Submit a signed artifact to Apple, wait for the verdict, and staple the ticket.
#
# Runs TWICE per release: once on the .app, once on the DMG that wraps it. See SIGNING.md for
# why the order is forced and why one submission is not enough.
#
# CREDENTIALS ARE A KEYCHAIN PROFILE, NEVER ARGV. The operator creates it once with
# `xcrun notarytool store-credentials`. This script takes only the profile NAME, so no Apple
# credential can reach a shell history, a process list or a CI log.
#
# THE STATUS IS THE VERDICT, NOT THE EXIT CODE. `notarytool submit --wait` exits 0 for a
# COMPLETED submission whose status is Invalid: the request succeeded, the notarization did
# not. Reading the exit code alone ships a build Gatekeeper refuses on every machine but this
# one. This script parses .status and treats anything but Accepted as fatal, fetching the full
# log first so the reason is in hand without a second round trip.
set -euo pipefail

TARGET="${1:-}"
PROFILE="${2:-${UNFOLDMYMAC_NOTARY_PROFILE:-unfoldmymac-notary}}"

fail() { echo "✖ notarize_release: $*" >&2; exit 1; }

[ -n "$TARGET" ] || fail "usage: notarize_release.sh /path/UnfoldMyMac.app|/path/UnfoldMyMac.dmg [profile]"
case "$TARGET" in
  *.app) [ -d "$TARGET" ] || fail "not an application bundle: $TARGET" ;;
  *.dmg) [ -f "$TARGET" ] || fail "not a disk image: $TARGET" ;;
  *) fail "only a .app or a .dmg can be notarized: $TARGET" ;;
esac
TARGET="$(cd "$(dirname "$TARGET")" && pwd)/$(basename "$TARGET")"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# ── Pre-flight, BEFORE the upload ───────────────────────────────────────────
#
# Both checks cost a second. Discovering either after the upload costs the whole submission,
# and the failure reads as a network problem rather than the configuration problem it is.
echo "→ pre-flight"
/usr/bin/codesign --verify --strict --verbose=2 "$TARGET"
details="$(/usr/bin/codesign -dv --verbose=4 "$TARGET" 2>&1)"
case "$details" in
  *"Authority=Developer ID Application:"*) ;;
  *) fail "artifact is not Developer ID signed; notarization would be rejected after the upload" ;;
esac
if [ "${TARGET##*.}" = "app" ]; then
  case "$details" in *"Runtime Version="*) ;; *) fail "application is missing the Hardened Runtime flag" ;; esac
fi
case "$details" in *"Timestamp="*) ;; *) fail "artifact carries no secure timestamp; notarization requires one" ;; esac
/usr/bin/xcrun notarytool history --keychain-profile "$PROFILE" --output-format json >/dev/null 2>&1 \
  || fail "keychain profile '$PROFILE' did not authenticate. Create it once with
     xcrun notarytool store-credentials $PROFILE --key <key.p8> --key-id <id> --issuer <uuid>"
echo "  ✓ Developer ID signature, secure timestamp, profile '$PROFILE'"

# ── Package for upload ──────────────────────────────────────────────────────
#
# ditto -c -k --keepParent is the only archiver Apple documents for a bundle. /usr/bin/zip
# loses the symlinks and xattrs a signed bundle depends on, and the submission fails on the
# far side with a message about an invalid signature.
if [ "${TARGET##*.}" = "app" ]; then
  upload="$work/$(basename "$TARGET" .app).zip"
  echo "→ archiving the bundle for upload"
  /usr/bin/ditto -c -k --keepParent "$TARGET" "$upload"
else
  upload="$TARGET"
fi

echo "→ submitting $(basename "$upload") ($(/usr/bin/du -h "$upload" | cut -f1))"
submission="$work/submission.json"
set +e
/usr/bin/xcrun notarytool submit "$upload" \
  --keychain-profile "$PROFILE" --wait --timeout 2h --output-format json >"$submission" 2>"$work/submit.err"
submit_rc=$?
set -e
[ -s "$submission" ] || { cat "$work/submit.err" >&2; fail "notarytool returned no JSON (exit $submit_rc); the submission did not complete"; }

status="$(/usr/bin/plutil -extract status raw -o - "$submission" 2>/dev/null || true)"
id="$(/usr/bin/plutil -extract id raw -o - "$submission" 2>/dev/null || true)"
[ -n "$id" ] || { cat "$submission" >&2; fail "notarytool returned no submission id"; }

if [ "$status" != "Accepted" ]; then
  echo "--- notarytool log $id ---" >&2
  /usr/bin/xcrun notarytool log "$id" --keychain-profile "$PROFILE" >&2 2>/dev/null || true
  fail "notarization status is '$status' (submission $id), not Accepted. Nothing was stapled."
fi
echo "  ✓ Accepted (submission $id)"

# ── Staple ──────────────────────────────────────────────────────────────────
#
# The ticket is an omitted resource under the bundle's resource rules, so stapling does not
# break the seal. Asserted rather than assumed.
echo "→ stapling"
/usr/bin/xcrun stapler staple "$TARGET"
/usr/bin/xcrun stapler validate "$TARGET" >/dev/null || fail "the stapled ticket does not validate"
/usr/bin/codesign --verify --strict "$TARGET" || fail "stapling invalidated the signature"
echo "  ✓ ticket stapled and validated"

case "$TARGET" in
  *.app) echo "✓ notarize_release: $TARGET stapled. Next: script/package_dmg.sh \"$TARGET\"" ;;
  *.dmg) echo "✓ notarize_release: $TARGET stapled. Next: script/verify_release.sh <app> \"$TARGET\"" ;;
esac
