# step58-vlc-fallback-adapter

## Why

Step 58 needs a concrete fallback adapter boundary so the existing deterministic
fallback strategy can select a VLC candidate after compatible primary playback
failures. The repository does not yet carry a verified VLC native package, so
this change must not claim end-to-end native VLC playback. It should provide the
Playback-owned adapter seam, backend injection point, capability declaration,
and normalized failure behavior that later native VLC wiring can use.

## What Changes

- Add a Playback-owned VLC fallback adapter implementing `PlayerAdapter`.
- Keep VLC backend execution behind an injected backend interface so tests and
  future native bindings do not leak concrete VLC packages across layers.
- Provide local-file playback, play, pause, seek, stop, dispose, and fallback
  candidate factory behavior with verified capability declarations.
- Normalize unsupported sources, missing backend, backend failures, and
  disposed adapter state through existing playback contracts.
- Add focused tests and checker coverage for fallback selection, capability
  hiding, and boundary cleanliness.

## Non-Goals

- No Flutter UI, app shell, route, playback page, settings page, fallback status
  widget, file picker, video surface, `lib/main.dart`, or `windows/**` changes.
- No unverified VLC package dependency, platform channel, FFI implementation, or
  native VLC binary packaging claim.
- No changes to MPV primary playback behavior, Provider, Storage, Streaming,
  Network, diagnostics, RSS, online rule, or WebView runtime behavior.

## Validation

- Focused VLC fallback adapter and fallback runtime tests.
- Advanced playback and player-core boundary checker coverage.
- OpenSpec validation, analyzer, Flutter analyzer, and Flutter test baseline
  before archive.
