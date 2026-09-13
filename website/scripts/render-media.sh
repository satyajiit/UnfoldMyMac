#!/usr/bin/env bash
set -euo pipefail
SITE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$SITE_DIR/../UnfoldMyMac"
FFMPEG_BIN="$(command -v ffmpeg)"
cd "$APP_DIR"
swift build
SWIFT_BIN="$(swift build --show-bin-path)"
mkdir -p "$SITE_DIR/.cache" "$SITE_DIR/public/media"
# Link the debug modules to reach the same internal renderer types used by app tests.
python3 - "$SWIFT_BIN" "$SITE_DIR/.cache/renderer-objects.txt" <<'PYTHON'
import json, pathlib, sys
build = pathlib.Path(sys.argv[1])
objects = []
for target in ['UnfoldMyMacCore', 'UnfoldMyMacKit']:
    mapping = json.loads((build / (target + '.build') / 'output-file-map.json').read_text())
    objects += [entry['object'] for entry in mapping.values() if 'object' in entry]
pathlib.Path(sys.argv[2]).write_text('\n'.join('"' + item + '"' for item in objects))
PYTHON
swiftc -swift-version 6 -parse-as-library -I "$SWIFT_BIN/Modules" \
  "$SITE_DIR/scripts/RenderMedia.swift" \
  "$SITE_DIR/scripts/DesktopFixture.swift" \
  @"$SITE_DIR/.cache/renderer-objects.txt" \
  -o "$SITE_DIR/.cache/render-media"
cd "$SITE_DIR/.."
WEBSITE_FFMPEG="$FFMPEG_BIN" "$SITE_DIR/.cache/render-media" "$SITE_DIR/public/media" "$@"
