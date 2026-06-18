# step55-bt-streaming-smoke-gate

## Why

Steps 51-54 added concrete libtorrent task wiring, file-backed virtual byte
serving, and adapter-owned priority plan application. Step 55 needs a non-UI
smoke gate that proves those pieces compose into one BT streaming path without
moving UI, playback surfaces, range servers, or native engine details across
layer boundaries.

## What Changes

- Add a BT streaming smoke gate that composes libtorrent-backed task creation,
  metadata/file selection, virtual stream creation, file-backed byte range
  serving, scheduler plan generation, and concrete priority application.
- Keep the smoke gate tool and tests deterministic by using a fake
  `LibtorrentEngineBackend` and a temporary local media file.
- Add a checker script that verifies the Step 55 artifacts and boundary terms,
  then runs the focused smoke test and Dart smoke tool.
- Document the non-UI Step 55 smoke path and its production boundary.

## Non-Goals

- No Flutter UI, download page, playback page, timeline overlay rendering,
  route, file picker, video surface, `lib/main.dart`, or `windows/**` changes.
- No HTTP/range server, socket server, pipe server, WebView, diagnostics,
  RSS automation, network policy, storage migration, MPV/VLC/media-kit, or
  native player work.
- No fake native per-piece API. This smoke gate validates priority application
  through the current libtorrent file-priority adapter boundary.

## Validation

- Focused BT streaming smoke gate test.
- Step 55 checker script plus existing BT streaming checker.
- OpenSpec validate, analyzer, and Flutter test baseline before archive.
