## Why

The current repository baseline is not validation-clean. Player-core boundary
checks fail because playback source handoff imports Streaming runtime types,
full Flutter tests fail because the virtual stream contract test still expects
the old skipped-file failure kind, and analyzer output includes avoid_print
noise in runtime checker tools.

## What Changes

- Keep playback source handoff independent from Streaming by accepting only
  playback-owned virtual stream source descriptors.
- Preserve virtual stream failure semantics by distinguishing missing files from
  skipped files in contract tests and specs.
- Clean analyzer output from runtime checker scripts without changing their
  command-line success messages.

## Impact

- Affected code includes playback handoff/source contracts, focused playback
  and virtual stream tests, runtime smoke checkers, and active OpenSpec specs.
- No commits or pushes are part of this change.
