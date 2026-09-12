#!/usr/bin/env bash
# Everything that must be true about THIS MACHINE before a release build starts.
#
# Every assertion here costs about a second. Deferred, each one instead costs a full
# notarization round trip, and several of them fail in ways that read as something else:
# a missing secure timestamp reads as a network glitch, an absent Metal toolchain reads as
# nothing at all, and a stale mounted volume reads as a successful build.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$HERE/.." && pwd)"
REPO_ROOT="$(cd "$PROJECT_DIR/.." && pwd)"
IDENTITY="${UNFOLDMYMAC_SIGN_IDENTITY:-}"
PROFILE="${UNFOLDMYMAC_NOTARY_PROFILE:-unfoldmymac-notary}"
ALLOW_DIRTY=0
[ "${1:-}" = "--allow-dirty" ] && ALLOW_DIRTY=1

fail() { echo "✖ check_release_host: $*" >&2; exit 1; }
ok()   { echo "  ✓ $*"; }

echo "→ release host checks"

# ── 1. OS and toolchain ─────────────────────────────────────────────────────
macos_major="$(/usr/bin/sw_vers -productVersion | cut -d. -f1)"
[ "$macos_major" -ge 26 ] || fail "macOS 26 or later is required to build this app (found $(/usr/bin/sw_vers -productVersion))"
developer_dir="$(/usr/bin/xcode-select -p)"
case "$developer_dir" in
  /Applications/Xcode*.app/Contents/Developer) ;;
  *) fail "xcode-select points at '$developer_dir'. Full Xcode is required:
     sudo xcode-select -s /Applications/Xcode.app/Contents/Developer" ;;
esac
xcode_version="$(/usr/bin/xcodebuild -version | awk 'NR==1{print $2}')"
xcode_major="${xcode_version%%.*}"
[ "$xcode_major" -ge 26 ] || fail "Xcode 26 or later is required (found $xcode_major)"
ok "macOS $(/usr/bin/sw_vers -productVersion), Xcode $xcode_version"

for tool in notarytool stapler SetFile; do
  /usr/bin/xcrun -f "$tool" >/dev/null 2>&1 || fail "xcrun cannot find '$tool'"
done
for tool in /usr/bin/tiffutil /usr/bin/hdiutil /usr/bin/osascript /usr/libexec/PlistBuddy /usr/bin/plutil /usr/bin/ditto; do
  [ -x "$tool" ] || fail "missing required tool: $tool"
done
ok "notarytool, stapler, SetFile, tiffutil, hdiutil, osascript, PlistBuddy, plutil, ditto"

# ── 2. Metal toolchain ──────────────────────────────────────────────────────
#
# compile_shaders.sh exits 0 with a note when this is absent, which is right for a developer
# and wrong for a release: the shipped app would compile every shader on the user's Mac at
# first paint. A release must carry Shaders/Compiled.
/usr/bin/xcrun -sdk macosx metal --version >/dev/null 2>&1 \
  || fail "the Metal toolchain is not installed, so compile_shaders.sh would silently skip.
     A release must ship precompiled metallibs. Install it with:
     xcodebuild -downloadComponent MetalToolchain"
ok "Metal toolchain present"

# ── 3. Signing identity ─────────────────────────────────────────────────────
#
# Matched on the full 'Developer ID Application:' prefix, not a loose grep. This keychain also
# holds 'Apple Distribution: … (WW382UC8JD)' with the same team id, and a loose match would
# pick a certificate that notarization rejects.
[ -n "$IDENTITY" ] || fail "UNFOLDMYMAC_SIGN_IDENTITY is unset. Export the exact identity:
     export UNFOLDMYMAC_SIGN_IDENTITY=\"Developer ID Application: … (TEAMID)\""
case "$IDENTITY" in
  "Developer ID Application:"*) ;;
  *) fail "UNFOLDMYMAC_SIGN_IDENTITY must be a 'Developer ID Application: …' identity, not '$IDENTITY'" ;;
esac
identities="$(/usr/bin/security find-identity -v -p codesigning)"
case "$identities" in
  *"\"$IDENTITY\""*) ;;
  *) fail "'$IDENTITY' is not a valid signing identity in this keychain.
     security find-identity -v -p codesigning   # lists what is" ;;
esac

cert_pem="$(/usr/bin/security find-certificate -c "${IDENTITY#Developer ID Application: }" -p 2>/dev/null || true)"
if [ -n "$cert_pem" ]; then
  subject="$(printf '%s' "$cert_pem" | /usr/bin/openssl x509 -noout -subject 2>/dev/null || true)"
  case "$subject" in *"OU=${UNFOLDMYMAC_TEAM_ID:-WW382UC8JD}"*) ;;
    *) fail "the certificate's OU is not ${UNFOLDMYMAC_TEAM_ID:-WW382UC8JD}: $subject" ;; esac
  printf '%s' "$cert_pem" | /usr/bin/openssl x509 -noout -checkend 0 >/dev/null \
    || fail "the signing certificate has expired"
  printf '%s' "$cert_pem" | /usr/bin/openssl x509 -noout -checkend 2592000 >/dev/null \
    || echo "  ! the signing certificate expires within 30 days" >&2
