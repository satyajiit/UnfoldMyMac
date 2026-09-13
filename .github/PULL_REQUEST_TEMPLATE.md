## What changed

<!-- What this does and why. If it fixes an issue, link it. -->

## Checks

Run from `UnfoldMyMac/`. Tick what you ran and paste the output in a collapsed block.

- [ ] `swift test`
- [ ] `./script/build_and_run.sh --build`
- [ ] `./script/build_and_run.sh --shader-check`
- [ ] `./script/build_and_run.sh --probe`

`--shader-check` and `--probe` need a real Mac. If you could not run them, say so.

For a website change, `npm run verify` from `website/` instead. CI does not run the browser
suite, so that run is the only thing standing between a regression and the live site.

**Mac model and macOS version:**

## Rendering changes

<!-- Delete if not applicable. Attach a short recording or before-and-after stills. -->

## Confirmations

- [ ] No new third-party package dependencies.
- [ ] Any artwork added is mine or licensed to me, the source is stated above, and anything
      outside the Apache 2.0 grant is carved out in `NOTICE`.
- [ ] No generated attribution lines in my commit messages (`Co-Authored-By` for tools,
      "Generated with", and similar).
