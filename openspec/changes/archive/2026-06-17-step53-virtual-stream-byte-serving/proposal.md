# step53-virtual-stream-byte-serving

## Why

Step 52 wires concrete BT task orchestration into runtime composition, but
virtual streams still only prove range availability and buffered range
projection. Step 53 should add the first real byte-serving path for selected
BT files without introducing UI, HTTP servers, sockets, piece-priority
application, timeline overlays, or playback-specific rendering.

## What Changes

- Add a neutral `VirtualByteRangeSource` boundary that `VirtualMediaStream`
  can use to ensure and open byte ranges.
- Let `VirtualMediaStreamRuntime` and `DeterministicVirtualMediaStreamRegistry`
  receive an optional byte source and content URI resolver.
- Add a concrete file-backed byte source that reads `file:` content URIs and
  emits `VirtualByteRangeChunk` values.
- Keep filesystem imports in the concrete byte source file and tests only.
- Add focused tests for selected-file range serving, buffered range
  persistence, and typed missing-file failures.
- Update virtual stream and BT boundary checkers for the concrete byte source
  allowlist only.

## Non-Goals

- No Flutter UI, playback page, video surface, file picker, route,
  `lib/main.dart`, or `windows/**` changes.
- No HTTP/range server, socket server, pipe server, platform channel, FFI,
  libtorrent change, piece-priority application, timeline overlay, RSS
  automation, WebView, diagnostics, network policy, or storage migration.
- No promise that every torrent engine exposes a complete on-disk file path;
  Step 53 serves byte ranges only when the selected file is represented by a
  concrete file URI.

## Validation

- Focused virtual stream byte-serving tests.
- Virtual media stream and BT streaming checker scripts.
- OpenSpec validate, analyzer, and full Flutter test baseline before archive.