fi
ok "identity: $IDENTITY"

# ── 4. The secure timestamp, probed with a real signature ───────────────────
#
# A signature without a secure timestamp verifies perfectly on this Mac and is rejected by the
# notary service AFTER the upload, with "The signature does not include a secure timestamp".
# Probing with an actual codesign run tests exactly what the release will do.
probe_dir="$(mktemp -d)"
trap 'rm -rf "$probe_dir"' EXIT
echo 'int main(void) { return 0; }' > "$probe_dir/probe.c"
/usr/bin/xcrun clang -o "$probe_dir/timestamp-probe" "$probe_dir/probe.c" 2>/dev/null \
  || fail "could not compile the timestamp probe binary"
if ! /usr/bin/codesign --force --timestamp --options runtime \
       --sign "$IDENTITY" "$probe_dir/timestamp-probe" 2>"$probe_dir/err"; then
  if ! /usr/bin/nc -z -G 5 timestamp.apple.com 443 >/dev/null 2>&1; then
    fail "timestamp.apple.com:443 is unreachable from this machine.

     DNS resolves and port 80 answers, so this is a firewall, VPN or proxy blocking
     outbound 443 to Apple's timestamp authority — not a connectivity problem.

     codesign --timestamp needs 443. Disconnect the VPN, switch networks, or allow
     outbound 443 to 17.157.80.0/24, then re-run.

     Do NOT work around this with --timestamp=none. That ships a build Apple will
     refuse to notarize, and the refusal arrives after the upload."
  fi
  cat "$probe_dir/err" >&2
  fail "the codesign timestamp probe failed"
fi
probe_details="$(/usr/bin/codesign -dvv "$probe_dir/timestamp-probe" 2>&1)"
case "$probe_details" in
  *"Timestamp="*) ;;
  *) fail "the probe signature carries no Timestamp= field, so the timestamp authority was not used" ;;
esac
ok "timestamp.apple.com reachable and stamping"

# ── 5. Notary profile ───────────────────────────────────────────────────────
/usr/bin/xcrun notarytool history --keychain-profile "$PROFILE" --output-format json >/dev/null 2>&1 \
  || fail "the notarytool keychain profile '$PROFILE' did not authenticate. Create it once:

     xcrun notarytool store-credentials $PROFILE \\
       --key \"\$HOME/.appstoreconnect/private_keys/AuthKey_XXXXXXXXXX.p8\" \\
       --key-id XXXXXXXXXX --issuer <issuer-uuid>"
ok "notary profile: $PROFILE"

# ── 6. A release artifact must correspond to a commit ───────────────────────
if [ "$ALLOW_DIRTY" -eq 0 ]; then
  dirty="$(git -C "$REPO_ROOT" status --porcelain)"
  [ -z "$dirty" ] || fail "the working tree is dirty. A notarized artifact that matches no commit
     cannot be reproduced or audited. Commit, stash, or pass --allow-dirty for a throwaway build.

$dirty"
  ok "working tree clean at $(git -C "$REPO_ROOT" rev-parse --short HEAD)"
else
  echo "  ! --allow-dirty: this build will not correspond to a commit" >&2
fi

# ── 7. No stale volume of the name the DMG will use ─────────────────────────
#
# Finder is addressed BY NAME during the window layout. A leftover mount with the same name
# means the layout lands on that volume and this image ships unbranded, passing every later check.
version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$PROJECT_DIR/Info.plist")"
volname="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleName' "$PROJECT_DIR/Info.plist") $version"
[ ! -e "/Volumes/$volname" ] || fail "a volume named '$volname' is already mounted.
     The installer layout addresses Finder by volume name, so building now would lay out THAT
     volume and ship an unbranded image that passes every check. Eject it first:
     hdiutil detach '/Volumes/$volname'"
ok "no stale /Volumes/$volname"

# ── 8. Scratch space ────────────────────────────────────────────────────────
free_kb="$(/bin/df -k "${TMPDIR:-/tmp}" | awk 'NR==2{print $4}')"
[ "$free_kb" -ge 2097152 ] || fail "less than 2 GB free in ${TMPDIR:-/tmp}; the read-write image needs room"
ok "$(( free_kb / 1048576 )) GB free in ${TMPDIR:-/tmp}"

echo "✓ check_release_host: this machine can cut a release"
