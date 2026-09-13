# Releasing UnfoldMyMac

UnfoldMyMac ships as a **Developer ID signed, Apple notarized, stapled DMG** with a branded
drag-to-Applications window. Releases are cut by hand on a Mac; CI builds and tests but never
signs for distribution.

```sh
export UNFOLDMYMAC_SIGN_IDENTITY="Developer ID Application: … (TEAMID)"
export UNFOLDMYMAC_NOTARY_PROFILE="unfoldmymac-notary"
cd UnfoldMyMac && ./script/release_macos.sh
```

That runs, in order: `host → build → sign → notarize-app → dmg → notarize-dmg → verify → checksum`,
and prints the SHA-256 plus a ready-to-paste `website/src/lib/release.json` block. Resume after a
failure with `--from <step>`; `--list` prints the step names.

**Three assets, not two.** `release.json` is published alongside the DMG and `SHA256SUMS`, because
the in-app updater reads it as its primary manifest — see [Three assets and the in-app
updater](#three-assets-and-the-in-app-updater) for why that matters and what breaks without it.

## One-time setup on the release machine

**Notarization credentials are a keychain profile.** The scripts accept only the profile *name*,
so no Apple credential can reach a shell history, a process list or a log.

```sh
xcrun notarytool store-credentials unfoldmymac-notary \
  --key "$HOME/.appstoreconnect/private_keys/AuthKey_XXXXXXXXXX.p8" \
  --key-id XXXXXXXXXX --issuer <issuer-uuid>

xcrun notarytool history --keychain-profile unfoldmymac-notary   # prove it works
```

The issuer is a UUID from App Store Connect ▸ Users and Access ▸ Integrations. It is **not** the
Apple Team ID; substituting one for the other is the classic mistake here.

**Grant Automation → Finder** to whichever terminal runs the release, under System Settings ▸
Privacy & Security ▸ Automation. `package_dmg.sh` drives Finder over AppleScript to record the
installer window layout, and that fails over SSH or without a GUI login session.

**`timestamp.apple.com:443` must be reachable.** A firewalled or VPN'd host produces a
clean-looking `codesign` pass whose output cannot be notarized: the notary service rejects it
with "The signature does not include a secure timestamp", minutes into the upload.
`check_release_host.sh` probes this with a real signature before anything else happens. Never
work around it with `--timestamp=none`.

## Why two notarization submissions, and why the order is forced

```
sign .app → notarize #1 → staple .app → package DMG → sign DMG → notarize #2 → staple DMG → verify
```

- **Staple the app before imaging.** Stapling writes the ticket *into* the bundle. Image first
  and staple after, and the loose app and the imaged copy differ, so `verify_release.sh`'s
  `diff -qr` fails and the only repair is another notarization.
- **The DMG needs its own ticket.** A ticket stapled to the app does not travel with the image,
  so the first double-click on a clean offline Mac would have to phone Apple.
- **The app needs its own ticket.** Stapling only the DMG leaves the copy dragged into
  `/Applications` without one, so its first launch needs a network round trip.

Two submissions buy offline first-launch on both surfaces.

**`checksum` is the last step and that is not cosmetic.** `stapler staple` rewrites the DMG, so a
hash taken before stapling is the hash of a file that no longer exists — and the website's
release gate re-hashes the bytes it downloads.

## What each script is for

| Script | Job |
|---|---|
| `check_release_host.sh` | Everything that must be true about the machine: OS and Xcode floors, required tools, the **Metal toolchain** (without it `compile_shaders.sh` silently exits 0 and the release would compile shaders on the user's Mac), a full-prefix identity match plus certificate OU and expiry, the **timestamp probe**, the notary profile, a clean tree, no stale volume of the DMG's name, scratch space. |
| `sign_release.sh` | Developer ID only, no fallback. Asserts bundle shape (licences match the repo, no Markdown, no `.DS_Store`, precompiled shaders present, the OFL ships with the fonts, expected architecture), strips xattrs, signs nested Mach-O inside out with `*.metallib` pruned, seals with the reviewed entitlements, then **runs the hardened bundle's `--probe` and `--shader-check`** before any upload. |
| `notarize_release.sh` | Runs twice. Pre-flights signature and profile *before* the upload, **parses `.status` rather than the exit code** (`--wait` exits 0 for a completed submission whose verdict is `Invalid`), dumps the notary log on failure, staples and validates. |
| `render_dmg_background.swift` | Draws the installer artwork and emits `layout.plist`, so the drawn arrow and the positioned icons cannot drift apart. Registers the app's own Space Grotesk into the process; nothing is installed on the host. |
| `package_dmg.sh` | Stages with `ditto`, images two-stage UDRW→UDZO, lays the window out through Finder, writes the volume icon **after** that step, signs the image, then mounts it and re-checks CDHash, `diff -qr` and the inner staple. |
| `verify_release.sh` | The post-notarization gate, runnable against downloaded artifacts. Prints the SHA-256, **writes** `release.json` next to the DMG, and runs `check_update_trust.sh`. |
| `check_update_trust.sh` | Asserts what the in-app updater will accept, against these exact artifacts: the release app accepted, the DMG accepted, the DMG rejected once the `identifier` clause is added, a development build rejected. |
| `release_macos.sh` | The driver, with `--from` resume. |

## Looking at the installer window without notarizing

Reviewing the artwork should not cost a notarization submission. Set `UNFOLDMYMAC_DMG_PREVIEW=1`
and `package_dmg.sh` will build the same window from whatever bundle you hand it, including the
one `./script/build_and_run.sh --build` just made:

```sh
./script/build_and_run.sh --build
UNFOLDMYMAC_DMG_PREVIEW=1 ./script/package_dmg.sh dist/UnfoldMyMac.app
open dist/UnfoldMyMac-1.0.0-preview.dmg
```

Geometry, background, Finder layout and volume icon are identical to the release path. What the
preview drops is everything that makes an image shippable: it asserts nothing about the bundle's
signature, hardened runtime or staple, it signs nothing, and it forces a `-preview.dmg` filename
so a preview cannot occupy the release name or be uploaded by mistake. Check it in both Light and
Dark Mode; Finder draws the icon captions in the viewer's appearance and the background cannot
override them.

To iterate on the artwork alone, skip the image entirely:

```sh
xcrun swift script/render_dmg_background.swift --out /tmp/dmg-art \
  --fonts Sources/UnfoldMyMacKit/Resources/Fonts --theme light --version 1.0.0
```

## Things that fail silently if you change them

**The window bounds are not the size of the artwork.** Finder's `bounds` include the title bar,
but the background is laid against the icon view's top-left and is never scaled. Setting bounds
to 660x420 crops the bottom of the art by exactly the title bar height and quietly eats the
footer line; nothing fails and the image still passes every later check. `package_dmg.sh` asks
AppKit for the chrome height on the running macOS and adds it, rather than hardcoding a number
that a future release moves.

- **`ditto`, never `cp -R`.** `cp` drops the xattrs and `_CodeSignature` a signed bundle depends
  on, producing an image that mounts, launches, and fails `stapler validate` in front of a user.
- **Populate the image item by item.** `ditto "$staging" "$mount"` would follow the
  `/Applications` symlink and pull the user's entire Applications folder into the image: a
  multi-gigabyte DMG that still builds, signs and mounts.
- **`.VolumeIcon.icns` goes in after the Finder layout step.** Finder deletes it from a volume it
  opens. Written early, the finished image has the custom-icon bit set and no icon to satisfy it.
- **No volume of the DMG's name may already be mounted.** Finder is addressed *by name*, so a
  stale mount means the layout lands on that volume and this image ships unbranded, passing
  every downstream check.
- **The image is signed without `--options runtime` and without entitlements.** A disk image is
  not executable code.
- **`*.metallib` must stay out of the nested-signing loop.** A metallib is an MTLB container, not
  Mach-O; signing one breaks `makeLibrary(URL:)` at runtime on the user's Mac.

## Entitlements

`UnfoldMyMac.entitlements` grants **audio input** for the optional React to sound connection.
Microphone access also requires the user’s TCC permission; it is requested from the sound toggle.
The file’s comment records why the other candidate entitlements are unnecessary. App Sandbox is off and must stay off: the lid-angle
sensor is a raw `IOHIDDevice` feature report that no sandbox entitlement grants.

`sign_release.sh` asserts the embedded set matches that file and that `get-task-allow` is absent,
so granting a capability means editing a file someone reads.

## Three assets and the in-app updater

The app now updates itself from these releases, so a release is no longer only a download link.
The copies already in the field predate the updater and will not pick this up — the first release
after 1.0.1 is still a manual download for everyone — but every release after it is consumed by
software rather than by a person, and three things about it are load-bearing:

**`release.json` is a release asset.** `verify_release.sh` writes it next to the DMG and
`release_macos.sh` refuses to print the publish line without it. The app fetches it from
`/releases/latest/download/release.json`, a redirect rather than an API call, so a check costs
nothing against the 60-per-hour unauthenticated GitHub limit that the wallpaper connector is
already spending from the same address. It is also the only place that states `minimumMacOS`: the
GitHub API cannot report `LSMinimumSystemVersion`, so without this file the app cannot tell a user
on an older macOS that the update is not for them. The GitHub API remains a fallback and the source
of release notes. The website consumes the identical bytes, so the two cannot drift.

**The release must be marked Latest.** `/releases/latest` excludes anything not flagged latest, and
a release published without it is simply invisible to every installed copy. Nothing fails; the
update never appears.

**The asset filename is checked against the tag.** The app requires exactly one `.dmg` named
`UnfoldMyMac-{version}.dmg` matching the tag, and refuses drafts and prereleases twice over — once
from the API flags and once from the parsed tag. These releases are cut by hand, and a forgotten
checkbox should stop an update rather than ship one.

`check_update_trust.sh` runs inside the verify step and asserts the trust decision against the real
artifacts. It reads the requirement strings out of the built binary via `--update-requirements`, so
the check cannot drift from the code that installs updates. The assertion that matters most is the
negative one: a **properly signed development build is rejected**. Team OU alone would accept it —
an Apple Development certificate carries the same OU — so the Developer ID leaf OID and `notarized`
do the real work. The DMG's requirement omits the `identifier` clause, because `package_dmg.sh`
signs the image without `--identifier` and the identifier is derived from the filename
(`UnfoldMyMac-1`, truncated at the first dot); pinning it would break silently at 2.0.

The updater needs no new entitlements and no Info.plist change; `UnfoldMyMac.entitlements` records
why. Worth doing though never read by this design: bump `CFBundleVersion` monotonically per
release, rather than leaving it at a static `2`.

## The local and CI paths are deliberately separate

`script/build_and_run.sh` signs with whatever is at hand — an auto-detected Apple Development
identity, or ad-hoc when there is none, which is what CI uses (`UNFOLDMYMAC_SIGN_IDENTITY: "-"`).
It never signs for distribution.

Keeping development on Apple Development is not laziness: macOS keys TCC grants on the code's
*designated requirement*, and an Apple Development DR pins the leaf certificate's subject CN
while a Developer ID DR pins the team OU. They are different identities to macOS, so signing
local builds with Developer ID would split the Screen Recording grant. It also means **a TCC
grant on the build machine proves nothing about the release build** — test the notarized DMG on a
clean Mac or a fresh user account.
