## Why

Step 31-34 completed the concrete playback binding, bundled libmpv packaging,
runtime composition, capability gate, and UI integration contract. Step 35
needs an executable non-UI smoke gate and release checklist so the core side
can verify local playback and Windows zip packaging before external UI work is
joined.

This change must keep UI implementation outside Codex ownership while giving
the project a repeatable way to check that a release directory can stage
`libmpv-2.dll` beside the executable and that the playback runtime can drive a
local sample file when native dependencies are available.

## What Changes

- Add a player smoke gate script that can:
  - stage a temporary release directory and package `exe + libmpv-2.dll`;
  - run the existing non-UI media_kit/libmpv playback smoke against a sample
    file;
  - skip native smoke when no native dependency is available unless strict mode
    is requested.
- Add release smoke documentation for UI/app-shell handoff and packaged
  Windows verification.
- Extend player-core checks so smoke gate tooling and checklist terms remain
  present.
- Keep `lib/src/ui/**`, `lib/main.dart`, and `windows/**` untouched.

## Impact

- Affected files are limited to docs, tools, checkers, and OpenSpec specs.
- This change does not implement Flutter app shell, file picker, video surface,
  routes, or Windows runner code.
- External UI work can use this checklist after it adds the runner and UI flow.
