#!/usr/bin/env bash
# Precompiles every shader unit the app declares into <shaders-dir>/Compiled/<digest>.metallib.
# The digest is the SHA-256 of the exact text ShaderLibraryCache compiles plus its math mode, so the
# runtime finds a unit by content and falls back to source compilation for anything else.
set -euo pipefail
EXECUTABLE="${1:?usage: compile_shaders.sh <executable> <shaders-dir>}"
SHADERS_DIR="${2:?usage: compile_shaders.sh <executable> <shaders-dir>}"
if ! xcrun -sdk macosx metal --version >/dev/null 2>&1; then
  echo "compile_shaders: Metal toolchain not installed; shaders stay source-compiled at runtime"
  exit 0
fi
UNITS="$(mktemp -t unfoldmymac-shader-units).json"
"$EXECUTABLE" --shader-units > "$UNITS"
python3 - "$UNITS" "$SHADERS_DIR" <<'PY'
import hashlib, json, os, pathlib, shutil, subprocess, sys, tempfile
units = json.load(open(sys.argv[1]))
shaders = pathlib.Path(sys.argv[2])
out = shaders / "Compiled"
if out.exists(): shutil.rmtree(out)
out.mkdir(parents=True)
flags = {"fast": ["-ffast-math"], "safe": ["-fno-fast-math"]}
index, compiled, skipped = {}, 0, []
with tempfile.TemporaryDirectory() as tmp:
    for unit in units:
        mode = unit["mathMode"]
        if mode not in flags:
            skipped.append(unit["id"]); continue
        family = pathlib.Path(unit["family"]).name  # "Shaders/Effects" -> "Effects"
        texts = []
        for name in unit["resources"]:
            with open(shaders / family / f"{name}.metal", encoding="utf-8", newline="") as handle: texts.append(handle.read())
        text = "\n".join(texts)
        digest = hashlib.sha256((text + "\n// mathMode=" + mode).encode("utf-8")).hexdigest()
        source = pathlib.Path(tmp) / f"{digest}.metal"; air = pathlib.Path(tmp) / f"{digest}.air"
        source.write_text(text, encoding="utf-8", newline="")
        subprocess.run(["xcrun", "-sdk", "macosx", "metal", "-c", *flags[mode], str(source), "-o", str(air)], check=True)
        subprocess.run(["xcrun", "-sdk", "macosx", "metallib", str(air), "-o", str(out / f"{digest}.metallib")], check=True)
        index[unit["id"]] = digest; compiled += 1
(out / "index.json").write_text(json.dumps(index, indent=2, sort_keys=True) + "\n")
print(f"compile_shaders: {compiled} units precompiled into {out}" + (f"; skipped (unsupported math mode): {skipped}" if skipped else ""))
PY
rm -f "$UNITS"
