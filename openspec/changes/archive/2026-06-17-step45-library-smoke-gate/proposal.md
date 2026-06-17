## Why

Steps 41-44 added concrete SQLite storage, storage-backed media-library
runtime, storage-backed video-detail runtime, and playback-history recording.
Step 45 closes Phase C with a non-UI library smoke gate that proves those
pieces compose into one executable local-library flow.

This change is intentionally not a UI page, file picker, thumbnail system, or
player surface. It validates that core runtime code can scan local files,
persist catalog state, bind metadata, load detail data, route playback handoff,
record playback history from playback snapshots, and replay continue-watching
state after reopening storage.

## What Changes

- Add a dedicated non-UI library smoke gate for:
  - local file scan and import;
  - SQLite-backed catalog, binding, and history persistence;
  - storage-backed video-detail loading;
  - local playback source handoff through existing contracts;
  - playback-history recording from `PlaybackStateSnapshot`;
  - continue-watching replay after storage reopen.
- Add focused test coverage for the smoke flow.
- Add a PowerShell checker that enforces the Step 45 tool/docs/tests and
  preserves UI/native/provider/streaming/network boundaries.
- Extend media-library runtime checks to run the Step 45 smoke gate.
- Add concise integration notes for the external UI/app-shell track.

## Impact

- Affected code is limited to tests, tools/checkers, docs, public validation,
  and OpenSpec specs.
- No live network, concrete provider transport, concrete player binding, BT,
  RSS, diagnostics, or UI implementation is required.
- `lib/src/ui/**`, `lib/main.dart`, and `windows/**` remain untouched.
