# step52-bt-task-runtime-implementation

## Why

Step 51 added a concrete libtorrent-backed `DownloadEngineAdapter`, but app
composition still has to manually assemble that adapter with `BtTaskStore`,
cache invalidation, and `BtTaskCoreRuntime`. Step 52 should make the non-UI BT
task runtime implementation path explicit: a stable composition contract that
creates concrete task lifecycle and metadata orchestration without leaking
libtorrent or UI concerns across layer boundaries.

## What Changes

- Add a neutral BT task runtime composition contract that bundles a
  `DownloadEngineAdapter`, `BtTaskStore`, optional cache invalidation bus, and
  optional clock for `BtTaskCoreRuntime`.
- Add a `BtTaskCoreBootstrap.withComposition(...)` constructor so app
  composition can create the runtime through a stable contract.
- Add a concrete libtorrent composition factory in the approved libtorrent
  adapter surface.
- Prove magnet/torrent creation, metadata, file selection, lifecycle commands,
  status/event observation, and restart projection still flow through
  engine-neutral runtime/storage values.
- Update checker coverage for the composition contract while preserving the
  Step 51 native import allowlist.

## Non-Goals

- No Flutter UI, download page, route, file picker, widget, `lib/main.dart`, or
  `windows/**` changes.
- No virtual byte serving, HTTP/range server, pipe server, playback handoff,
  `startStream`, piece-priority application, timeline overlay, RSS automation,
  WebView, diagnostics, or network-policy behavior.
- No additional native package imports outside the approved concrete libtorrent
  adapter file and tests.

## Validation

- Focused BT task runtime composition tests.
- BT task core runtime/checker scripts.
- OpenSpec validate, analyzer, and full Flutter test baseline before archive.
