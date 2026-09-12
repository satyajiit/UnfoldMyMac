# Security policy

## Supported versions

The latest published release. There are no long-term support branches.

## Reporting a vulnerability

Use GitHub's private vulnerability reporting:
**[Report a vulnerability](https://github.com/satyajiit/UnfoldMyMac/security/advisories/new)**.
Please do not open a public issue for a security problem.

If you would rather email, use `admin@matterwardlabs.com` with "UnfoldMyMac security" in the
subject.

Expect an acknowledgement within 7 days and a fix or a decision within 30. If a report is
declined you will get the reasoning, not silence.

## What is in scope

UnfoldMyMac runs unsandboxed, reads a raw HID sensor, can capture the built-in display, and can
read files in your home directory. Those surfaces are the ones worth looking at:

- **Desktop capture.** Frost uses ScreenCaptureKit on the built-in display only, with this
  process excluded. Capture starts when Frost is enabled or previewed and stops when it is not.
  Frames stay in memory: nothing is written to disk and nothing is transmitted. A path by which
  frames reach disk, another process, or the network is a vulnerability.
- **The Claude Code reader.** Reads usage metadata from JSONL under `~/.claude/projects` for the
  connected wallpapers. Prompts, responses and tool output are never read, stored or displayed. A
  path by which conversation content reaches a rendered surface, a cache or a log is a
  vulnerability.
- **The Codex reader.** Opens the Codex state database read-only and counts sessions and tokens.
  Titles and rollout content are never read.
- **The hook endpoints.** `--wallpaper-claude-hook` and `--wallpaper-codex-hook` accept JSON on
  stdin from locally configured hooks. They discard prompts and commands, serialise per session,
  and replace records atomically. Anything that makes them execute, log or persist attacker
  controlled content is a vulnerability.
- **The Codex hook installer.** Writes `~/.codex/hooks.json` idempotently, backing up first and
  leaving malformed or symlinked files alone. A path by which it follows a symlink, clobbers an
  unrelated file or escapes that directory is a vulnerability.
- **Artwork import.** Imported images are copied into
  `~/Library/Application Support/UnfoldMyMac/Artwork/`. Path traversal, or a crafted image that
  escapes that directory or executes code, is a vulnerability.
- **The custom HTTP wallpaper provider.** Contacts only the endpoint you configure. Server
  controlled data that leads to code execution, credential disclosure, or requests to a different
  host is a vulnerability.

## What is out of scope

- Anything that needs physical access to an unlocked Mac, or an already compromised account.
- The lid-angle HID report not being present on a given model. That is a hardware difference, not
  a security issue; file it as a compatibility report.
- Denial of service by pointing a data connection at a file you deliberately made enormous.

## What the app does not do

No telemetry, no analytics, no crash reporting, and no account. The only outbound network traffic
is the public GitHub API for a username you enter, NOAA space weather forecasts, and any endpoint
you configure yourself. Every data connection is off until you set it up.
