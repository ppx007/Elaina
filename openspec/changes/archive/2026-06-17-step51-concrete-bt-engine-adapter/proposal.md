# step51-concrete-bt-engine-adapter

## Why

Step 51 moves BT downloading from deterministic task orchestration toward a
real download-engine binding. The existing `DownloadEngineAdapter` and
`BtTaskCoreRuntime` already define the correct engine-neutral boundary; the
missing piece is a concrete libtorrent-backed adapter that app composition can
inject without UI, playback, provider, storage, network, or virtual-stream
layers importing libtorrent types.

## What Changes

- Add a concrete Streaming-layer adapter that implements `DownloadEngineAdapter`
  on top of the `libtorrent_flutter` package.
- Keep native/libtorrent imports restricted to the concrete adapter file and
  tests.
- Map magnet and `.torrent` sources, metadata/files, lifecycle commands,
  status observation, event observation, and file selection into existing
  engine-neutral BT task contracts.
- Declare only capabilities proven by this adapter: task management and
  metadata fetching. Virtual stream serving, piece-priority scheduling,
  timeline overlay, and long background download stay unsupported here.
- Update checker coverage so old Step 18 boundaries still protect neutral
  streaming contracts while allowing the approved concrete adapter file.

## Non-Goals

- No Flutter UI, download page, file picker, route, widget, `lib/main.dart`, or
  `windows/**` changes.
- No HTTP/range server, pipe server, virtual byte serving, playback handoff,
  `startStream`, piece priority application, RSS automation, WebView, or
  diagnostics behavior.
- No custom native C/C++ shim or platform build script in this change.

## Validation

- Focused concrete adapter tests.
- BT task core runtime/checker scripts.
- OpenSpec validate, analyzer, and full Flutter test baseline before archive.
